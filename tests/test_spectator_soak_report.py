import importlib.util
import unittest
from pathlib import Path

path = Path(__file__).parents[1] / "tools" / "spectator_soak_report.py"
spec = importlib.util.spec_from_file_location("report", path)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

class SoakReportTests(unittest.TestCase):
    def test_ignores_noise_and_reports_completed_rounds(self):
        lines = ["warning: audio", "SPECTATOR_EVENT event=ROUND_START round=1", "SPECTATOR_EVENT event=ROUND_RESULT round=1 winner=TEAM_1 durationMS=1200 team1Score=1 team2Score=0"]
        result = report.parse(lines)
        self.assertEqual(result["rounds_completed"], 1)
        self.assertEqual(result["winners"], {"TEAM_1": 1})
        self.assertEqual(result["duration_ms"]["average"], 1200)
        self.assertFalse(result["incomplete_final_round"])

    def test_detects_incomplete_round_and_watchdog(self):
        result = report.parse(["SPECTATOR_EVENT event=ROUND_START round=2", "SPECTATOR_EVENT event=WATCHDOG round=2 reason=timeout"])
        self.assertTrue(result["incomplete_final_round"])
        self.assertEqual(result["watchdog_events"], 1)

    def test_accepts_engine_print_prefix_in_console_snapshot(self):
        result = report.parse([
            "PRINT: SPECTATOR_EVENT event=ROUND_START round=3",
            "PRINT: SPECTATOR_EVENT event=ROUND_RESULT round=3 winner=TEAM_2 durationMS=900"
        ])
        self.assertEqual(result["rounds_started"], 1)
        self.assertEqual(result["rounds_completed"], 1)
        self.assertEqual(result["winners"], {"TEAM_2": 1})

if __name__ == "__main__": unittest.main()
