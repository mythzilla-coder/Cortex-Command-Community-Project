# Spectator AI V2 SHADOW Smoke Report

Date: 2026-09-02
Branch: `spectator-random-factions`
Test mode: temporary non-default `SHADOW`
Production mode after test: `OFF`

## Purpose

Validate the SHADOW instrumentation path and its lifecycle boundary before collecting a larger semantic/performance sample. This was not a behavior comparison and does not justify TASKS activation.

## Captured result

- Rounds started: 4.
- Rounds completed: 3.
- Incomplete final round: yes; the process was stopped during round 4 after the smoke target was reached.
- Watchdog events: 0.
- Parsed `AI_SHADOW_OBSERVATION` records: 2,393.
- Observation counts by round: round 1 = 768, round 2 = 714, round 3 = 735, round 4 = 176.
- `hasLOS=true` records: 0.
- `hasLOS=false` records: 2,393.
- `firing=true` records: 0.
- Completed-round durations: 37,565.164 ms; 45,114.862 ms; 47,598.096 ms.
- Winners: Ronin twice; Techion once.

## Invariants checked

- No SHADOW observation appeared before the first `AI_TOUCHDOWN_ALL_RELEASED` marker.
- SHADOW emitted observations across both teams after release.
- No actor-control calls were introduced; source-level safety tests and build remain passing.
- The observation payload contained opponent ID and distance but no opponent X/Y coordinates.
- The exact test process was stopped after evidence capture and the source mode was restored to `OFF`.

## Interpretation

The smoke test validates event transport, round lifecycle ordering, post-release gating, and basic observation volume. It did not exercise direct contact acquisition, engagement locks, firing capture, or meaningful LOS differentiation because this trace contained no LOS-positive or firing-positive samples.

The current 500 ms observation cadence should not be treated as a reliable firing-event detector. Fire and damage latches now preserve transitions observed by the SHADOW loop, but a future implementation should capture high-frequency timestamps and let the slower tactical loop consume those observations.

The log's nearest-enemy ID/distance fields are diagnostic world-truth observations. They must remain separate from team knowledge and must not become strategic targets when LOS is false.

## Performance follow-up

The original smoke path exposed a telemetry architecture problem: `Telemetry.Emit()` called `ConsoleMan:SaveAllText()` for every event. That meant each 500 ms SHADOW batch could trigger repeated full-console snapshots.

The fix separates cheap event emission from explicit `Telemetry.Snapshot()`. The arena now snapshots at `ROUND_RESULT` only. A runtime confirmation produced 894 SHADOW observations during round 1; no snapshot file existed during the first 30 seconds, and the file appeared only after the round-result boundary. This confirms that SHADOW observations no longer force per-observation disk snapshots.

This validates the I/O hypothesis but is not a complete frame-pacing benchmark. CPU/UPS and per-update timing counters remain future work.

## Decision

- SHADOW smoke: pass for instrumentation plumbing.
- SHADOW semantic readiness: incomplete; collect a richer trace.
- TASKS activation: no-go.
- TACTICAL activation: strong no-go.
- Production default: remain `OFF`.

## Next evidence step

Capture a larger SHADOW sample using the deterministic any-visible LOS selection and the new counters for visible opponents, visibility checks, contact acquisition/loss, actor skips, and AI V2 execution cost. Then complete the 50-round OFF baseline for comparison.

## Follow-up native semantic smoke

A native Windows `Debug Release|x64` build completed successfully before this run. A temporary SHADOW run then completed three rounds before being stopped and the source mode was restored to `OFF`.

- Observations: 2,597 across the three completed-round summaries.
- Both teams represented: team 0 = 1,411 observations; team 1 = 1,192 observations.
- Pre-touchdown observations: 0.
- Watchdogs: 0.
- Visible opponents: 0.
- LOS-positive observations: 0.
- Firing-positive observations: 0.
- Contact acquisitions/losses: 0/0.
- Reported `shadowObservationTimeMS`: 0 in all three summaries; this is not accepted as valid execution-cost evidence and requires instrumentation follow-up.

This validates native loading, lifecycle gating, telemetry emission, and runtime stability only. It does not pass the semantic SHADOW gate and does not justify TASKS-A.

## Sensor-validation follow-up

After the failed smoke, the LOS sensor was changed from `CastObstacleRay` to `CastMORay` with explicit target/root-MOID matching. The native build passed again, and a fresh three-round SHADOW run completed.

- Observations: 2,637 across the three summaries.
- Both teams represented: team 0 = 1,423; team 1 = 1,244.
- Pre-touchdown observations: 0.
- Watchdogs: 0.
- Visible opponents: 0.
- LOS-positive observations: 0.
- Fire events: 0.
- Contact acquisitions/losses: 0/0.
- Damage events: 2,707; 153; and 239 by round.
- SHADOW CPU time: 185 ms; 276 ms; and 270 ms by round.

Raw ray fields are now included in observations. Sampled first-hit values were commonly `hitMOID=255` with valid target MOIDs, indicating that the target was not the first ray hit. This confirms the sensor is no longer treating a target hit as a generic obstacle, but it does not yet establish useful direct visibility during the observed combat positions.

The semantic gate remains failed. The next step is an engine-backed deterministic LOS fixture or controlled scene, not TASKS-A or the canonical OFF baseline.

## Selection-dispatch correction

Native diagnostic telemetry subsequently produced `rayClassification=TARGET`
with `visibleOpponentCount=0`. Investigation found that
`SelectVisibleOpponent` is a static controller helper but was called with Lua
instance syntax (`:`), shifting its arguments and preventing all visible
selection. Commit `cd4ed43b3` corrects that call to `.`.

The same checkpoint adds native-aligned body/eye probe ordering, deterministic
ray classifications, and `losProbeRays` accounting. The controller and source
integration tests pass, and the native Windows `Debug Release|x64` build passes.
Production source was restored to `AI_V2_MODE = "OFF"` after each test.

No fresh post-fix completed round is recorded yet: the final temporary SHADOW
launch remained responsive but did not begin the spectator activity or update
the event log. Therefore the selector fix is implementation-verified, not
semantic-runtime-validated. Do not advance to TASKS-A, merge/PR, or the 50-round
OFF baseline until a fresh direct-launch semantic smoke completes.
