# Spectator camera engagement offset — 2026-09-13

## Decision

Implement the approved spectator-camera follow-up in an isolated worktree and keep it behind the existing spectator camera priority rules. The feature is a review candidate; visual acceptance remains open until a targeted capture shows several opposite-edge exchanges.

## Behavior

- Preserve ordinary soldier follow as the default.
- On a followed actor's firing edge, find the nearest living enemy in the aim cone, excluding same-team, behind-shooter, too-near, and out-of-range actors.
- Frame 55% of the way from shooter to enemy so the enemy and the shot line are visible without abandoning the shooter.
- Hold the engagement frame for 900 ms, then return to soldier follow.
- Apply a 1400 ms cooldown and preserve event/death and last-survivor priority.

## Implementation

- `SpectatorCameraEventLogic.lua` contains the pure target-selection and frame interpolation helpers.
- `SpectatorArena.lua` owns timers, cooldowns, actor snapshots, native firearm signals, and the controller-fire fallback.
- `spectator_camera_event_test.lua` covers cone, team, range, and frame bias.
- `spectator_ai_integration_test.py` covers activity integration and priority ordering.

## Verification

- Lua behavioral tests: PASS.
- AI controller Lua tests: PASS.
- Python integration suite: 10 tests PASS.
- Lua load/syntax checks: PASS.
- `git diff --check`: PASS.
- Native `Debug Release|x64` build: PASS, 0 errors; existing compiler/project warnings remain.
- Native runtime log: `CAMERA_FIRE_CONTROLLER` followed by `CAMERA_ENGAGEMENT` in a completed round.

The runtime observation was sampled from a local Debug Release session; it was not treated as a complete visual acceptance run. The next acceptance capture should deliberately include two actors at opposite screen edges, confirm that both remain readable during exchange, and confirm the timed return to follow.
