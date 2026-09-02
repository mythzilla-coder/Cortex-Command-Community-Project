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

The current 500 ms observation cadence should not be treated as a reliable firing-event detector. A future implementation should capture high-frequency fire/damage timestamps and let the slower tactical loop consume those observations.

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

Capture a larger SHADOW sample after adding explicit counters for contact acquisition/loss, memory expiry, target reservations, recovery transitions, actor skips, malformed telemetry, ray count, and AI V2 execution cost. Then complete the 50-round OFF baseline for comparison.
