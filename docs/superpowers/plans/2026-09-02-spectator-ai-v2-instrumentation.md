# Spectator AI V2 Instrumentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a behavior-neutral, testable AI V2 observation layer that records released actor state, contact memory inputs, tactical proposals, progress/stuck measurements, and baseline metrics before any tactical orders are enabled.

**Architecture:** `SpectatorAIController` will sit above the existing `NativeHumanAI` and be inactive in `OFF` mode. In `SHADOW` mode it will compute and log proposals without modifying actor AIMode, waypoints, controllers, or combat behavior. The controller will own round-scoped state and expose pure data-oriented helpers wherever possible so tests do not require the game.

**Tech Stack:** Cortex Command Lua 5.1/LuaJIT, existing activity Lua APIs, dependency-free Python reporting/tests, Fengari for standalone Lua tests.

**Spec:** Google Drive `CORTEX_AI_V2_PRECODING_BLUEPRINT.md` (Drive ID `1mQ8YAmf9Ked4AeYK8tVN8Oh8g5Yq51Ua`) and repository bridge `docs/CORTEX_COMMAND_KNOWLEDGE_BRIDGE.md`.

## Global Constraints

- Preserve V11/V11.1 touchdown and release behavior exactly.
- Do not replace or directly control `NativeHumanAI` aiming, firing, reload, locomotion, jetpack, digging, or local reactions.
- Do not apply AI V2 behavior in the first milestone; `OFF` is the default and `SHADOW` must not mutate actors.
- Do not use omniscient hidden enemy positions as team tactical contacts.
- Do not add an influence map, GOAP, custom aiming, forced jetpack input, pacing director, or permanent cover nodes.
- Preserve uncommitted camera-review work and unrelated user changes.

---

### Task 1: Pure controller state and metrics

**Files:**
- Create: `Data/Base.rte/Activities/SpectatorAIController.lua`
- Test: `tests/spectator_ai_controller_test.lua`

**Interfaces:**
- `SpectatorAIController.Create(config)` returns a controller with mode `OFF` unless explicitly configured.
- `BeginRound(roundID, seed)` clears all actor/contact/squad state and records the round generation.
- `RegisterActor(actorID, team, spawnIndex)` creates released=false actor state.
- `ReleaseActor(actorID, timestampMS)` marks an actor released and records release time.
- `RecordPosition(actorID, timestampMS, x, y, waypointX, waypointY, hardEngaged, pathPending)` stores bounded progress samples without changing actor state outside the controller.
- `RecordContact(team, enemyID, timestampMS, x, y, confidence, source)` stores current strategic knowledge; hidden positions must not be updated by this API unless the caller supplies a visible/shared observation.
- `Snapshot()` returns deterministic counts and metrics for tests/reporting.

- [ ] Write failing tests for default OFF mode, round reset, release timing, stale-ID isolation, bounded position history, contact memory freezing, and deterministic snapshots.
- [ ] Run `fengari tests/spectator_ai_controller_test.lua` and confirm expected failures because the module does not exist.
- [ ] Implement the smallest dependency-free controller satisfying those tests.
- [ ] Run the focused test and confirm PASS.
- [ ] Run the existing Lua and Python tests.
- [ ] Commit: `Add behavior-neutral spectator AI V2 controller state`.

### Task 2: Activity integration in OFF mode

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`
- Modify: `Data/Base.rte/Activities/SpectatorTelemetry.lua` if runtime transport requires a targeted fix
- Test: `tests/spectator_activity_integration_test.lua` or a deterministic source/trace check if engine construction cannot be isolated

- [ ] Add controller construction and round-generation initialization without changing actor AIMode or waypoint calls.
- [ ] Register actors when spawned and release them only from the existing accepted touchdown-release path.
- [ ] Sample positions at a low, staggered cadence after release.
- [ ] Keep `AI_V2_MODE = OFF` as the explicit default and emit configuration/version metadata through the existing telemetry path.
- [ ] Add tests/checks proving OFF mode makes no tactical actor mutations.
- [ ] Run Lua tests, Python tests, `git diff --check`, and the Debug Release x64 build.
- [ ] Commit: `Integrate spectator AI V2 controller in off mode`.

### Task 3: Shadow contact and progress observations

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorAIController.lua`
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`
- Test: `tests/spectator_ai_controller_test.lua`
- Modify: `tools/spectator_soak_report.py` and `tests/test_spectator_soak_report.py` only for fields proven by real output

- [ ] Add deterministic contact confidence decay and expiry with frozen last-known positions.
- [ ] Add hard-engagement observations and progress/stuck suspicion without recovery actions.
- [ ] Add SHADOW-only proposal records for contact/task/destination choices; proposals must not call AIMode or waypoint mutators.
- [ ] Add round metrics for first contact/shot/damage, participation, target/task churn, stuck exposure, path refreshes, and watchdog rate where source evidence exists.
- [ ] Test memory expiry, engagement lock timing, progress thresholds, and no hidden-position updates.
- [ ] Run focused/full tests and a short runtime trace.
- [ ] Commit: `Add spectator AI V2 shadow observations`.

### Task 4: Baseline run and activation gate

**Files:**
- Modify: `docs/SPECTATOR_TELEMETRY.md`
- Modify: `docs/AUTONOMOUS_WORK_LOG.md`
- Create: `docs/SPECTATOR_AI_V2_BASELINE.md`
- Modify: `tools/spectator_soak_report.py` only after structured runtime records are available

- [ ] Resolve the live `SPECTATOR_EVENT` output gap before treating reports as authoritative.
- [ ] Run accepted V11/V11.1 in `OFF` with instrumentation only.
- [ ] Collect at least 50 completed rounds before defining improvement thresholds.
- [ ] Record distributions and runtime cost without enabling behavior changes.
- [ ] Review SHADOW proposals for plausible contacts, low churn, no omniscient tracking, bounded CPU cost, and clean round resets.
- [ ] Do not enable `TASKS` until the baseline and SHADOW acceptance evidence is recorded.

