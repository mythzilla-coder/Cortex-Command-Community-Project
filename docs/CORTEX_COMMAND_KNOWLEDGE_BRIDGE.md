# Cortex Command — Shared Knowledge Bridge

Last synchronized: 2026-09-02

This is the repository-side continuity contract for regular ChatGPT and Codex. External Drive and Notion records are continuity mirrors; newer local Git, tests, and runtime evidence take precedence.

## Source-of-truth order

1. Local Git state and runtime/test evidence.
2. Current repository documentation under `docs/`.
3. The shared Google Drive bridge and canonical `SPECTATOR_ARENA.md`.
4. Notion project dashboard.
5. Historical snapshots and older chat context.

Before implementation, inspect `git status`, the current branch/HEAD, recent history, tags, local handoffs, and relevant logs. Never reset or overwrite newer local work with an older external snapshot.

## Repository

`C:\Users\mythz\Documents\Cortex-Command-Community-Project`

Current local branch: `spectator-random-factions`  
Current local HEAD: `d5c9b787c Integrate spectator AI V2 controller in off mode`

Important local milestones:

- `spectator-soak-2026-08-31`: approximately 1h44m unattended, round 66, 65 completed matches, observed score 36–29.
- `53c2b1f2d`: V10.1 AI baseline.
- `94ee8e328`: V11 touchdown gate.
- `de7031896`: V11.1 target-spread improvement.
- `46755ce40`: telemetry sink emission fix.

## Current product

Spectator Arena is an autonomous real-time 8v8 AI-vs-AI activity on `Ketanot Hills`. Its loop is:

`spawn -> fight -> winner detection -> score update -> reset -> next round`

The lifecycle is:

`BOOT -> PREPARE_ROUND -> SPAWN_TEAMS -> BATTLE -> ROUND_RESULT -> ROUND_RESET`

Direct launch is source-controlled through `Source/Main.cpp`; `Userdata/Settings.ini` remains runtime state and must not be committed.

## Accepted AI state

V11/V11.1 AI behavior is accepted and frozen for now. Actors spawn in SENTRY, must touch terrain before distributed pursuit, are released individually after touchdown, and landed teammates are redistributed when another teammate lands. Do not resume pursuit-pulse/tap experiments or modify native AI files without a new explicit decision.

## Unresolved camera milestone

The event-aware hybrid camera remains uncommitted and pending human visual acceptance. Its priority is:

`LAST_SURVIVOR > CAMERA_EVENT > CAMERA_SOLDIER > CAMERA_POI > CAMERA_CENTER`

Review values are a 400 ms fire window, 2000 ms event hold, 4000 ms cooldown, 180–1200 pixel range, 0.85 aim-dot threshold, and per-round victim deduplication. Attribution is conservative inference, not engine-confirmed killer attribution.

Required before commit: review 3–5 complete rounds, observe a credible off-screen event cut, confirm timing, no false cuts, clean return to soldier-follow, deduplication, and last-survivor priority.

Read:

- `docs/HANDOFF_CAMERA_EVENT_AWARE.md`
- `docs/HANDOFF_CAMERA_HYBRID_REVIEW.md`
- `docs/SPECTATOR_ARENA.md`

## Observability state

The telemetry helper and Python soak parser are implemented and unit-tested. Root-cause review found that Lua `print` is routed into the in-memory `ConsoleMan` buffer, while `LogConsole.txt` is written only during orderly `ConsoleMan::Destroy()`. The activity now snapshots the console buffer to ignored `SPECTATOR_EVENT_LOG.txt` after telemetry events. A fresh smoke run produced the expected records; a longer soak is still needed for completed-round statistics.

Relevant files:

- `Data/Base.rte/Activities/SpectatorTelemetry.lua`
- `tools/spectator_soak_report.py`
- `tests/spectator_telemetry_test.lua`
- `tests/spectator_camera_event_test.lua`
- `tests/test_spectator_soak_report.py`

## AI V2 status

The first behavior-neutral foundation is present in `Data/Base.rte/Activities/SpectatorAIController.lua`, and `SpectatorArena.lua` now wires it in explicit `OFF` mode. Actors are registered at spawn, released only at the existing accepted touchdown boundary, and sampled at a low cadence after `AI_TOUCHDOWN_ALL_RELEASED`; the controller does not mutate actors, AIMode, waypoints, controllers, or combat behavior. `AI_V2_CONFIG` is emitted through the existing telemetry helper.

This is instrumentation only. Do not enable `TASKS` or `TACTICAL` behavior until baseline and SHADOW evidence exists. Runtime telemetry capture is now functioning through the activity-scoped `SPECTATOR_EVENT_LOG.txt` snapshot path, but the 50-round OFF-mode baseline is still incomplete.

## Work protocol

Prefer deterministic tests, logs, state, and soak reports during autonomous work. Preserve unrelated changes. Record meaningful progress in `docs/AUTONOMOUS_WORK_LOG.md` and a dated session summary. Synchronize external Drive/Notion state only after verified local milestones.

Next decision gate:

`collect OFF-mode baseline -> visually review camera -> accept/reject camera -> commit/synchronize -> build minimal stream-facing HUD`
