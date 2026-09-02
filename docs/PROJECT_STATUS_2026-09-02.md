# Cortex Command Community Project — Development Status

Date: 2026-09-02  
Branch: `spectator-random-factions`  
Current HEAD: `a8d178ffb Record extended spectator baseline sample`

## What the project is

The project is a dedicated autonomous Spectator Arena build for Cortex Command Community Project. It launches an 8v8 AI-vs-AI activity on `Ketanot Hills`, with randomized faction matchups and an automated lifecycle:

`spawn -> touchdown/release -> battle -> winner detection -> score update -> next round`

The normal menu and engine systems remain available in the source, but the debug full executable is configured to launch the spectator activity directly.

## Accepted behavior

V11/V11.1 behavior is the current frozen gameplay baseline:

- Actors spawn in SENTRY mode.
- Actors must touch terrain before the existing distributed pursuit logic releases them.
- Release is individual, and landed teammates are redistributed when another teammate lands.
- NativeHumanAI remains responsible for aiming, firing, locomotion, jetpack behavior, digging, and local reactions.

No AI V2 tactical orders are enabled.

## AI V2 development state

The AI V2 work is intentionally staged:

1. Behavior-neutral controller state and metrics exist in `Data/Base.rte/Activities/SpectatorAIController.lua`.
2. `SpectatorArena.lua` integrates the controller in explicit `AI_V2_MODE = "OFF"`.
3. Actors are registered at spawn, released at the accepted touchdown boundary, and sampled at 500 ms cadence after all actors release.
4. `AI_V2_CONFIG` is emitted through telemetry.

The controller currently does not change actor AIMode, waypoints, controllers, targeting, combat, or camera behavior. SHADOW, TASKS, and TACTICAL modes remain future work and require baseline evidence first.

## Telemetry and baseline evidence

Telemetry is encoded as `SPECTATOR_EVENT event=...` records. The engine prefixes Lua console output with `PRINT:`; the parser accepts this real runtime form. The activity snapshots the console buffer to the ignored file `SPECTATOR_EVENT_LOG.txt` after telemetry events because the legacy `LogConsole.txt` is only written during orderly shutdown.

Observed preliminary evidence:

- Four completed rounds across two fresh OFF-mode runs.
- Winners: `RONIN_WINS=2`, `DUMMY_WINS=2`.
- Watchdog events: `0`.
- Observed completed-round duration range: `34,015.306–60,464.248 ms`.
- The required activation baseline is at least 50 completed rounds; it has not been reached.

The report tool is `tools/spectator_soak_report.py`. It reports completed/incomplete rounds, winner counts, durations, and watchdog events.

## Camera state

The event-aware hybrid camera work is present locally but remains uncommitted and requires human visual acceptance over 3–5 complete rounds. Review priorities are last survivor, camera event, soldier follow, combat POI, then center. No camera acceptance should be inferred from automated tests.

## Verification

Passing checks include:

- Lua controller, telemetry, and camera-event tests under cached Fengari.
- Python soak-report and integration tests.
- `git diff --check`.
- Debug Release x64 MSBuild.
- Fresh executable runtime capture with expected activity, configuration, round, and battle telemetry.

## Recommended next decisions

1. Continue the OFF-mode soak to 50 completed rounds and preserve the report as the activation baseline.
2. Perform human visual camera review and either accept or revise the uncommitted camera work.
3. Only after both gates, begin SHADOW contact/progress observations; do not enable tactical orders until SHADOW evidence is reviewed.
