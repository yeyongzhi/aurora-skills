from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"


class StaticSiteTests(unittest.TestCase):
    def test_scripts_are_local_and_present(self) -> None:
        html = (SITE / "index.html").read_text(encoding="utf-8")
        sources = re.findall(r'<script\s+src="([^"]+)"', html)
        self.assertTrue(sources)
        self.assertTrue(all(not source.startswith(("http://", "https://")) for source in sources))
        for source in sources:
            self.assertTrue((SITE / source).is_file(), source)

    def test_markdown_is_sanitized_and_paths_are_encoded(self) -> None:
        app = (SITE / "app.js").read_text(encoding="utf-8")
        self.assertIn("DOMPurify.sanitize", app)
        self.assertIn("path.split('/').map(encodeURIComponent)", app)
        self.assertIn("decodeURIComponent(location.hash.slice(1))", app)

    def test_bundle_has_no_volatile_timestamp(self) -> None:
        bundle = (SITE / "data" / "skills.js").read_text(encoding="utf-8")
        payload = json.loads(bundle.removeprefix("window.__SKILLS__ = ").removesuffix(";\n"))
        self.assertNotIn("generatedAt", payload)
        self.assertEqual(1, payload["schemaVersion"])


if __name__ == "__main__":
    unittest.main()
