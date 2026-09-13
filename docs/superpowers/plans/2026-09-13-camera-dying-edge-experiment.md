# Camera DYING-Edge Attribution Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace unreliable live-to-DEAD/removal observation with a Lua-visible DYING edge while preserving the existing conservative attribution and camera behavior.

**Architecture:** Keep `SpectatorCameraEventLogic.lua` as the pure lifecycle/attribution policy layer and keep `SpectatorArena.lua` responsible for actor snapshots, trace correlation, and camera state. A shot receives one monotonically increasing trace ID; all lifecycle, attribution, request, target, hold, and return markers inherit that ID.

**Tech Stack:** Cortex Command Lua activity scripts, Lua fixture tests executed through the repository's configured Lua harness, Python source/integration tests, native Debug Release runtime capture, Markdown project records.

**Spec:** Approved in-chat design from 2026-09-13: `DEAD/removal-based → DYING-edge observation`; keep shooter identity, single-victim, opposing-team, aim-cone, distance, shot-recency, 400 ms, priority, request/target/hold/return behavior unchanged.

## Global Constraints

- Do not widen the 400 ms recent-fire window.
- Do not change camera priority, target position, hold duration, cooldowns, or return behavior.
- Treat DYING as a candidate lifecycle signal, not as global proof of camera-worthy death.
- Preserve the opposing-team, single-victim, shooter-identity, aim-cone, distance, and handled-victim gates.
- Record explicit rejection reasons for stale shots, shooter mismatch, no candidate, aim-cone failure, distance failure, multiple candidates, and handled victims.
- Keep `AI_V2_MODE` OFF and nearby-ally tracking deferred.
- Do not stage local runtime logs, captures, or other untracked artifacts.

### Task 1: Add pure DYING-edge and rejection-reason tests

**Files:**
- Modify: `tests/spectator_camera_event_test.lua`
- Modify: `tests/spectator_ai_integration_test.py`

**Interfaces:**
- Consumes: Existing `CameraEventLogic.HasObservedDeath` and `SelectEventCandidate` contracts.
- Produces: Expected `CameraEventLogic.HasObservedDying(previousStatus, currentStatus)` behavior and trace-marker/source assertions for `CAMERA_EVENT_DYING_OBSERVED` and `traceID`.

- [x] **Step 1: Write the failing test**

Add these assertions to `tests/spectator_camera_event_test.lua` using the
engine's `Actor.Status` enum values (`STABLE = 0`, `DYING = 3`, `DEAD = 4`):

```lua
assertEqual(
    CameraEventLogic.HasObservedDying(0, 3, 3),
    true,
    "stable-to-dying transition is lifecycle evidence"
)
assertEqual(
    CameraEventLogic.HasObservedDying(3, 3, 3),
    false,
    "a sustained dying state is not a second edge"
)
assertEqual(
    CameraEventLogic.HasObservedDying(4, 4, 3),
    false,
    "dead state is not a new dying edge"
)
```

Extend the integration source checks to require `CAMERA_EVENT_DYING_OBSERVED`, `traceID`, and rejection strings `STALE_SHOT`, `SHOOTER_MISMATCH`, `NO_CANDIDATE`, `AIM_CONE`, `DISTANCE`, and `MULTIPLE_VICTIMS`.

- [x] **Step 2: Run test to verify it fails**

Run the repository's Lua camera-event test and the focused Python integration test. Expected result: the Lua test fails because `HasObservedDying` is not defined, and the Python test fails because the new marker/reason strings are absent.

- [x] **Step 3: Commit**

Do not commit this red test-only state; continue directly to Task 2 after recording the expected failures.

### Task 2: Implement the minimal DYING-edge observation and correlated diagnostics

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorCameraEventLogic.lua`
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`

**Interfaces:**
- Consumes: Actor `Status`, `Health`, `PrevHealth`, and `UniqueID`; existing shot and attribution structures.
- Produces: `HasObservedDying(previousStatus, currentStatus)`, one `CAMERA_EVENT_DYING_OBSERVED` per new edge, unchanged event selection gates, explicit attribution rejection reason, and one `traceID` carried through the camera event lifecycle.

- [x] **Step 1: Add the pure failing behavior's minimal implementation**

Implement `HasObservedDying` as `previousStatus ~= Actor.DYING and currentStatus == Actor.DYING`. Extend candidate evaluation only enough to return a reason alongside a nil selection; do not alter the existing aim, range, recency, team, or single-candidate decisions.

- [x] **Step 2: Add trace correlation at fire creation**

Initialize `self.CameraTraceSequence = 0`. Increment it whenever `CameraLastShot` is created and store the value as `traceID`. Update `EmitCameraTrace` to default `fields.traceID` from `CameraLastShot.traceID` when the caller does not provide one.

- [x] **Step 3: Replace the lifecycle observation point**

Store `status`, `health`, `prevHealth`, and position in each tracked actor record. During `DetectCameraEvent`, recognize only a transition to `Actor.DYING` as the new lifecycle candidate. Emit `CAMERA_EVENT_DYING_OBSERVED` with `traceID`, shooter, victim, victim team, health, previous health, position, and shot age. Keep removal logging diagnostic-only and do not treat an unobserved removal as a candidate.

- [x] **Step 4: Preserve downstream camera behavior**

Pass DYING candidates through the existing `SelectEventCandidate` gates. Emit `CAMERA_EVENT_ATTRIBUTION_ACCEPTED` or `CAMERA_EVENT_ATTRIBUTION_REJECTED` with the same existing fields plus `traceID` and `reason`; keep `EnterEventMode`, target issuance, hold, return, cooldown, and priority code unchanged except for passing the accepted event's trace ID to downstream markers.

- [x] **Step 5: Run the focused tests**

Run the Lua camera-event test, Lua controller test, Python integration suite, and `git diff --check`. Expected result: all tests pass and the only source changes are the lifecycle/diagnostic experiment plus its tests.

- [x] **Step 6: Commit the implementation**

```powershell
git add tests/spectator_camera_event_test.lua tests/spectator_ai_integration_test.py Data/Base.rte/Activities/SpectatorCameraEventLogic.lua Data/Base.rte/Activities/SpectatorArena.lua
git commit -m "test: observe camera victim DYING edges"
```

### Task 3: Run the bounded runtime experiment

**Files:**
- Create: `work/camera-dying-edge-experiment-20260913-2100/` runtime capture directory (replace `2100` with the actual capture start time)
- Inspect: `SPECTATOR_EVENT_LOG.txt` and the camera trace output

**Interfaces:**
- Consumes: Debug Release executable and the Task 2 diagnostic build.
- Produces: Counts and one correlated trace chain, or evidence that DYING is observed while attribution remains rejected.

- [x] **Step 1: Launch the existing direct Arena runtime**

Use the already verified Debug Release launch path without changing startup settings, AI mode, map, team size, or camera parameters.

- [x] **Step 2: Capture trace and rendered-frame evidence**

Capture approximately 25–60 seconds at the established frame size/rate and retain the trace log. Do not use the failed second-capture procedure or terminate the game in a way that discards buffered logs; use orderly shutdown.

- [x] **Step 3: Correlate the result**

Search for `traceID` and verify whether any sequence reaches `FIRE_OBSERVED → DYING_OBSERVED → ATTRIBUTION_ACCEPTED → CAMERA_EVENT_REQUEST → CAMERA_EVENT_TARGET_ISSUED → CAMERA_EVENT_HOLD_COMPLETE → CAMERA_EVENT_RETURN`. If no accept occurs, report DYING count and rejection-reason counts without loosening any gate.

- [x] **Step 4: Review frames only around a correlated event**

If an accepted event exists, inspect frames from approximately T−2 seconds through T+3–5 seconds and verify movement, arrival, hold, and return. If no accepted event exists, record that visual behavioral acceptance remains HOLD.

### Task 4: Synchronize evidence and project records

**Files:**
- Modify: `docs/SPECTATOR_CAMERA_ENGAGEMENT_OFFSET_2026-09-13.md`
- Modify: `docs/SPECTATOR_ARENA.md`
- Modify: `docs/CORTEX_COMMAND_KNOWLEDGE_BRIDGE.md`
- Modify: `docs/AUTONOMOUS_WORK_LOG.md`

**Interfaces:**
- Consumes: Task 2 commit hash, Task 3 trace counts, rendered capture result, and rejection reasons.
- Produces: A source-grounded experiment record that distinguishes lifecycle-observation PASS from DYING attribution acceptance and camera behavioral acceptance.

- [x] **Step 1: Record the experiment outcome locally**

State the exact commit, runtime duration, DYING count, accepted/rejected counts, reason counts, and whether the full correlated chain was observed. Preserve the existing HOLD language when no full chain is proven.

- [x] **Step 2: Run final verification**

Run the focused tests, Python integration suite, `git diff --check`, and `git status --short`; confirm runtime artifacts remain untracked.

- [ ] **Step 3: Commit and push the evidence record**

```powershell
git add docs/SPECTATOR_CAMERA_ENGAGEMENT_OFFSET_2026-09-13.md docs/SPECTATOR_ARENA.md docs/CORTEX_COMMAND_KNOWLEDGE_BRIDGE.md docs/AUTONOMOUS_WORK_LOG.md
git commit -m "docs: record camera dying-edge experiment"
git push fork HEAD:spectator-random-factions
```

- [ ] **Step 4: Update Drive and Notion**

Replace the four canonical Drive markdown artifacts from the isolated worktree and update the existing Notion project page with the new commit, experiment status, and next milestone. Read back all five records before reporting completion.

### Task 5: Close DYING attribution accounting and run the condition-based sample

**Files:**
- Modify: `tests/spectator_ai_integration_test.py`
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`
- Modify: `docs/SPECTATOR_CAMERA_ENGAGEMENT_OFFSET_2026-09-13.md`
- Modify: `docs/SPECTATOR_ARENA.md`
- Modify: `docs/CORTEX_COMMAND_KNOWLEDGE_BRIDGE.md`
- Modify: `docs/AUTONOMOUS_WORK_LOG.md`

**Interfaces:**
- Consumes: One-shot `CAMERA_EVENT_DYING_OBSERVED` records and the existing attribution selector.
- Produces: Exactly one terminal `CAMERA_EVENT_ATTRIBUTION_ACCEPTED`, `CAMERA_EVENT_ATTRIBUTION_REJECTED`, or `CAMERA_EVENT_ATTRIBUTION_NOT_EVALUATED` disposition per DYING edge, plus condition-based runtime evidence.

- [ ] **Step 1: Write the failing accounting assertions**

Require the activity source to contain `CAMERA_EVENT_ATTRIBUTION_NOT_EVALUATED`, `NO_CORRELATABLE_SHOT`, `COOLDOWN`, and `DYING_OBSERVED` alongside the existing acceptance/rejection markers. The existing runtime parser must count the three terminal disposition event names separately.

- [ ] **Step 2: Run the focused test to verify it fails**

Run `python tests/spectator_ai_integration_test.py`. Expected result: the test fails because the not-evaluated marker and reasons are not yet present.

- [ ] **Step 3: Implement terminal accounting without changing attribution policy**

Collect DYING candidates even when no shot is available, and emit `CAMERA_EVENT_ATTRIBUTION_NOT_EVALUATED` with `NO_CORRELATABLE_SHOT`, `COOLDOWN`, or `SHOOTER_MISMATCH` when the existing early-return conditions prevent evaluation. When evaluation runs, emit one accepted or rejected disposition per candidate; use `MULTIPLE_VICTIMS` for every candidate in an ambiguous set. Keep selection, thresholds, recency, cooldown, priority, and camera state unchanged.

- [ ] **Step 4: Run all focused verification**

Run the Python integration suite, native Debug Release launch, and `git diff --check`. Confirm the accounting invariant in the runtime parser: DYING observed equals accepted plus rejected plus not evaluated.

- [ ] **Step 5: Run until an accept or the round bound**

Capture a rolling rendered-frame buffer at the established window size while the unchanged Arena runs until the first accepted trace ID or 20 completed rounds, whichever comes first. Preserve the prior 8 seconds of frames when an accept appears, then retain at least 5 seconds after return. If no accept appears, keep only the bounded summary and report all terminal dispositions.

- [ ] **Step 6: Document and synchronize the outcome**

Record the exact counts, reason distribution, first accepted trace ID if any, frame-buffer path, and acceptance status in the four local documents. Commit, push the PR branch, fast-forward the original checkout, update the four Drive artifacts and the Notion project page, and read back all external records.
