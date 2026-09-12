"""Shared skill discovery and YAML frontmatter helpers."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Iterable

import yaml

FRONTMATTER_RE = re.compile(r"\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\Z)", re.DOTALL)
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
BUSINESS_SKILLS_DIR = Path("sort-skills")
PROJECT_SKILLS_DIR = Path(".agents") / "skills"
TEMPLATE_SKILL = Path("_templates") / "skill-template" / "SKILL.md"


class FrontmatterError(ValueError):
    """Raised when a SKILL.md frontmatter block is missing or invalid."""


def load_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise FrontmatterError("缺少格式正确的 YAML frontmatter")
    try:
        data = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        raise FrontmatterError(f"YAML 无法解析：{exc}") from exc
    if not isinstance(data, dict):
        raise FrontmatterError("YAML frontmatter 必须是映射")
    return data


def discover_skill_files(
    root: Path,
    *,
    include_project: bool = True,
    include_template: bool = False,
) -> list[Path]:
    """Discover only declared skill roots instead of scanning the whole repository."""
    found = list((root / BUSINESS_SKILLS_DIR).rglob("SKILL.md"))
    if include_project:
        project_root = root / PROJECT_SKILLS_DIR
        if project_root.is_dir():
            found.extend(project_root.rglob("SKILL.md"))
    if include_template:
        template = root / TEMPLATE_SKILL
        if template.is_file():
            found.append(template)
    return sorted(set(path.resolve() for path in found))
