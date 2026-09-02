# ChatGPT Review Handoff — Cortex Command AI V2

You are reviewing the Cortex Command Community Project's spectator AI V2 work on branch `spectator-random-factions`.

## Context

The project runs an autonomous spectator arena using Cortex Command's native `NativeHumanAI`. The approved direction is to add a coordinator above native AI rather than replace native actor behavior. Production must remain `AI_V2_MODE = "OFF"` until evidence supports activation.

## What has been implemented

- Round-scoped AI V2 controller state.
- Frozen direct contact memory with confidence expiry.
- Engagement locks with expiry.
- Task hysteresis.
- Bounded target reservations and stale-reservation cleanup.
- One-stage-at-a-time recovery escalation.
- Pure CLOSE/MID/LONG weapon classification.
- Destination scoring using range, cover, LOS, and threat.
- SHADOW-only post-touchdown observation collection for opponent, LOS, firing, health, waypoint/path, progress, and recovery.

## Safety constraints

- NativeHumanAI remains authoritative.
- V11/V11.1 touchdown/release behavior must not change.
- OFF and SHADOW must not mutate AIMode, waypoints, actor position, health, inventory, or controller input.
- No behavior improvement may be claimed without matched OFF and behavior-enabled evidence.
- Camera-review files in the working tree are separate user work; do not modify or commit them.

## Evidence status

- Lua and Python tests pass.
- Debug Release x64 build passes with 0 errors.
- Four completed OFF rounds have been observed in preliminary short runs.
- The required OFF baseline is 50 completed rounds.
- The first non-default SHADOW trace was captured: 2,393 observations across four started rounds, with no LOS-positive or firing-positive samples. It passed lifecycle and plumbing checks but was semantically incomplete.
- The telemetry path no longer snapshots the console per event; explicit snapshots occur at round-result boundaries.
- Deterministic nearest-visible opponent selection and aggregate SHADOW visibility/cost/contact metrics are now implemented in the latest checkout.

## Review questions

1. Inspect `Data/Base.rte/Activities/SpectatorAIController.lua` for semantic, numerical, and edge-case issues in contact expiry, task hysteresis, reservations, recovery escalation, weapon classification, and destination scoring.
2. Inspect `Data/Base.rte/Activities/SpectatorArena.lua` and confirm that SHADOW observation is truly post-release, nil-safe, bounded, and behavior-neutral.
3. Identify any engine API assumptions that should be verified before runtime SHADOW capture.
4. Recommend the smallest useful SHADOW evidence experiment and the exact metrics to collect.
5. Recommend whether to prioritize the 50-round OFF baseline, SHADOW capture, parser/report improvements, or another safety task.
6. Propose one narrowly scoped behavior-enabled experiment only if the evidence gate is satisfied; include rollback criteria. TASKS remains blocked for now.

## Desired review output

Return:

- findings ordered by severity;
- concrete code/documentation corrections;
- a prioritized next-step plan;
- explicit separation of verified facts, inferences, and open questions;
- a go/no-go recommendation for SHADOW capture and later TASKS activation.

Primary local references:

- `docs/PROJECT_SUMMARY_AND_NEXT_STEPS_2026-09-02.md`
- `docs/superpowers/specs/2026-09-02-spectator-ai-v2-shadow-design.md`
- `docs/superpowers/plans/2026-09-02-spectator-ai-v2-shadow-implementation.md`
- `Data/Base.rte/Activities/SpectatorAIController.lua`
- `Data/Base.rte/Activities/SpectatorArena.lua`
- `tests/spectator_ai_controller_test.lua`
- `tests/spectator_ai_integration_test.py`

Drive review bundle:

- [Source snapshot manifest](https://drive.google.com/file/d/1Y8SULsRv7pW2IiRyw3FqtEH2g466ATZn/view)
- [SpectatorAIController.lua](https://drive.google.com/file/d/1z-ejFEDlVaflUMfJwFr3s3XlNBHAAUse/view)
- [SpectatorArena.lua](https://drive.google.com/file/d/1CEyZGfMjzwKhi_HZ1XPRzBXpmVmmYnCE/view)
- [Controller tests](https://drive.google.com/file/d/19xOIqYhNJYw8VPA87DPCIMQHSMWx7tzO/view)
- [Integration tests](https://drive.google.com/file/d/1MZtVsiG4hahyitxMeuU3QNd-zuhzLxjx/view)
- [Telemetry test](https://drive.google.com/file/d/1O7URrZAL5PkVdk207Tlctx23UWg1iXTu/view)
- [Soak report parser](https://drive.google.com/file/d/15ki8-2vuP5nnYj5ZPqVn1awVeHr10Tqe/view)
