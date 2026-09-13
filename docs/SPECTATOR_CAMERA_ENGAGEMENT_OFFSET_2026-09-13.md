# Spectator camera engagement offset — 2026-09-13

## Decision

Implement the approved spectator-camera follow-up in an isolated worktree and keep it behind the existing spectator camera priority rules. The feature is a review candidate pending a targeted rendered-frame review.

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

## Visual acceptance — 2026-09-13

- Focused Debug Release capture: 50 frames over approximately 25 seconds from an isolated worktree.
- Three runtime engagement transitions were observed in the same session: each `CAMERA_FIRE_CONTROLLER` was followed by `CAMERA_ENGAGEMENT`.
- Reviewed frames kept the firing side, opposing side, and active shot effects readable during combat; no sampled jitter or empty-terrain lock was observed.
- The camera returned to ordinary follow framing between combat phases, including round transition and regrouping views.

Decision: **ACCEPTED_FOR_THIS_REVIEW_BUILD**. This accepts the engagement-offset behavior for PR #284; the older event-aware camera milestone remains a separate review item.
