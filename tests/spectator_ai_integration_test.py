from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ACTIVITY = ROOT / "Data" / "Base.rte" / "Activities" / "SpectatorArena.lua"


class SpectatorAIIntegrationTests(unittest.TestCase):
    def test_controller_is_wired_to_release_boundary_in_off_mode(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn('self.AI_V2_MODE = "OFF"', source)
        self.assertIn('self.Telemetry.ConfigureRuntime("SPECTATOR_EVENT_LOG.txt")', source)
        self.assertIn('self.Telemetry.Emit("AI_V2_CONFIG"', source)
        self.assertIn('self.AIController:RegisterActor(', source)
        self.assertRegex(source, r'AIController:ReleaseActor\(')
        self.assertIn('self.AIController:RecordPosition(', source)
        self.assertIn('self:UpdateAIInstrumentation(', source)
        self.assertLess(
            source.index("self.RoundNumber = self.RoundNumber + 1"),
            source.index("self.AIController:BeginRound(")
        )

    def test_instrumentation_has_no_actor_control_calls(self):
        source = ACTIVITY.read_text(encoding="utf-8")
        start = source.index("function SpectatorArena:UpdateAIInstrumentation")
        end = source.index("\nend", start)
        body = source[start:end]

        self.assertNotIn("AIMode =", body)
        self.assertNotIn("ClearAIWaypoints", body)
        self.assertNotIn("AddAISceneWaypoint", body)
        self.assertNotIn("AddAIMOWaypoint", body)


if __name__ == "__main__":
    unittest.main()
