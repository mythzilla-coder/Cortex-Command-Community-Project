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

    def test_shadow_observations_are_post_release_and_read_only(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn("function SpectatorArena:UpdateAIShadowObservations", source)
        shadow_start = source.index("function SpectatorArena:UpdateAIShadowObservations")
        shadow_end = source.index("\nfunction ", shadow_start + 10)
        shadow_body = source[shadow_start:shadow_end]

        self.assertIn('self.AI_V2_MODE ~= "SHADOW"', shadow_body)
        self.assertIn("self.AIController:RecordContact(", shadow_body)
        self.assertIn("self.AIController:RecordShadowObservation(", shadow_body)
        self.assertIn("self.AIController:SelectVisibleOpponent(", shadow_body)
        self.assertIn("visibleOpponentCount", shadow_body)
        self.assertIn("visibleOpponentChecks", shadow_body)
        self.assertIn("self.AIController:RecordShadowBatchMetrics(", shadow_body)
        self.assertIn("self.AIController:FiredRecently(", shadow_body)
        self.assertIn("self.AIController:RecordEngagement(", shadow_body)
        self.assertIn('self.Telemetry.Emit("AI_SHADOW_OBSERVATION"', shadow_body)
        self.assertNotIn("AIMode =", shadow_body)
        self.assertNotIn("ClearAIWaypoints", shadow_body)
        self.assertNotIn("AddAISceneWaypoint", shadow_body)
        self.assertNotIn("AddAIMOWaypoint", shadow_body)
        self.assertIn('self.Telemetry.Emit("AI_SHADOW_ROUND_SUMMARY"', source)

        instrumentation_start = source.index("function SpectatorArena:UpdateAIInstrumentation")
        instrumentation_end = source.index("\nfunction ", instrumentation_start + 10)
        instrumentation_body = source[instrumentation_start:instrumentation_end]
        self.assertIn("self:UpdateAIShadowObservations(", instrumentation_body)
        self.assertLess(
            instrumentation_body.index("self.AISpawnSettled"),
            instrumentation_body.index("self:UpdateAIShadowObservations(")
        )


if __name__ == "__main__":
    unittest.main()
