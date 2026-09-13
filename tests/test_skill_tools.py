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

    def test_bundle_is_identical_for_lf_and_crlf_checkouts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            skill_dir = root / "sort-skills" / "system" / "business-skill"
            write_skill(skill_dir, "business-skill")
            script = skill_dir / "example.ps1"
            script.write_bytes("# 中文\nWrite-Output 'hello'\n".encode("utf-8"))
            binary = skill_dir / "example.png"
            binary.write_bytes(b"\x89PNG\r\n")
            text_files = [skill_dir / "SKILL.md", script]
            for path in text_files:
                path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n"))
            first = build_site.render_bundle(build_site.build(root))
            for path in text_files:
                path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
            second = build_site.render_bundle(build_site.build(root))
            self.assertEqual(first, second)
            files = build_site.collect_files(skill_dir, root)
            script_entry = next(entry for entry in files if entry["name"] == script.name)
            self.assertEqual(len(script_entry["content"].encode("utf-8")), script_entry["size"])
            binary_entry = next(entry for entry in files if entry["name"] == binary.name)
            self.assertTrue(binary_entry["binary"])
            self.assertEqual(len(binary.read_bytes()), binary_entry["size"])

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
