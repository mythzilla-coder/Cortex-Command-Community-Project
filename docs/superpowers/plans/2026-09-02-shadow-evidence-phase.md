# SHADOW Evidence Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SHADOW LOS semantics and runtime cost measurable while keeping AI V2 behavior-neutral and production `OFF`.

**Architecture:** Add a pure, dependency-free visibility-selection helper to the controller for deterministic testing, then have the arena evaluate every living opponent and record nearest/visible counts without inserting world-truth coordinates into team contact memory. Extend controller metrics with bounded counters and elapsed observation cost, and expose them in the per-round SHADOW summary.

**Tech Stack:** Lua activity scripts, Fengari Lua tests, Python unittest source checks, Cortex Command engine ray APIs, Markdown documentation.

**Spec:** `docs/superpowers/specs/2026-09-02-spectator-ai-v2-shadow-design.md`

## Global Constraints

- Production default remains `AI_V2_MODE = "OFF"`.
- `OFF` and `SHADOW` must not mutate actor AIMode, waypoints, controllers, inventory, health, position, or combat state.
- NativeHumanAI remains authoritative for local movement and combat.
- Diagnostic world-truth observations must not become team contact knowledge.
- Camera/research working-tree changes are outside this phase and must remain untouched.
- Every production behavior change requires a failing test before implementation.

### Task 1: Deterministic visibility-selection helper

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorAIController.lua`
- Modify: `tests/spectator_ai_controller_test.lua`

**Interfaces:**
- Produces `SpectatorAIController.SelectVisibleOpponent(opponents, visibilityByID)` returning `nearestOpponent`, `nearestDistanceSquared`, and `visibleOpponentCount`.
- `opponents` contains entries with `UniqueID` and `distanceSquared`.
- `visibilityByID[id]` is a boolean; only visible opponents may be selected.

- [ ] Write a failing test covering a blocked nearest opponent and a visible farther opponent.
- [ ] Run the controller test and confirm the new assertion fails because the helper is absent.
- [ ] Implement the minimal pure helper with deterministic nearest-visible selection and count.
- [ ] Run the controller test and confirm it passes.
- [ ] Commit as `Add deterministic SHADOW visibility selection`.

### Task 2: Controller SHADOW metrics

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorAIController.lua`
- Modify: `tests/spectator_ai_controller_test.lua`

**Interfaces:**
- Add metrics for `VisibleOpponents`, `VisibleOpponentChecks`, `ActorSkips`, `ContactAcquisitions`, `ContactLosses`, and `ShadowObservationTimeMS`.
- Add `RecordShadowBatchMetrics(fields)` accepting numeric counters and elapsed milliseconds.
- Include all counters in `Snapshot()`.

- [ ] Write failing tests for batch-counter accumulation and snapshot output.
- [ ] Run the controller test and confirm failure.
- [ ] Implement accumulation with numeric defaults and no engine dependencies.
- [ ] Run the controller test and confirm pass.
- [ ] Commit as `Add SHADOW aggregate metrics`.

### Task 3: Arena any-visible LOS observation

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`
- Modify: `tests/spectator_ai_integration_test.py`

**Interfaces:**
- For each released living actor, evaluate all living opponents with the existing obstacle-ray API.
- Use the pure helper to select the nearest visible opponent while retaining the nearest world-truth opponent only as a diagnostic field.
- Record contact only for the selected visible opponent.
- Emit `visibleOpponentCount`, `visibleOpponentChecks`, and `nearestVisibleEnemy` in SHADOW telemetry.
- Record skipped actors and batch elapsed time in controller metrics.

- [ ] Add source-level assertions requiring all-opponent visibility selection and the new telemetry fields while prohibiting actor-control calls.
- [ ] Run integration tests and confirm they fail before wiring is present.
- [ ] Implement the smallest read-only arena integration.
- [ ] Run integration tests and confirm pass.
- [ ] Commit as `Measure any-visible SHADOW contacts`.

### Task 4: Documentation and verification

**Files:**
- Modify: `docs/PROJECT_STATUS_2026-09-02.md`
- Modify: `docs/PROJECT_SUMMARY_AND_NEXT_STEPS_2026-09-02.md`
- Modify: `docs/CHATGPT_REVIEW_HANDOFF_2026-09-02.md`
- Modify: `docs/SPECTATOR_AI_V2_SHADOW_SMOKE_REPORT_2026-09-02.md`

- [ ] Correct stale HEAD and SHADOW statements.
- [ ] Document that the first smoke passed plumbing but lacked LOS/firing positives.
- [ ] Document the new deterministic LOS and metric phase.
- [ ] Run Lua tests, Python tests, `git diff --check`, and the relevant build verification.
- [ ] Commit documentation and verification evidence as `Document SHADOW evidence phase`.

## Self-review

- The plan keeps LOS selection pure and testable while leaving engine ray calls in the activity layer.
- No task changes production mode or applies TASKS behavior.
- World-truth nearest-enemy diagnostics remain separate from contact memory.
- Each code task has a failing-test step before production changes.
