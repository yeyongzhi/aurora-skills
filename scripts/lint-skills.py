#!/usr/bin/env python3
"""校验仓库内所有 skill 的 frontmatter 与命名一致性。

用法:
    python scripts/lint-skills.py              # 警告不影响退出码
    python scripts/lint-skills.py --strict     # 有警告也返回 1（CI 用）
    python scripts/lint-skills.py --root PATH  # 指定仓库根目录
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SKIP_DIRS = {".git", "_archive", "_templates", "scripts", "site", ".workbuddy", "node_modules"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MIN_DESCRIPTION = 40
REQUIRED = ("name", "description")


def parse_frontmatter(text: str) -> dict:
    """极简 YAML frontmatter 解析，只覆盖 skill 用到的扁平结构。"""
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    block = text[3:end].strip("\n")
    data: dict = {}
    current_list = None
    for line in block.splitlines():
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=Path(__file__).resolve().parent.parent)
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    errors: list[str] = []
    warnings: list[str] = []
    seen_names: dict[str, Path] = {}
    total = 0

    for skill_md in sorted(root.rglob("SKILL.md")):
        rel = skill_md.relative_to(root)
        if any(part in SKIP_DIRS or part.startswith(".") for part in rel.parts):
            continue
        total += 1
        skill_dir = skill_md.parent
        meta = parse_frontmatter(skill_md.read_text(encoding="utf-8"))

        if not meta:
            errors.append(f"{rel}: 缺少或无法解析 YAML frontmatter")
            continue

        for field in REQUIRED:
            if not meta.get(field):
                errors.append(f"{rel}: frontmatter 缺少必填字段 `{field}`")

        name = meta.get("name", "")
        if name and not NAME_RE.match(name):
            errors.append(f"{rel}: name `{name}` 不是 kebab-case")
        if name and name != skill_dir.name:
            errors.append(f"{rel}: name `{name}` 与目录名 `{skill_dir.name}` 不一致")
        if name and name in seen_names:
            errors.append(f"{rel}: name `{name}` 与 {seen_names[name]} 重复")
        elif name:
            seen_names[name] = rel

        if len(meta.get("description", "")) < MIN_DESCRIPTION:
            errors.append(
                f"{rel}: description 过短（< {MIN_DESCRIPTION} 字），"
                "Agent 可能无法正确触发"
            )
        if not meta.get("platform"):
            warnings.append(f"{rel}: 建议声明 platform（all / windows / macos / linux）")
        if not meta.get("tags"):
            warnings.append(f"{rel}: 建议补充 tags，便于交叉检索")

    print(f"扫描到 {total} 个 skill")
    for line in warnings:
        print(f"  WARN  {line}")
    for line in errors:
        print(f"  ERROR {line}")

    if errors:
        print(f"\n{len(errors)} 个错误，{len(warnings)} 个警告")
        return 1
    if warnings and args.strict:
        print(f"\n{len(warnings)} 个警告（strict 模式）")
        return 1
    print("通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
