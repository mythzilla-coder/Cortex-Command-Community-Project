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
        self.assertIn("self.AIController.SelectVisibleOpponent(", shadow_body)
        self.assertIn("visibleOpponentCount", shadow_body)
        self.assertIn("visibleOpponentChecks", shadow_body)
        self.assertIn("BuildSightProbeTargets", shadow_body)
        self.assertIn("rte.grassID", shadow_body)
        self.assertIn("losProbeRays", shadow_body)
        self.assertIn("self.AIController:RecordShadowBatchMetrics(", shadow_body)
        self.assertIn("SceneMan:CastMORay(", shadow_body)
        self.assertIn("ClassifyRayHit(", shadow_body)
        self.assertIn("rayClassification", shadow_body)
        self.assertIn("rayReturn", shadow_body)
        self.assertIn("hitMOID", shadow_body)
        self.assertIn("CalculateCPUTimeMS", shadow_body)
        self.assertIn("self.AIController:FiredRecently(", shadow_body)
        self.assertIn("self.AIController:RecordEngagement(", shadow_body)
        self.assertIn('self.Telemetry.Emit("AI_SHADOW_OBSERVATION"', shadow_body)
        self.assertNotIn("AIMode =", shadow_body)
        self.assertNotIn("ClearAIWaypoints", shadow_body)
        self.assertNotIn("AddAISceneWaypoint", shadow_body)
        self.assertNotIn("AddAIMOWaypoint", shadow_body)
        self.assertIn('self.Telemetry.Emit("AI_SHADOW_ROUND_SUMMARY"', source)
        self.assertIn("visibleOpponents = aiSnapshot.VisibleOpponents", source)
        self.assertIn("visibleOpponentChecks = aiSnapshot.VisibleOpponentChecks", source)
        self.assertIn("losProbeRays = aiSnapshot.LOSProbeRays", source)
        self.assertIn("actorSkips = aiSnapshot.ActorSkips", source)
        self.assertIn("shadowObservationTimeMS = aiSnapshot.ShadowObservationTimeMS", source)

        instrumentation_start = source.index("function SpectatorArena:UpdateAIInstrumentation")
        instrumentation_end = source.index("\nfunction ", instrumentation_start + 10)
        instrumentation_body = source[instrumentation_start:instrumentation_end]
        self.assertIn("self:UpdateAIShadowObservations(", instrumentation_body)
        self.assertLess(
            instrumentation_body.index("self.AISpawnSettled"),
            instrumentation_body.index("self:UpdateAIShadowObservations(")
        )
        self.assertIn("UpdateAIFireDamageLatches", source)
        self.assertIn("RecordCombatSignals", source)

    def test_spawn_loadout_diagnostic_does_not_flush_console(self):
        source = ACTIVITY.read_text(encoding="utf-8")
        start = source.index("function SpectatorArena:CreateFactionSoldier")
        end = source.index("\nfunction ", start + 10)
        spawn_body = source[start:end]
        self.assertNotIn("self.Telemetry.Snapshot()", spawn_body)

    def test_arena_loadout_reconciliation_samples_post_insertion_and_first_update(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn('self:RecordLoadoutDiagnostic("WEAPON_POST_INSERTION"', source)
        self.assertIn('RecordLoadoutDiagnostic("WEAPON_FIRST_UPDATE"', source)
        self.assertIn("self.A1FirstUpdateLoadoutObserved", source)
        self.assertIn("actor.EquippedItem", source)
        self.assertIn("actor.EquippedBGItem", source)

    def test_arena_retained_weapon_reference_is_opt_in_and_read_only(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn("self.A1RetainWeaponReference", source)
        self.assertIn("self.A1DiagnosticWeaponRefs[actor.UniqueID] = weapon", source)
        self.assertIn("local retainedWeapon = arena.A1DiagnosticWeaponRefs[actor.UniqueID]", source)
        self.assertNotIn("retainedWeapon:Set", source)
        self.assertNotIn("retainedWeapon.ToDelete =", source)

    def test_arena_reconciliation_inspects_attachment_and_world_presence_read_only(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn("actor.FGArm", source)
        self.assertIn("foregroundArmAttached", source)
        self.assertIn("retainedAttached", source)
        self.assertIn("worldItemCount", source)
        self.assertIn("retainedWorldItem", source)

    def test_spawn_trace_is_bounded_and_persisted_only_at_terminal_boundaries(self):
        source = ACTIVITY.read_text(encoding="utf-8")
        self.assertIn("function SpectatorArena:RecordSpawnTrace", source)
        self.assertIn("self.ArenaSpawnTraceLimit", source)
        self.assertIn("function SpectatorArena:PersistSpawnTrace", source)
        self.assertIn('"ROUND_SPAWN_COMPLETE"', source)
        self.assertIn('"STARTUP_DIAGNOSTIC_TIMEOUT"', source)
        trace_start = source.index("function SpectatorArena:RecordSpawnTrace")
        trace_end = source.index("\nfunction ", trace_start + 10)
        trace_body = source[trace_start:trace_end]
        self.assertNotIn("Snapshot()", trace_body)

    def test_post_spawn_trace_is_bounded_sparse_and_one_shot(self):
        source = ACTIVITY.read_text(encoding="utf-8")

        self.assertIn("function SpectatorArena:RecordPostSpawnTrace", source)
        self.assertIn("self.A1PostSpawnTraceLimit", source)
        self.assertIn("function SpectatorArena:PersistPostSpawnTrace", source)
        self.assertIn("self.A1PostSpawnTracePersisted", source)
        self.assertIn("SPECTATOR_ARENA_POST_SPAWN_TRACE_LOG.txt", source)
        self.assertIn("self.A1PostSpawnWallTimer.ElapsedRealTimeMS", source)
        self.assertIn('self:PersistPostSpawnTrace("DIAGNOSTIC_TIMEOUT"', source)
        self.assertIn('self:PersistPostSpawnTrace("ROUND_RESULT"', source)

        for milestone in (1, 2, 10, 60, 300):
            self.assertIn(f"[{milestone}] = true", source)

        for stage in (
            "UPDATE_ACTIVITY_ENTER",
            "BEFORE_CAMERA_UPDATE",
            "AFTER_CAMERA_UPDATE",
            "BEFORE_TOUCHDOWN_UPDATE",
            "AFTER_TOUCHDOWN_UPDATE",
            "BEFORE_FIRE_LATCH_UPDATE",
            "AFTER_FIRE_LATCH_UPDATE",
            "BEFORE_AI_INSTRUMENTATION",
            "AFTER_AI_INSTRUMENTATION",
            "ALL_ACTORS_RELEASED",
            "BATTLE_STARTED",
            "ROUND_RESULT",
        ):
            self.assertIn(f'"{stage}"', source)

        trace_start = source.index("function SpectatorArena:RecordPostSpawnTrace")
        trace_end = source.index("\nfunction ", trace_start + 10)
        trace_body = source[trace_start:trace_end]
        self.assertNotIn("Snapshot(", trace_body)
        self.assertNotIn("AIMode =", trace_body)
        self.assertNotIn("ClearAIWaypoints", trace_body)
        self.assertNotIn("AddAISceneWaypoint", trace_body)
        self.assertNotIn("AddAIMOWaypoint", trace_body)

        instrumentation_start = source.index("function SpectatorArena:UpdateAIInstrumentation")
        instrumentation_end = source.index("\nfunction ", instrumentation_start + 10)
        instrumentation_body = source[instrumentation_start:instrumentation_end]
        self.assertIn("self:RecordA1ProgressMarkers()", instrumentation_body)


if __name__ == "__main__":
    unittest.main()
