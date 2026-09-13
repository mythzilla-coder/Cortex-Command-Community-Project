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

Visual sanity: **PASS**. Camera behavioral acceptance: **HOLD**.

This sample supports ordinary watchability only: the camera kept combat readable over uneven terrain, avoided sustained empty-terrain fixation, and showed no obvious sampled oscillation. It does not establish that an attributable event cut occurred, request-to-arrival timing, return behavior, deduplication/retrigger suppression, survivor/end-of-round priority, or acceptance across 3–5 complete rounds. Earlier telemetry also recorded zero events passing the conservative attribution gate, so this visual sample does not validate the event-selection pipeline.

Next milestone: prove the first attributable camera cut with a telemetry-directed capture covering **T − 2 s → request → selection → camera movement → arrival → T + 3–5 s**, then separately observe 3–5 complete rounds for return/reset and survivor behavior. The nearby-ally firing aggregation idea remains deferred as a camera-v2 candidate.

## Attribution-directed capture — 2026-09-13

Review-only trace markers were added for observed fire, actor removal, attribution, request, target issuance, hold completion, and return. The markers do not change camera selection, priority, thresholds, holds, cooldowns, or target positions.

- The traced run covered five complete rounds and recorded 68 followed-shooter fire observations; a final bounded round was also captured with 100 rendered frames at 976×579 over approximately 25 seconds.
- Runtime recorded 12 `CAMERA_EVENT_REMOVAL_UNCONFIRMED` records, including removed victims with tracked health below zero, but zero `CAMERA_EVENT_DEATH_OBSERVED`, zero attribution accepts, zero event requests, and zero target-issuance markers.
- The rendered sample remained visually sane, but no attributable camera cut occurred and therefore no end-to-end visual verification is claimed.

Finding: the live actor roster can remove a victim before the camera observes a live→dead transition. Several unconfirmed removals were also outside the 400 ms attribution window. The next task is to resolve this death-observation boundary in diagnostic-only scope and then repeat the same narrow capture. Do not loosen attribution gates or add camera-v2 tracking before that proof exists.

## Native lifecycle root-cause investigation — 2026-09-13

The native source confirms the observation boundary. `Source/Main.cpp` calls
`g_ActivityMan.Update()` before `g_MovableMan.Update()` each frame. During the
native actor update, `Actor.cpp` changes an actor to `DYING` when health reaches
zero or below; after the death timer expires it changes the actor to `DEAD`.
The subsequent `MovableMan.cpp` pass partitions dead actors into particles,
removes them from team rosters, and erases them from the live actor list.

Lua exposes `Actor.Status`, `Actor.Health`, `Actor.PrevHealth`, `Actor.IsDead()`,
and the `DYING`/`DEAD` status values, but the activity update cannot reliably
observe `DEAD` while the actor is still in `MovableMan.Actors`. Therefore the
last authoritative in-roster lifecycle signal is the transition to `DYING`,
with health and previous health available for correlation. This confirms the
runtime evidence without changing camera behavior or attribution policy.

Next hypothesis: test the Lua-visible `DYING` transition as death evidence
under the existing single-victim, shooter-identity, aim-cone, distance, and
400 ms gates. No implementation or acceptance claim is made by this finding;
the next change must remain diagnostic-only until one end-to-end attributable
cut is proven.

## DYING-edge experiment — 2026-09-13

The diagnostic experiment replaced the prior live-to-DEAD/removal candidate
with a one-shot Lua-visible `DYING` edge. Trace correlation was added with a
monotonic `traceID`; the shooter, victim lifecycle, attribution, request,
target, hold, and return markers use that ID. The existing shooter identity,
single-victim, opposing-team, aim-cone, distance, recency, cooldown, priority,
and camera behavior were left unchanged.

- Implementation checkpoint: `09a242eec`.
- Native run: 90 rendered frames over approximately 90 seconds; orderly exit;
  two round results were recorded and the next round began.
- Trace counts: 44 `CAMERA_FIRE_OBSERVED`, 11
  `CAMERA_EVENT_DYING_OBSERVED`, 3 `CAMERA_EVENT_REMOVAL_UNCONFIRMED`, 9
  `CAMERA_EVENT_ATTRIBUTION_REJECTED`, and zero attribution accepts, requests,
  target issuances, hold completions, or returns.
- Rejection reasons: 7 `STALE_SHOT` and 2 `DISTANCE`. No 400 ms widening was
  applied.
- Representative rendered frames remained readable, but no event-camera
  movement was claimed because no attribution was accepted.

Status: **DEATH-OBSERVATION ROOT CAUSE PASS** and **DYING OBSERVATION PASS**;
**DYING ATTRIBUTION ACCEPTANCE UNPROVEN**; **CAMERA BEHAVIORAL ACCEPTANCE
HOLD**. The lifecycle seam is repaired for observation, while the unchanged
classifier still needs a naturally accepted candidate before camera-event
behavior can be accepted.

## Condition-based DYING accounting capture — 2026-09-13

The accounting follow-up kept the existing attribution policy unchanged and
ran until the first natural accept. The run stopped after four completed
rounds when the first accepted event was observed, then exited normally after
the hold and return. A bounded rolling buffer retained 120 rendered frames at
976x579; the accepted window is under
`work/camera-dying-edge-rolling-20260913-223423/accepted/`.

- `CAMERA_FIRE_OBSERVED`: 91
- `CAMERA_EVENT_DYING_OBSERVED`: 44
- `CAMERA_EVENT_ATTRIBUTION_ACCEPTED`: 2
- `CAMERA_EVENT_ATTRIBUTION_REJECTED`: 20
- `CAMERA_EVENT_ATTRIBUTION_NOT_EVALUATED`: 22
- `CAMERA_EVENT_REQUEST`: 2
- `CAMERA_EVENT_TARGET_ISSUED`: 2
- `CAMERA_EVENT_HOLD_COMPLETE`: 2
- `CAMERA_EVENT_RETURN`: 2
- `CAMERA_EVENT_REMOVAL_UNCONFIRMED`: 5

The accounting invariant closes exactly: `44 = 2 + 20 + 22`. Terminal
reasons were `STALE_SHOT` 19, `SHOOTER_MISMATCH` 10,
`NO_CORRELATABLE_SHOT` 8, and `COOLDOWN` 5. No 400 ms widening, gate change,
priority change, or ally-tracking behavior was added.

Trace `49` provides the first complete telemetry chain:
`FIRE_OBSERVED -> DYING_OBSERVED -> ATTRIBUTION_ACCEPTED -> REQUEST ->
TARGET_ISSUED -> HOLD_COMPLETE -> RETURN`, with one trace ID throughout.
The sampled frames around the accepted window remain combat-centered and
readable. Because the capture was sampled at 1 FPS, it supports visual sanity
and the telemetry chain but does not precisely prove movement onset/arrival
latency. Behavioral acceptance therefore remains **HOLD** pending a higher-
rate event-window review and the separate 3–5-round acceptance pass.

The initial capture exposed a diagnostic-only Lua truthiness label bug that
reported accepted dispositions as `NO_CANDIDATE`. It was corrected and
regression-tested in `fbb12f0d4`; camera behavior and attribution policy were
not changed. Implementation provenance remains `09a242eec`, accounting
checkpoint `351bd91f1`, and latest code sync `fbb12f0d4`.
