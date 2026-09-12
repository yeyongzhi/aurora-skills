#!/usr/bin/env python3
"""Validate business and project-local skills."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from skill_utils import FrontmatterError, NAME_RE, discover_skill_files, load_frontmatter

MIN_DESCRIPTION = 40
REQUIRED = ("name", "description")
PLATFORMS = {"all", "windows", "macos", "linux"}


def lint(root: Path) -> tuple[int, list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    seen_names: dict[str, Path] = {}
    skill_files = discover_skill_files(root, include_project=True)

    for skill_md in skill_files:
        rel = skill_md.relative_to(root)
        skill_dir = skill_md.parent
        try:
            meta = load_frontmatter(skill_md)
        except (FrontmatterError, UnicodeDecodeError) as exc:
            errors.append(f"{rel}: {exc}")
            continue

        for field in REQUIRED:
            if not meta.get(field):
                errors.append(f"{rel}: frontmatter 缺少必填字段 `{field}`")

        name = meta.get("name", "")
        if name and not isinstance(name, str):
            errors.append(f"{rel}: name 必须是字符串")
            name = ""
        if name and not NAME_RE.fullmatch(name):
            errors.append(f"{rel}: name `{name}` 不是 kebab-case")
        if name and name != skill_dir.name:
            errors.append(f"{rel}: name `{name}` 与目录名 `{skill_dir.name}` 不一致")
        if name and name in seen_names:
            errors.append(f"{rel}: name `{name}` 与 {seen_names[name]} 重复")
        elif name:
            seen_names[name] = rel

        description = meta.get("description", "")
        if not isinstance(description, str):
            errors.append(f"{rel}: description 必须是字符串")
        elif len(description.strip()) < MIN_DESCRIPTION:
            errors.append(f"{rel}: description 过短（至少 {MIN_DESCRIPTION} 字），Agent 可能无法正确触发")

        extension = meta.get("metadata", {}) if isinstance(meta.get("metadata"), dict) else {}
        platform = meta.get("platform", extension.get("platform"))
        if not platform:
            warnings.append(f"{rel}: 建议声明 platform（all / windows / macos / linux）")
        elif not isinstance(platform, str) or any(
            item.strip() not in PLATFORMS for item in platform.split(",")
        ):
            errors.append(f"{rel}: platform 包含不支持的值")

        tags = meta.get("tags", extension.get("tags"))
        if not tags:
            warnings.append(f"{rel}: 建议补充 tags，便于交叉检索")
        elif not isinstance(tags, list) or not all(isinstance(tag, str) for tag in tags):
            errors.append(f"{rel}: tags 必须是字符串列表")

    return len(skill_files), errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    total, errors, warnings = lint(Path(args.root).resolve())
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
