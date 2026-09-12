#!/usr/bin/env python3
"""Build the static site's deterministic skill data bundle."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from skill_utils import TEMPLATE_SKILL, discover_skill_files, load_frontmatter

TEXT_SUFFIXES = {
    ".md", ".markdown", ".txt", ".json", ".yml", ".yaml", ".toml", ".ini", ".cfg",
    ".py", ".js", ".ts", ".tsx", ".jsx", ".sh", ".bash", ".ps1", ".psm1",
    ".html", ".htm", ".css", ".scss", ".sql", ".rb", ".go", ".java", ".xml",
}
MAX_FILE_BYTES = 512 * 1024
H1_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def language_for(suffix: str) -> str:
    return {
        ".md": "markdown", ".markdown": "markdown", ".ps1": "powershell",
        ".sh": "bash", ".bash": "bash", ".py": "python", ".js": "javascript",
        ".ts": "typescript", ".tsx": "typescript", ".jsx": "javascript",
        ".html": "html", ".htm": "html", ".css": "css", ".json": "json",
        ".yml": "yaml", ".yaml": "yaml", ".sql": "sql", ".go": "go",
        ".java": "java", ".rb": "ruby", ".xml": "xml", ".toml": "toml",
    }.get(suffix, suffix.lstrip(".") or "text")


def category_title(readme: Path | None, fallback: str) -> str:
    if readme and readme.exists():
        match = H1_RE.search(readme.read_text(encoding="utf-8"))
        if match:
            title = match.group(1).strip()
            return title.split("·", 1)[-1].strip()
    return fallback


def text_preview(path: Path) -> tuple[str, bool]:
    raw = path.read_bytes()
    truncated = len(raw) > MAX_FILE_BYTES
    return raw[:MAX_FILE_BYTES].decode("utf-8", errors="replace"), truncated


def collect_files(skill_dir: Path, root: Path) -> list[dict[str, Any]]:
    files: list[dict[str, Any]] = []
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        suffix = path.suffix.lower()
        entry: dict[str, Any] = {
            "path": path.relative_to(root).as_posix(),
            "name": path.name,
            "lang": language_for(suffix),
            "size": path.stat().st_size,
        }
        if suffix in TEXT_SUFFIXES:
            entry["content"], truncated = text_preview(path)
            entry["binary"] = False
            if truncated:
                entry["truncated"] = True
        else:
            entry["content"] = ""
            entry["binary"] = True
        files.append(entry)
    files.sort(key=lambda item: (item["name"] != "SKILL.md", item["path"]))
    return files


def build(root: Path) -> dict[str, Any]:
    grouped: dict[str, list[Path]] = {}
    for skill_md in discover_skill_files(root, include_project=False):
        rel = skill_md.relative_to(root)
        category = rel.parts[1]
        grouped.setdefault(category, []).append(skill_md.parent)

    categories: list[dict[str, Any]] = []
    for category, skill_dirs in grouped.items():
        category_dir = root / "sort-skills" / category
        readme = category_dir / "README.md"
        skills = []
        for skill_dir in sorted(skill_dirs, key=lambda path: path.name):
            meta = load_frontmatter(skill_dir / "SKILL.md")
            skills.append({
                "name": skill_dir.name,
                "dir": skill_dir.relative_to(root).as_posix(),
                "description": meta.get("description", ""),
                "platform": meta.get("platform", "all"),
                "tags": meta.get("tags", []),
                "files": collect_files(skill_dir, root),
            })
        categories.append({
            "name": category,
            "title": category_title(readme, category),
            "meta": False,
            "readme": readme.read_text(encoding="utf-8") if readme.exists() else "",
            "skills": skills,
        })

    template_md = root / TEMPLATE_SKILL
    if template_md.is_file():
        template_dir = template_md.parent
        meta = load_frontmatter(template_md)
        template_readme = root / "_templates" / "README.md"
        categories.append({
            "name": "_templates",
            "title": "模板",
            "meta": True,
            "readme": template_readme.read_text(encoding="utf-8") if template_readme.exists() else "",
            "skills": [{
                "name": template_dir.name,
                "dir": template_dir.relative_to(root).as_posix(),
                "description": meta.get("description", ""),
                "platform": meta.get("platform", "all"),
                "tags": meta.get("tags", []),
                "files": collect_files(template_dir, root),
            }],
        })

    categories.sort(key=lambda item: (item["meta"], item["name"]))
    business = [category for category in categories if not category["meta"]]
    return {
        "schemaVersion": 1,
        "categories": categories,
        "stats": {
            "categories": len(business),
            "skills": sum(len(category["skills"]) for category in business),
            "files": sum(
                len(skill["files"])
                for category in business
                for skill in category["skills"]
            ),
            "templates": sum(
                len(category["skills"]) for category in categories if category["meta"]
            ),
        },
    }


def render_bundle(data: dict[str, Any]) -> str:
    return "window.__SKILLS__ = " + json.dumps(
        data, ensure_ascii=False, separators=(",", ":")
    ) + ";\n"


def main() -> int:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=here.parent)
    parser.add_argument("--out", default=here.parent / "site" / "data" / "skills.js")
    parser.add_argument("--check", action="store_true", help="fail when the bundle is stale")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    data = build(root)
    rendered = render_bundle(data)

    if args.check:
        if not out.exists() or out.read_text(encoding="utf-8") != rendered:
            print(f"{out.relative_to(root).as_posix()} 不是最新，请运行 build-site.py")
            return 1
        print(f"{out.relative_to(root).as_posix()} 已是最新")
        return 0

    out.parent.mkdir(parents=True, exist_ok=True)
    previous = out.read_text(encoding="utf-8") if out.exists() else None
    if previous != rendered:
        out.write_text(rendered, encoding="utf-8", newline="\n")
        action = "已生成"
    else:
        action = "无需更新"

    stats = data["stats"]
    print(
        f"{action} {out.relative_to(root).as_posix()}："
        f"{stats['categories']} 个分类 / {stats['skills']} 个 skill / "
        f"{stats['files']} 个文件 / {stats['templates']} 个模板"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
