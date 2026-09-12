from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))


def load_script(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


build_site = load_script("build_site", ROOT / "scripts" / "build-site.py")
lint_skills = load_script("lint_skills", ROOT / "scripts" / "lint-skills.py")
from skill_utils import discover_skill_files, load_frontmatter  # noqa: E402


def write_skill(path: Path, name: str, description: str = "用于测试复杂 YAML 和 Skill 发现行为，确保描述长度足够并能够被正确解析。") -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "SKILL.md").write_text(
        "---\n"
        f"name: {name}\n"
        f"description: \"{description}: includes colon\"\n"
        "platform: all\n"
        "tags: [one, two]\n"
        "---\n\n# Test\n",
        encoding="utf-8",
    )


class SkillToolsTests(unittest.TestCase):
    def test_yaml_and_declared_roots(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_skill(root / "sort-skills" / "development" / "business-skill", "business-skill")
            write_skill(root / ".agents" / "skills" / "project-skill", "project-skill")
            write_skill(root / "_archive" / "archived-skill", "archived-skill")
            files = discover_skill_files(root, include_project=True)
            self.assertEqual(2, len(files))
            self.assertEqual(["one", "two"], load_frontmatter(files[0])["tags"])

    def test_build_is_deterministic_and_excludes_templates_from_stats(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_skill(root / "sort-skills" / "development" / "business-skill", "business-skill")
            category = root / "sort-skills" / "development"
            (category / "README.md").write_text("# development · 软件开发\n", encoding="utf-8")
            write_skill(root / "_templates" / "skill-template", "skill-template")
            (root / "_templates" / "README.md").write_text("# 模板\n", encoding="utf-8")

            first = build_site.build(root)
            second = build_site.build(root)
            self.assertEqual(first, second)
            self.assertEqual(
                {"categories": 1, "skills": 1, "files": 1, "templates": 1},
                first["stats"],
            )
            self.assertNotIn("generatedAt", build_site.render_bundle(first))
            self.assertEqual("软件开发", first["categories"][0]["title"])

    def test_lint_includes_project_skills(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_skill(root / "sort-skills" / "system" / "business-skill", "business-skill")
            write_skill(root / ".agents" / "skills" / "project-skill", "project-skill")
            total, errors, warnings = lint_skills.lint(root)
            self.assertEqual(2, total)
            self.assertEqual([], errors)
            self.assertEqual([], warnings)


if __name__ == "__main__":
    unittest.main()
