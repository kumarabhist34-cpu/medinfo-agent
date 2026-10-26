"""Unit tests for the FDA label Lambda. Run: python -m unittest discover -s lambda/tests -v"""

import io
import json
import os
import sys
import unittest
import urllib.error
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "fda_label"))
import app  # noqa: E402


def fda_response(payload):
    return io.BytesIO(json.dumps(payload).encode())


def event(drug):
    return {"queryStringParameters": {"drug": drug} if drug is not None else None}


class LambdaHandlerTests(unittest.TestCase):

    @mock.patch("app.urllib.request.urlopen")
    def test_returns_label_summary(self, urlopen):
        urlopen.return_value.__enter__.return_value = fda_response({
            "results": [{"effective_time": "20250114", "boxed_warning": ["Lactic acidosis can occur."]}]
        })
        res = app.lambda_handler(event("metformin"), None)
        body = json.loads(res["body"])
        self.assertEqual(res["statusCode"], 200)
        self.assertEqual(body["labelEffectiveDate"], "20250114")
        self.assertEqual(body["boxedWarning"], "Lactic acidosis can occur.")
        called_url = urlopen.call_args[0][0]
        self.assertIn("openfda.generic_name", called_url)
        self.assertIn("metformin", called_url)

    @mock.patch("app.urllib.request.urlopen")
    def test_no_boxed_warning_reports_none(self, urlopen):
        urlopen.return_value.__enter__.return_value = fda_response({"results": [{"effective_time": "20240101"}]})
        body = json.loads(app.lambda_handler(event("lisinopril"), None)["body"])
        self.assertEqual(body["boxedWarning"], "None")

    @mock.patch("app.urllib.request.urlopen")
    def test_long_warning_is_truncated(self, urlopen):
        urlopen.return_value.__enter__.return_value = fda_response(
            {"results": [{"effective_time": "20240101", "boxed_warning": ["x" * 2000]}]})
        body = json.loads(app.lambda_handler(event("drug"), None)["body"])
        self.assertEqual(len(body["boxedWarning"]), app.MAX_WARNING_CHARS)

    @mock.patch("app.urllib.request.urlopen")
    def test_openfda_404_returns_404(self, urlopen):
        urlopen.side_effect = urllib.error.HTTPError("u", 404, "Not Found", {}, None)
        self.assertEqual(app.lambda_handler(event("notadrug"), None)["statusCode"], 404)

    @mock.patch("app.urllib.request.urlopen")
    def test_network_failure_returns_502(self, urlopen):
        urlopen.side_effect = urllib.error.URLError("timeout")
        self.assertEqual(app.lambda_handler(event("metformin"), None)["statusCode"], 502)

    def test_missing_drug_returns_400(self):
        self.assertEqual(app.lambda_handler(event(None), None)["statusCode"], 400)
        self.assertEqual(app.lambda_handler(event("   "), None)["statusCode"], 400)

    def test_rejects_unsafe_input(self):
        res = app.lambda_handler(event('metformin" OR 1'), None)
        self.assertEqual(res["statusCode"], 400)


if __name__ == "__main__":
    unittest.main()
