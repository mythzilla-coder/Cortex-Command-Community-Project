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

## 2026-09-04 — Verified long-run raw evidence

Changed:
- Independently parsed `logs/session-2026-09-03-debug-release-0924/` with `tools/spectator_soak_report.py` and a separate line-level cross-check.
- Added `docs/SPECTATOR_LONG_RUN_ANALYSIS_2026-09-03.md` with hashes, statistics, interpretation, and Drive links.

Verified evidence:
- `SPECTATOR_EVENT_LOG.txt`: 104 round starts and 104 completed rounds.
- `LogConsole.txt`: 105 starts and 104 completed rounds; round 105 is an incomplete trailing round after shutdown-time console flushing.
- Winner distribution: Imperatus 28, Browncoats 22, Coalition 21, Techion 17, Ronin 11, Dummy 5.
- Completed-round duration: minimum 22,215.778 ms, maximum 91,712.998 ms, mean 43,078.56525 ms, median 40,656.707 ms.
- Watchdogs: 0. `AI_SHADOW_OBSERVATION` records: 0.
- AI V2 mode is evidenced as `OFF` by the session configuration and trace markers.

Status:
- The 104 completed OFF-mode rounds qualify toward and exceed the canonical 50-round OFF baseline count; the incomplete round is excluded.
- The formal AI activation gate remains `OFF` because this run contains no SHADOW semantic evidence and does not establish behavior quality or CPU/UPS thresholds.

## 2026-09-03 — Debug Release runtime log archive

Changed:
- Launched the newest available executable, `Cortex Command.debug.release.exe`.
- Closed the game through its normal window-close path so buffered console and loading logs were flushed.
- Archived the session output under `logs/session-2026-09-03-debug-release-0924/`.

Captured:
- 5 files, approximately 4.3 MB: `LogConsole.txt`, `LogLoading.txt`, `SPECTATOR_EVENT_LOG.txt`, `SPECTATOR_ARENA_SPAWN_TRACE_LOG.txt`, and `SPECTATOR_ARENA_POST_SPAWN_TRACE_LOG.txt`.
- The preserved console history contains 104 `ROUND_RESULT` records and no watchdog records.
- This launch did not produce new `AI_SHADOW_OBSERVATION` records, so it is not new SHADOW semantic evidence.

Status:
- The process exited normally and the archive is retained for future evaluation.
- The SHADOW evidence gate and 50-round OFF baseline remain unchanged.

## 2026-09-05 bounded integrity/R2 continuation

See SPECTATOR_CONTINUATION_STATUS_2026-09-05.md for exact commands, raw evidence, binary hash, and next capture contract. Confirmed committed missing camera dependency; preserved candidate pending review. Reparsed OFF snapshots: 104/104 event and 104/105 console, zero watchdogs. R1B: 16/16 attached valid retained weapons and empty equipped discovery; 16/16 missing arm MOID, so R2 first divergence remains undetermined. Python 12 tests OK; camera/controller/telemetry Lua PASS. Initial mistyped telemetry filename corrected. No source/settings changes, native build, or native runtime claim. Existing dirty artifacts and historical tag preserved. Starting status/pre-existing tracked patch and Python results saved under work/continuation-2026-09-05/. Dedicated status report committed separately; this appended log remains recoverable with prior user edits intact.
Report commit: 0eb20c432. Drive connector upload success=true, destination parent 0AGSQc2hrH2H_Uk9PVA, file ID 1HSP6eelqR2ttV_oRzESaX4Ir7jcwbxWe. URL: https://drive.google.com/file/d/1HSP6eelqR2ttV_oRzESaX4Ir7jcwbxWe/view?usp=drivesdk

## 2026-09-13 — native camera capture review

Captured and reviewed 50 local PNG frames over approximately 25 seconds from the
visible Debug Release game window at 976x579. The segment covered the end of
round 28 and the beginning of round 29. The camera generally kept active combat
groups in view across the hill/valley and did not show a sustained empty-terrain
lock in the sampled frames. The transition into the next round centered the
airborne squad. No deliberately observed off-screen event cut, return timing,
victim deduplication, last-survivor priority, or 3–5 full-round acceptance was
established. Decision remains **HOLD_FOR_VISUAL_ACCEPTANCE**. Production
`AI_V2_MODE` remains `OFF`.

## 2026-09-05 — isolated broad-development checkpoint

See docs/SPECTATOR_IMPLEMENTATION_STATUS_2026-09-05.md. New implementation is in branch spectator-development-2026-09-05 at C:/Users/mythz/Documents/Codex/2026-09-05/cortex-command-community-project/work/development; it has not been merged or committed as implementation. Native build passed; R2 identified and corrected missing AHuman casts. Preserved corrected SHADOW evidence: 5/5 rounds, zero watchdogs, 1,662 fire events and 693 damage observations (supersedes the earlier three-round interim summary). Independent D1 fixture: health 100->98, wounds 0->1, PASS. HUD/configuration/proposal code remains candidate: first HUD run had an OPENGL32.DLL access violation; repeat visual verification was interrupted by physical Escape. All 16 Python and 10 Lua tests pass at documentation time, but native feature acceptance and TASKS-A GO remain pending. Saved defaults are OFF, retention=false, topology diagnostics=false. Historical tag and this checkout's pre-existing dirty work are preserved. Upload receipts will follow after connector readback.

## 2026-09-13 — engagement camera offset review build

Implemented the approved spectator-camera follow-up in an isolated worktree. The director now biases the camera toward the enemy in the followed actor's firing direction for a short, cooldown-gated engagement frame while preserving event/death and last-survivor priority. The implementation uses native firearm signals when available and a rising `Controller.WEAPON_FIRE` edge as a guarded fallback for the live actor-wrapper attachment mismatch.

Verification passed: pure Lua camera tests, controller Lua tests, 10-test Python integration suite, Lua load checks, `git diff --check`, and native `Debug Release|x64` build with zero errors. A focused 50-frame Debug Release capture from the isolated worktree produced three `CAMERA_FIRE_CONTROLLER` followed by `CAMERA_ENGAGEMENT` transitions. Reviewed frames kept the firing side and opposing side readable, showed normal follow return, and showed no sampled jitter or empty-terrain lock. Engagement-offset decision: **ACCEPTED_FOR_THIS_REVIEW_BUILD**. The older event-aware camera milestone remains separately held; this was a local frame capture, not an MP4 screen recording.

## 2026-09-13 — condition-based DYING accounting capture

Ran the unchanged Arena until the first naturally accepted DYING-correlated
event. The run reached four completed rounds, retained a 120-frame rolling
buffer at 976x579, and exited normally after the first accepted hold/return.

Verified counts: 91 fire observations, 44 DYING observations, 2 accepted, 20
rejected, 22 not evaluated, 5 removal-unconfirmed, 2 requests, 2 targets, 2
hold completions, and 2 returns. The invariant `44 = 2 + 20 + 22` closes.
Rejection/not-evaluated reasons were STALE_SHOT 19, SHOOTER_MISMATCH 10,
NO_CORRELATABLE_SHOT 8, and COOLDOWN 5. Trace 49 spans fire, DYING,
acceptance, request, target, hold, and return.

The rendered 1 FPS buffer is visually sane but is insufficient for precise
movement-onset/arrival timing, so camera behavioral acceptance remains HOLD.
The capture exposed and the latest code fixed only an accepted-reason label
bug (`NO_CANDIDATE` caused by Lua truthiness); no camera or attribution policy
changed. Code checkpoints: `09a242eec`, `351bd91f1`, and latest sync
`fbb12f0d4`.

## 2026-09-13 — stream HUD overlay

Implemented the approved Lua-only stream HUD in the isolated worktree. The
overlay places team/alive/score panels in the upper corners, round/time and
combat pressure at center top, and keeps the centered winner/result banner for
round transitions. The camera and AI behavior are unchanged. The nearby-ally
fire aggregation idea is recorded as a future camera-v2 candidate rather than
expanded into a battlefield-wide tracking system.

Verification passed: HUD formatter test, 11-test Python integration suite,
camera event test, AI controller test, Lua load checks, and `git diff --check`.
A 100-frame native Debug Release capture showed readable HUD placement and the
transition into round 2; runtime reached `ROUND_RESULT` without Lua errors.
The result banner was not retained in a captured frame because the window ended
just before the result transition. Decision: **ACCEPTED_FOR_THIS_REVIEW_BUILD**.

## 2026-09-13 — camera acceptance status correction

The engagement-camera review status is corrected to distinguish visual sanity
from behavioral acceptance. The 50-frame / approximately 25-second review over
rounds 28→29 supports **visual sanity: PASS**: combat remained readable over
uneven terrain, with no sustained empty-terrain fixation or obvious sampled
oscillation. **Camera behavioral acceptance remains HOLD.** The review did not
prove an attributable event cut, request-to-arrival timing, return behavior,
deduplication/retrigger suppression, survivor/end-of-round priority, or 3–5
complete rounds. Earlier telemetry recorded zero events passing the conservative
attribution gate, so event selection is still unproven. The next task is the
first attributable camera-cut capture, using a narrow T − 2 s → request →
selection → movement → arrival → T + 3–5 s window, followed by 3–5 complete
rounds. HUD acceptance remains independent and unchanged.

## 2026-09-13 — attributable camera-cut investigation

The first telemetry-directed capture was executed with review-only camera trace
markers. The traced run covered five complete rounds plus a final bounded round;
the runtime recorded 12 `CAMERA_EVENT_REMOVAL_UNCONFIRMED` cases, including
victims whose tracked health was already below zero, but zero
`CAMERA_EVENT_DEATH_OBSERVED`, attribution accepts, requests, or target-
issuance markers. A 100-frame, approximately 25-second rendered capture stayed
visually sane but contained no attributable camera cut, so no behavioral
acceptance claim is made.

Finding: the actor roster can remove a victim before the camera observes a
live→dead transition, and the observed removals were outside or near the end
of the 400 ms attribution window. Native source inspection confirms that the
activity update runs before the MovableMan update; actors enter `DYING` at
health `<= 0`, then become `DEAD` and are removed from the live actor list and
team rosters in the manager pass. Lua exposes `Status`, `Health`, `PrevHealth`,
and the `DYING`/`DEAD` values, so `DYING` is the last authoritative in-roster
signal. The next task is to test that signal diagnostically under the existing
attribution gates, followed by the same narrow end-to-end capture. Attribution
gates and camera-v2 ally tracking remain unchanged.

## 2026-09-13 — DYING-edge attribution experiment

The diagnostic-only change moved camera victim lifecycle observation from
live-to-DEAD/removal detection to a one-shot Lua-visible `DYING` edge and added
monotonic `traceID` correlation across the camera trace. The unchanged native
run produced 44 `CAMERA_FIRE_OBSERVED`, 11
`CAMERA_EVENT_DYING_OBSERVED`, 3 `CAMERA_EVENT_REMOVAL_UNCONFIRMED`, and 9
`CAMERA_EVENT_ATTRIBUTION_REJECTED` records. Rejections were seven
`STALE_SHOT` and two `DISTANCE`; there were zero accepts, requests, target
issuances, hold completions, or returns. The 90-second rendered sample stayed
visually readable, but no event-camera movement was claimed.

Decision: **DEATH-OBSERVATION ROOT CAUSE PASS** and **DYING OBSERVATION PASS**;
**DYING AS ATTRIBUTION EVIDENCE NOT YET ACCEPTED**; camera behavioral
acceptance remains **HOLD**. Keep the 400 ms window and all existing gates
unchanged, and keep camera-v2 ally tracking deferred. Next proof is one
naturally accepted correlated event followed by the T−2 s → T+3–5 s frame
review.
