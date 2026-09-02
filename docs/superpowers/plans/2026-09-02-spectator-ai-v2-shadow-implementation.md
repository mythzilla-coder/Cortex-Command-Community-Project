# Spectator AI V2 Shadow and Tactical Coordination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Add SHADOW-only observations for contact memory, engagement, task proposals, weapon/environment scoring, and recovery while preserving V11/V11.1 and keeping tactical behavior disabled.

**Architecture:** Extend `SpectatorAIController` as a pure state/decision layer above `NativeHumanAI`. `SpectatorArena` supplies verified observations after the all-released boundary; OFF and SHADOW record or propose data without mutating actors.

**Tech Stack:** Cortex Command Lua 5.1/LuaJIT, cached Fengari, Python `unittest`, Visual Studio MSBuild Debug Release x64.

**Spec:** `docs/superpowers/specs/2026-09-02-spectator-ai-v2-shadow-design.md`

## Global Constraints

- Preserve V11/V11.1 touchdown and release exactly.
- Keep `AI_V2_MODE = "OFF"` as production default.
- Do not replace or directly control NativeHumanAI aiming, firing, reload, locomotion, jetpack, digging, or local reactions.
- Do not use omniscient hidden enemy positions as contacts.
- Do not add full influence maps, GOAP, RL, replacement pathfinding, permanent cover nodes, or pacing logic.
- Preserve uncommitted camera-review files.
- Add telemetry fields only after real runtime output proves them.

---

### Task 1: Audit local AI and navigation APIs

**Files:** Read `Data/Base.rte/AI/NativeHumanAI.lua`, `Data/Base.rte/Activities/SpectatorArena.lua`, `Source/Lua/LuaBindingsEntities.cpp`, and `Source/Lua/LuaBindingsManagers.cpp`; modify `docs/AUTONOMOUS_WORK_LOG.md`.

**Produces:** A dated list of verified observation-safe signatures for waypoint, path, LOS, health, weapon, and terrain APIs. Unsupported or ambiguous APIs are recorded as unavailable.

- [ ] Run `rg -n "GetLastAIWaypoint|IsWaitingOnNewMovePath|CalculatePath|ShortestDistance|CastAllMOsRay|FiredFrame|Health|WoundCount|EquippedItem" Data Source`.
- [ ] Record owner/type, arguments, return shape, and observation safety for each API actually present.
- [ ] Run `git diff --check`.
- [ ] Commit with `git add docs/AUTONOMOUS_WORK_LOG.md; git commit -m "Audit local spectator AI APIs"`.

### Task 2: Add contact memory and engagement observations

**Files:** Modify `Data/Base.rte/Activities/SpectatorAIController.lua`; test `tests/spectator_ai_controller_test.lua`.

**Produces:** `RecordEngagement(actorID, timestampMS, signal, untilMS)`, `IsHardEngaged(actorID, timestampMS)`, `GetContact(team, enemyID, timestampMS)`, confidence expiry, and deterministic snapshot counts.

- [ ] Add failing tests for frozen direct contact positions, lower-confidence shared reports, contact expiry, engagement-lock retention, and engagement expiry.
- [ ] Run `fengari tests/spectator_ai_controller_test.lua`; confirm failure because the methods are absent.
- [ ] Implement only round-scoped pure state; do not call engine APIs or mutate actors.
- [ ] Re-run the focused controller and telemetry tests; expect PASS.
- [ ] Commit `Add spectator AI V2 contact and engagement observations`.

### Task 3: Add task, reservation, and recovery rules

**Files:** Modify `Data/Base.rte/Activities/SpectatorAIController.lua`; test `tests/spectator_ai_controller_test.lua`.

**Produces:** `AssignTask`, `ReserveTarget`, `CanReserveTarget`, `RecordProgress`, and `GetRecoveryStage` with hysteresis, reservation limits, expiry, and staged recovery.

- [ ] Add failing tests for task hysteresis, reservation dogpile limits, stale reservation expiry, and one-stage-at-a-time recovery escalation.
- [ ] Run the focused test and confirm the expected missing-method failure.
- [ ] Implement deterministic rules with configurable thresholds and bounded round-scoped state.
- [ ] Re-run the focused controller test; expect PASS.
- [ ] Commit `Add spectator AI V2 task and recovery rules`.

### Task 4: Add weapon and environment scoring

**Files:** Modify `Data/Base.rte/Activities/SpectatorAIController.lua`; test `tests/spectator_ai_controller_test.lua`.

**Produces:** Pure `ClassifyWeapon(profile)`, `ScoreDestination(context)`, and `SelectDistinctDestination(candidates, current, minimumImprovement)` helpers.

- [ ] Add failing tests showing close-range weapons prefer covered close positions, long-range weapons prefer distance/LOS, invalid profiles reduce confidence, and marginal destination improvements are rejected.
- [ ] Run the focused test and confirm failure.
- [ ] Implement numeric, engine-independent scoring; do not encode faction-specific assumptions.
- [ ] Re-run focused tests; expect PASS.
- [ ] Commit `Add deterministic spectator AI weapon environment scoring`.

### Task 5: Integrate SHADOW observations into SpectatorArena

**Files:** Modify `Data/Base.rte/Activities/SpectatorArena.lua`; update `tests/spectator_ai_integration_test.py`; modify telemetry only if a proven transport issue appears.

**Produces:** `UpdateAIShadowObservations(team1Actors, team2Actors)`, called only after all actors release and only when `AI_V2_MODE == "SHADOW"`. Production remains `OFF`.

- [ ] Add failing source assertions for the explicit mode branch, post-release ordering, verified actor observations, and absence of actor mutation calls inside the shadow function.
- [ ] Run `python -m unittest discover -s tests -p 'spectator_ai_integration_test.py' -v`; confirm failure.
- [ ] Implement conservative nil-safe observation of weapon, health, firing, LOS, waypoint, progress, and terrain context using only Task 1 APIs.
- [ ] Emit proposals without applying AIMode, waypoint, controller, inventory, health, position, or combat changes.
- [ ] Run Lua tests, Python tests, integration tests, `git diff --check`, and the Debug Release x64 build.
- [ ] Commit `Add spectator AI V2 shadow observations`.

### Task 6: Capture and review SHADOW evidence

**Files:** Modify `tools/spectator_soak_report.py` and `tests/test_spectator_soak_report.py` only for proven fields; create `docs/SPECTATOR_AI_V2_SHADOW_REPORT.md`; update `docs/SPECTATOR_TELEMETRY.md` and `docs/AUTONOMOUS_WORK_LOG.md`.

**Produces:** A report separating measured observations from proposals, malformed lines, and limitations.

- [ ] Add failing parser tests using captured `PRINT: SPECTATOR_EVENT` lines with decimal values and malformed optional fields.
- [ ] Implement backward-compatible parsing; ignore malformed fields without losing round counts.
- [ ] Run a non-default SHADOW trace, capture `SPECTATOR_EVENT_LOG.txt`, and do not commit generated logs.
- [ ] Report contact plausibility, task/target churn, weapon/environment differentiation, recovery correlation, CPU/UPS observations, and hidden-position violations.
- [ ] Run all Lua/Python tests, `git diff --check`, and the Debug Release x64 build.
- [ ] Commit `Add spectator AI V2 shadow report`.

### Task 7: Complete baseline comparison and activation review

**Files:** Create `docs/SPECTATOR_AI_V2_BASELINE.md`; update `docs/PROJECT_STATUS_2026-09-02.md` and `docs/AUTONOMOUS_WORK_LOG.md`.

**Produces:** An explicit recommendation to remain OFF, continue SHADOW, or request approval for TASKS.

- [ ] Require at least 50 completed OFF-mode rounds before defining activation thresholds.
- [ ] Record winner distribution, durations, watchdog rate, incomplete rounds, runtime stability, and CPU/UPS impact when available.
- [ ] Compare SHADOW proposals against OFF observations and identify measured values, inferences, limitations, and unanswered questions.
- [ ] Do not claim improvement without a behavior-enabled comparison.
- [ ] Run the complete verification suite and `git diff --check`.
- [ ] Commit `Record spectator AI V2 baseline review`.
