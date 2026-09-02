# Autonomous work log

## 2026-09-02 — Project grounding and observability checkpoint

Changed:
- Confirmed the actual repository at `C:\Users\mythz\Documents\Cortex-Command-Community-Project`.
- Read the canonical Google Drive development state: AI V11.1 is accepted; event-aware camera remains uncommitted pending human visual review.
- Added `Data/Base.rte/Activities/SpectatorTelemetry.lua` and integrated meaningful activity/round/state/watchdog events into `SpectatorArena.lua`.
- Added a pure-Lua telemetry test and telemetry format documentation.

Verification:
- `git diff --check` — PASS.
- Lua tests — BLOCKED: no standalone `lua` executable is installed or discoverable in this environment.
- No game run performed; no visual acceptance was inferred.

Preservation:
- Existing camera and AI experimental files remain unmodified by this checkpoint.
- No camera acceptance or production claim made.

Next:
- Run Lua tests with the game/runtime interpreter.
- Use `tools/spectator_soak_report.py` on a captured game log and extend fields only when real output confirms them.

## 2026-09-02 — AI V2 instrumentation foundation

Changed:
- Reviewed the AI V2 pre-coding blueprint from Google Drive.
- Added the behavior-neutral `SpectatorAIController` state/metrics module.
- Added tests for OFF mode, round reset, touchdown release state, bounded progress samples, frozen contact memory, and deterministic snapshots.
- Added an implementation plan at `docs/superpowers/plans/2026-09-02-spectator-ai-v2-instrumentation.md`.

Verification:
- New Lua controller test — PASS under cached Fengari.
- Existing telemetry and camera Lua tests — PASS.
- Python suite — 2 tests PASS.
- `git diff --check` — PASS.

Preservation:
- Controller is not integrated into `SpectatorArena.lua` yet.
- Default mode is `OFF`; no actor behavior, NativeHumanAI, touchdown, waypoint, or camera behavior changed.

Next:
- Integrate observation only after `AI_TOUCHDOWN_ALL_RELEASED`, retaining OFF as the default.
- Resolve live `SPECTATOR_EVENT` transport before baseline soak claims.

## 2026-09-02 — AI V2 OFF-mode activity integration

Changed:
- Wired `SpectatorAIController` into `SpectatorArena.lua` without changing V11/V11.1 actor behavior.
- Added round generation reset, spawn registration, accepted touchdown-release recording, and 500 ms released-actor position sampling.
- Added `AI_V2_CONFIG version=2 mode=OFF` through the existing telemetry path.
- Added a source-level integration test proving the release boundary and no tactical actor mutations in the instrumentation function.

Verification:
- Focused controller and integration Lua/Python checks — PASS.
- Full Python suite — 2 tests PASS.
- Debug Release x64 MSBuild — PASS (existing compiler/linker warnings only).
- `git diff --check` — PASS.
- Fresh executable smoke launch stayed alive for the smoke window; legacy `LogConsole.txt` did not refresh, so no new round-level runtime claim is made.

Preservation:
- `AI_V2_MODE` remains `OFF`; no tasks, tactical orders, contact sharing, or NativeHumanAI replacement was enabled.
- Uncommitted camera-review files remain untouched and uncommitted.

## 2026-09-02 — Telemetry transport root-cause review

Finding:
- Lua `print` is overridden by the engine to call `ConsoleMan:PrintString`, so the telemetry helper’s default emission path is valid.
- `LogConsole.txt` is written from `ConsoleMan::Destroy()` as a shutdown snapshot. Forced process termination can discard buffered records, explaining the apparent live-log gap.

Action:
- Documented `-cout` stdout capture and orderly shutdown as the valid runtime verification paths.
- Added an activity-scoped `SPECTATOR_EVENT_LOG.txt` snapshot path and taught the soak parser to accept the engine’s `PRINT:` prefix.

Verification:
- Fresh rebuilt executable smoke run produced 11 `SPECTATOR_EVENT` records, including `AI_V2_CONFIG`, `ROUND_START`, and `BATTLE` state.
- The parser correctly reported `1` started and `0` completed rounds for the intentionally short run.
- Runtime snapshot is ignored by Git; no generated log is committed.

## 2026-09-02 — Preliminary OFF-mode baseline soak

Observed:
- Fresh rebuilt executable ran through two completed rounds and entered a third before the exact process was stopped.
- Results: `2/3` rounds completed, winners `RONIN_WINS=1`, `DUMMY_WINS=1`, watchdog events `0`.
- Completed-round durations were `33915.31 ms` and `60464.248 ms` (average `47189.779 ms`).

Correction:
- The live engine emits decimal `durationMS` values. Updated `tools/spectator_soak_report.py` and its test to parse numeric durations instead of integers only.

Status:
- This is preliminary evidence, not the required 50-round activation baseline.

## 2026-09-02 — Extended OFF-mode baseline sample

Observed:
- A second fresh run completed two additional rounds before round 3 remained active at the evidence checkpoint.
- This run: `2/3` rounds completed, winners `RONIN_WINS=1`, `DUMMY_WINS=1`, watchdog events `0`.
- Completed-round durations were `37798.488 ms` and `34015.306 ms` (average `35906.897 ms`).

Status:
- Combined with the earlier sample, four completed rounds are now observed across two runs; this remains far below the required 50-round baseline.
- `AI_V2_MODE` remains `OFF`; no SHADOW or tactical activation decision is justified yet.

## 2026-09-02 — Deterministic soak parser

Changed:
- Added `tools/spectator_soak_report.py` to aggregate structured events.
- Added two Python unit tests covering noise, completed rounds, incomplete final rounds, durations, and watchdog events.

Verification:
- `python -m unittest tests/test_spectator_soak_report.py -v` — PASS (2 tests).
- `git diff --check` — PASS.

Commit:
- `642c549f0 Add spectator soak report parser`

## 2026-09-02 — Local AI and navigation API audit

Verified observation-safe interfaces for the spectator AI V2 shadow layer:

- Actor state: `Health`, `PrevHealth`, `MaxHealth`, `GetAimAngle`, `GetLastAIWaypoint`, `MovePathEnd`, `MovePathSize`, `IsWaitingOnNewMovePath`, `AIBaseDigStrength`, `JumpHeight`, and `DigStrength`.
- Weapon state: held `HDFirearm` `FiredFrame` and `MuzzlePos`.
- Damage state: `MOSRotating.WoundCount`.
- World queries: `SceneMan:ShortestDistance`, obstacle/strength/MO ray casts, `SceneMan:GetLastRayHitPos`, and `MovableMan:GetMOsAtPosition`.
- Navigation support: `Scene:CalculatePath` and `CalculatePathAsync` are available, but path calculation is potentially expensive and must remain bounded and cadence-limited in any future planner.
- Timing: `SettingsMan.AIUpdateInterval` and `TimerMan.AIDeltaTimeMS` are available for cadence-aligned sampling.

Safety boundary:

- `ClearAIWaypoints`, `AddAISceneWaypoint`, `AddAIMOWaypoint`, `SetMovePathToUpdate`, actor setters, and controller-input methods are mutating interfaces. They remain reserved for future TASKS/TACTICAL modes and must not be called by OFF or SHADOW instrumentation.
- No direct killer/instigator binding was identified in the inspected Lua-facing APIs. Any future contact attribution must therefore remain conservative and inference-based unless a stronger engine signal is found.

Status:
- The audit confirms enough local read-only data to implement contact memory, engagement observations, and bounded scoring without replacing `NativeHumanAI` or changing V11/V11.1 touchdown/release behavior.

## 2026-09-02 — AI V2 shadow implementation phases 2–5

Implemented and committed the pure shadow-layer foundations:

- Contact memory with frozen direct positions, confidence updates, expiry, and engagement-lock observations.
- Task hysteresis, bounded target reservations with stale-expiry cleanup, and one-stage-at-a-time recovery escalation.
- Engine-independent weapon classification and destination scoring for range, cover, line of sight, threat, and meaningful-improvement filtering.
- SHADOW-only arena observations after the existing touchdown/release gate, covering nearest opponent, LOS, firing, health, waypoint/path state, progress, and recovery stage.

Verification:
- Focused Lua controller tests — PASS under the locally restored cached Fengari runner.
- Telemetry Lua test — PASS.
- Python test suite — 3 tests PASS.
- SHADOW integration source tests — 3 tests PASS.
- `git diff --check` — PASS.
- `RTEA.sln` Debug Release x64 build — PASS, 0 errors; existing compiler warnings remain.

Evidence boundary:
- No behavior-enabled AI decision has been activated.
- No non-default SHADOW runtime trace has yet been used to claim contact, task, recovery, CPU/UPS, or tactical quality improvements.
- Production remains OFF pending a deliberate SHADOW evidence capture and the required 50 completed OFF-mode baseline rounds.

## 2026-09-02 — SHADOW smoke test

Observed in a temporary non-default SHADOW run:

- 4 rounds started, 3 completed, 0 watchdog events.
- 2,393 `AI_SHADOW_OBSERVATION` records: round counts 768, 714, 735, and 176.
- 0 LOS-positive records and 0 firing-positive records; contact/engagement semantics were therefore not exercised.
- No observation appeared before the first `AI_TOUCHDOWN_ALL_RELEASED` marker.
- Completed-round durations were 37,565.164 ms, 45,114.862 ms, and 47,598.096 ms.

Decision:
- SHADOW instrumentation plumbing passes, but semantic readiness is incomplete. Keep production `OFF`; do not activate TASKS or TACTICAL behavior.
- Full details: `docs/SPECTATOR_AI_V2_SHADOW_SMOKE_REPORT_2026-09-02.md`.

## 2026-09-02 — SHADOW telemetry I/O performance correction

Finding:
- `Telemetry.Emit()` was calling `ConsoleMan:SaveAllText()` for every event, including every SHADOW actor observation. This was a confirmed high-probability source of periodic full-console disk-write stalls.

Changed:
- Separated cheap `Telemetry.Emit()` from explicit `Telemetry.Snapshot()`.
- Moved the arena snapshot to the low-frequency `ROUND_RESULT` boundary.
- Kept production mode `OFF` and preserved the existing telemetry test contract through explicit snapshot verification.

Verification:
- Telemetry/controller Lua tests — PASS.
- Python suite — 3 tests PASS.
- Runtime A/B confirmation: 894 SHADOW observations accumulated before the first round-result snapshot, with no snapshot file during the initial 30-second window; the file appeared after round 1 completed.
- Source restored to `AI_V2_MODE = "OFF"`; camera work remains untouched.

Remaining:
- Add aggregate SHADOW counters and execution-cost timing before another semantic SHADOW run.
