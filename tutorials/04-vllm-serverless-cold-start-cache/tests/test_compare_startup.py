import sys
import unittest
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from compare_startup import compare


class CompareStartupTest(unittest.TestCase):
    def test_reports_signed_percent_change(self):
        result = compare({"cold": {"phase": 200}, "cached": {"phase": 50}})
        self.assertEqual(result["comparison"]["phase"]["change_percent"], -75.0)

    def test_ignores_metrics_missing_from_cached_run(self):
        result = compare({"cold": {"kept": 10, "missing": 3}, "cached": {"kept": 8}})
        self.assertEqual(set(result["comparison"]), {"kept"})


if __name__ == "__main__":
    unittest.main()
