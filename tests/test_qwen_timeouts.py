import unittest

import app


class QwenTimeoutConfigTest(unittest.TestCase):
    def test_brainstorm_timeout_allows_slower_frontier_models(self):
        self.assertGreaterEqual(app.QWEN_IDEA_TIMEOUT_SECONDS, 180)


if __name__ == "__main__":
    unittest.main()
