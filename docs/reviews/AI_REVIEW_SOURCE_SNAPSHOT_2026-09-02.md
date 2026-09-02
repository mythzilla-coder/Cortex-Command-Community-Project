# AI V2 Review Source Snapshot

Generated: 2026-09-02
Branch: `spectator-random-factions`
HEAD at snapshot creation: `26b5f35f2a69d3d3f43c9b57ae05712340382eef`

This manifest accompanies the source files uploaded to Drive for independent ChatGPT review. The local repository remains the engineering source of truth.

## Uploaded source files

- `Data/Base.rte/Activities/SpectatorAIController.lua` — controller state, contact memory, engagement, task/reservation/recovery rules, and pure scoring helpers.
- `Data/Base.rte/Activities/SpectatorArena.lua` — complete activity source, including the post-release SHADOW observation boundary.
- `tests/spectator_ai_controller_test.lua` — pure controller tests.
- `tests/spectator_ai_integration_test.py` — source-level integration/safety tests.
- `tests/spectator_telemetry_test.lua` — telemetry behavior test.
- `tools/spectator_soak_report.py` — runtime event parser.

## Canonical local state

- AI V2 mode: `OFF`.
- NativeHumanAI: authoritative for actor behavior.
- Touchdown/release: V11/V11.1 behavior preserved.
- Verification: Lua tests pass, Python tests pass, integration tests pass, `git diff --check` passes, and Debug Release x64 build passes with 0 errors.
- Runtime evidence: four completed OFF rounds in preliminary short runs; 50 completed rounds remain required for the baseline.

## Intentionally dirty/untracked user work

These files are separate camera-review work and are not part of the AI V2 source snapshot:

- `docs/DIRECT_LAUNCH_SPECTATOR.md`
- `docs/HANDOFF_CAMERA_HYBRID_REVIEW.md`
- `Data/Base.rte/Activities/SpectatorCameraEventLogic.lua`
- `docs/HANDOFF_CAMERA_EVENT_AWARE.md`
- `_research_spectator_mod/`
- `tests/spectator_camera_event_test.lua`

Generated Python cache directories are also untracked and are not review artifacts.

## Review boundary

SHADOW currently records nearest-opponent/world-query observations for diagnostics. These observations must not be treated as team knowledge unless visibility/share rules authorize them. No TASKS or TACTICAL behavior is enabled.
