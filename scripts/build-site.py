#!/usr/bin/env python3
"""扫描仓库里的所有 skill，生成站点数据文件 site/data/skills.js。

产出为 JS 而不是 JSON，是为了让 index.html 用 file:// 双击打开时也能加载
（fetch + JSON 在 file:// 下会被 CORS 拦掉）。

用法:
    python scripts/build-site.py
    python scripts/build-site.py --root PATH --out PATH
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SKIP_DIRS = {".git", ".github", "_archive", "site", "node_modules", ".workbuddy", "scripts"}
TEXT_SUFFIX = {
    ".md", ".markdown", ".txt", ".json", ".yml", ".yaml", ".toml", ".ini", ".cfg",
    ".py", ".js", ".ts", ".tsx", ".jsx", ".sh", ".bash", ".ps1", ".psm1",
    ".html", ".htm", ".css", ".scss", ".sql", ".rb", ".go", ".java", ".xml",
}
MAX_FILE_BYTES = 512 * 1024
H1_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    data: dict = {}
    current_list = None
    for line in text[3:end].strip("\n").splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        item = line.strip()
        if item.startswith("- ") and current_list:
            data[current_list].append(item[2:].strip().strip("\"'"))
            continue
        if ":" not in item:
            continue
        key, _, value = item.partition(":")
        key, value = key.strip(), value.strip()
        if not value:
            data[key] = []
            current_list = key
        else:
            data[key] = value.strip("\"'")
            current_list = None
    return data


def lang_of(suffix: str) -> str:
    return {
        ".md": "markdown", ".markdown": "markdown", ".ps1": "powershell",
        ".sh": "bash", ".bash": "bash", ".py": "python", ".js": "javascript",
        ".ts": "typescript", ".tsx": "typescript", ".jsx": "javascript",
        ".html": "html", ".htm": "html", ".css": "css", ".json": "json",
        ".yml": "yaml", ".yaml": "yaml", ".sql": "sql", ".go": "go",
        ".java": "java", ".rb": "ruby", ".xml": "xml", ".toml": "toml",
    }.get(suffix, suffix.lstrip(".") or "text")


def category_title(readme: Path | None, fallback: str) -> str:
    """从分类 README 的一级标题里取 `xxx · 中文名` 的中文部分。"""
    if readme and readme.exists():
        m = H1_RE.search(readme.read_text(encoding="utf-8", errors="replace"))
        if m:
            title = m.group(1).strip()
            if "·" in title:
                return title.split("·", 1)[1].strip()
            return title
    return fallback


def collect_files(skill_dir: Path, root: Path) -> list[dict]:
    files = []
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        rel = path.relative_to(root).as_posix()
        suffix = path.suffix.lower()
        size = path.stat().st_size
        entry = {
            "path": rel,
            "name": path.name,
            "lang": lang_of(suffix),
            "size": size,
        }
        if suffix in TEXT_SUFFIX:
            if size > MAX_FILE_BYTES:
                entry["content"] = path.read_text(
                    encoding="utf-8", errors="replace"
                )[:MAX_FILE_BYTES]
                entry["truncated"] = True
            else:
                entry["content"] = path.read_text(encoding="utf-8", errors="replace")
            entry["binary"] = False
        else:
            entry["content"] = ""
            entry["binary"] = True
        files.append(entry)
    # SKILL.md 永远排在最前
    files.sort(key=lambda f: (f["name"] != "SKILL.md", f["path"]))
    return files


def build(root: Path) -> dict:
    categories: list[dict] = []
    grouped: dict[str, list[Path]] = {}

    for skill_md in sorted(root.rglob("SKILL.md")):
        rel = skill_md.relative_to(root)
        if any(p in SKIP_DIRS or p.startswith(".") for p in rel.parts):
            continue
        grouped.setdefault(rel.parts[0], []).append(skill_md.parent)

    for cat_name, skill_dirs in grouped.items():
        cat_path = root / cat_name
        readme = cat_path / "README.md"
        skills = []
        for skill_dir in sorted(skill_dirs, key=lambda p: p.name):
            skill_md = skill_dir / "SKILL.md"
            meta = parse_frontmatter(skill_md.read_text(encoding="utf-8", errors="replace"))
            skills.append({
                "name": skill_dir.name,
                "dir": skill_dir.relative_to(root).as_posix(),
                "description": meta.get("description", ""),
                "platform": meta.get("platform", "all"),
                "tags": meta.get("tags", []) if isinstance(meta.get("tags"), list) else [],
                "files": collect_files(skill_dir, root),
            })
        categories.append({
            "name": cat_name,
            "title": category_title(readme if readme.exists() else None, cat_name),
            "meta": cat_name.startswith("_"),
            "readme": readme.read_text(encoding="utf-8", errors="replace")
            if readme.exists() else "",
            "skills": skills,
        })

    # 业务分类按名字排序在前，meta 分类（_ 前缀）在后
    categories.sort(key=lambda c: (c["meta"], c["name"]))

    total_skills = sum(len(c["skills"]) for c in categories)
    total_files = sum(len(s["files"]) for c in categories for s in c["skills"])
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "categories": categories,
        "stats": {
            "categories": len([c for c in categories if not c["meta"]]),
            "skills": total_skills,
            "files": total_files,
        },
    }


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=here.parent)
    ap.add_argument("--out", default=here.parent / "site" / "data" / "skills.js")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    data = build(root)
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    out.write_text(
        "window.__SKILLS__ = "
        + json.dumps(data, ensure_ascii=False, separators=(",", ":"))
        + ";\n",
        encoding="utf-8",
    )

    s = data["stats"]
    print(
        f"已生成 {out.relative_to(root).as_posix()}："
        f"{s['categories']} 个分类 / {s['skills']} 个 skill / {s['files']} 个文件，"
        f"{out.stat().st_size / 1024:.1f} KB"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
