import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StaticBrandingTest(unittest.TestCase):
    def test_static_branding_uses_new_name_and_shared_logo(self):
        html = (ROOT / "static" / "index.html").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("需求生成工坊", html)
        self.assertIn("需求生成工坊", readme)
        self.assertNotIn("需求町工坊", html)
        self.assertNotIn("需求町工坊", readme)
        self.assertEqual(html.count("/assets/demand-logo.png"), 4)
        self.assertTrue((ROOT / "static" / "assets" / "demand-logo.png").exists())


if __name__ == "__main__":
    unittest.main()
