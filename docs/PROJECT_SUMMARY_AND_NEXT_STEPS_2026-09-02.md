# Cortex Command Community Project — Project Summary and Next Steps

Date: 2026-09-02
Branch: `spectator-random-factions`

## Executive summary

This project is a Cortex Command community-project checkout with an autonomous spectator arena. The current work is a staged AI V2 foundation designed to improve squad-level coordination without replacing the engine's native human AI or changing the existing touchdown/release safety behavior.

The implementation is intentionally conservative: production remains `AI_V2_MODE = "OFF"`. AI V2 currently supports round-scoped observations and pure decision helpers, while SHADOW mode is available for proposal/telemetry capture. No behavior-enabled comparison has been made yet.

## Current architecture

- `SpectatorArena.lua` owns round setup, faction selection, actor spawning, touchdown gating, battle lifecycle, native AI configuration, telemetry, and camera behavior.
- `NativeHumanAI` remains responsible for local actor behavior: aiming, firing, reload, locomotion, jetpack use, digging, and immediate reactions.
- `SpectatorAIController.lua` is the AI V2 coordinator/state layer. It currently stores observations and deterministic rules without directly controlling actors.
- `SpectatorTelemetry.lua` emits structured `SPECTATOR_EVENT` records and can snapshot them to `SPECTATOR_EVENT_LOG.txt`.
- `spectator_soak_report.py` parses runtime event logs and reports round counts, winners, durations, incomplete rounds, and watchdog events.

## AI V2 design

The approved design uses a coordinator above native AI with four intended modes:

- `OFF`: current production behavior.
- `SHADOW`: observe and propose, but never apply actor control.
- `TASKS`: assign bounded squad tasks.
- `TACTICAL`: apply carefully gated tactical orders after evidence supports activation.

The intended squad model is two four-actor squads per team. Planned tasks are `PRESSURE`, `MANEUVER`, `SEARCH`, `REGROUP`, and `RECOVER`. The design includes engagement locks, imperfect contact memory, task hysteresis, soft target reservations, progress/recovery escalation, and weapon/environment scoring.

## Implemented AI V2 capabilities

### Contact and engagement state

- Frozen direct-contact positions.
- Lower-confidence memory/shared reports do not rewrite the frozen direct position.
- Configurable contact expiry, currently defaulting to 3000 ms.
- Engagement locks with explicit expiry.

### Tasks, reservations, and recovery

- Task assignment hysteresis prevents rapid task churn.
- Target reservations enforce a per-target limit and remove stale reservations.
- Progress observations escalate recovery one stage at a time, bounded by a configurable maximum.

### Weapon and environment scoring

- Pure weapon classification into `CLOSE`, `MID`, `LONG`, or `UNKNOWN`.
- Destination scoring considers distance, cover, line of sight, and threat.
- Candidate destination selection rejects marginal improvements to reduce oscillation.

### SHADOW observations

After all living actors pass the existing touchdown/release gate, SHADOW mode can observe:

- nearest opponent and distance;
- line of sight;
- current-frame firearm firing;
- health and previous health;
- current AI waypoint and path state;
- progress toward the current waypoint;
- recovery stage.

These observations emit `AI_SHADOW_OBSERVATION` telemetry and do not set AIMode, add or clear waypoints, alter position, alter health, alter inventory, or inject controller input.

Telemetry performance correction: `Telemetry.Emit()` is now cheap and no longer snapshots the full console. Explicit snapshots occur at low-frequency round-result boundaries, eliminating per-observation disk writes during SHADOW.

## Verified engine APIs

Observation-safe APIs include actor health/previous health, aim angle, last AI waypoint, move-path state, dig/jump properties, firearm firing/muzzle state, wound count, SceneMan distance/ray queries, MovableMan local MO queries, AI timing values, and bounded path-calculation interfaces.

Mutating interfaces such as `ClearAIWaypoints`, `AddAISceneWaypoint`, `AddAIMOWaypoint`, `SetMovePathToUpdate`, actor setters, and controller-input methods are reserved for future TASKS/TACTICAL work. No direct killer/instigator binding was identified, so future contact attribution must remain conservative and inference-based.

## Verification status

Passing checks:

- Lua controller tests under the cached Fengari runner.
- Lua telemetry test.
- Python test suite: 3 tests.
- SHADOW integration source tests: 3 tests.
- `git diff --check`.
- `RTE.sln` Debug Release x64 build with 0 errors.

The build still emits existing compiler warnings; no new build failure is present.

## Runtime evidence

Telemetry transport was verified through activity-scoped `SPECTATOR_EVENT_LOG.txt` snapshots and orderly shutdown behavior. The preliminary OFF sample contains four completed rounds across two short runs:

- Ronin wins: 2.
- Dummy wins: 2.
- Watchdog events: 0.
- Completed-round durations: approximately 34.0–60.5 seconds.

This is not an activation baseline. The approved evidence gate requires at least 50 completed OFF-mode rounds before defining activation thresholds.

## Known limitations and discrepancies

- AI V2 scoring helpers are implemented and tested but are not yet driving actor behavior.
- The first non-default SHADOW plumbing smoke trace passed instrumentation, but it produced no LOS-positive or firing-positive observations.
- The follow-up evidence phase now evaluates all living opponents for LOS, selects the nearest visible opponent, and records aggregate visibility, contact-transition, actor-skip, and execution-cost metrics.
- A native three-round SHADOW smoke was completed after the Windows Debug Release x64 build. It showed both teams and zero pre-touchdown observations/watchdogs, but still had zero visible opponents, LOS positives, firing positives, and contact transitions; reported execution cost was zero and is not yet trusted.
- A sensor-validation follow-up replaced obstacle-ray boolean interpretation with explicit `CastMORay` target/root-MOID matching. Three fresh rounds produced nonzero CPU-cost measurements (185/276/270 ms) and durable damage events, but still zero visible opponents, LOS positives, fire events, or contact transitions. Raw ray IDs are now recorded; semantic validation remains blocked.
- No claim can be made about improved win rate, tactical quality, CPU/UPS impact, recovery quality, or hidden-position violations.
- The nearest-enemy observation is conservative but does not provide direct killer/instigator attribution.
- The existing camera-review files are separate user work and remain dirty/uncommitted.

## Recommended next steps

1. Validate LOS semantics with deterministic tests and distinguish nearest-opponent LOS from any-visible-opponent LOS.
2. Add aggregate counters and measured execution-cost fields to the next SHADOW trace.
3. Run a second semantic SHADOW smoke requiring LOS-positive, contact, firing, and damage evidence.
4. Complete the 50-round OFF baseline and record winner distribution, duration distribution, watchdog rate, incomplete rounds, runtime stability, and CPU/UPS if available.
5. Compare SHADOW observations against the OFF baseline, then request explicit approval before changing the default from OFF or applying TASKS behavior.
6. Only after evidence supports it, implement one narrow behavior-enabled experiment with rollback and a matched OFF comparison.

## Recent committed work

- `369a1cc45` — Record spectator AI V2 shadow implementation status
- `143439d54` — Add spectator AI V2 shadow observations
- `6c41463a4` — Add deterministic spectator AI weapon environment scoring
- `7bfefb573` — Add spectator AI V2 task and recovery rules
- `de6f348f1` — Add spectator AI V2 contact observations
- `37b32e3af` — Audit local spectator AI APIs
- `f7c27b0bf` — Plan spectator AI V2 shadow implementation
- `b7be3c4c0` — Specify spectator AI V2 shadow design

## Review request

The next reviewer should assess whether the SHADOW observation boundary is genuinely behavior-neutral, whether contact/progress semantics are sound, whether the proposed evidence gates are sufficient, and what smallest safe behavior-enabled experiment should follow the evidence phase.
