import io
import unittest
from urllib.error import HTTPError

import app


class QwenErrorReportingTest(unittest.TestCase):
    def test_http_error_body_is_reported(self):
        original_urlopen = app.request.urlopen

        def fake_urlopen(req, timeout):
            raise HTTPError(
                req.full_url,
                400,
                "Bad Request",
                hdrs=None,
                fp=io.BytesIO(b'{"code":"InvalidModel","message":"model is unavailable"}'),
            )

        app.request.urlopen = fake_urlopen
        try:
            with self.assertRaisesRegex(ValueError, "InvalidModel"):
                app.call_qwen_json("system", "user", "test-key", "bad-model", app.DEFAULT_QWEN_ENDPOINT)
        finally:
            app.request.urlopen = original_urlopen


if __name__ == "__main__":
    unittest.main()
