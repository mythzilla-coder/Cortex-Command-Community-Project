# Cortex Command — Shared Knowledge Bridge

Last synchronized locally: 2026-09-13

This is the repository-side continuity contract for regular ChatGPT and Codex. External Drive and Notion records are continuity mirrors; newer local Git, tests, and runtime evidence take precedence.

## Source-of-truth order

1. Local Git state and runtime/test evidence.
2. Current repository documentation under `docs/`.
3. The shared Google Drive bridge and canonical `SPECTATOR_ARENA.md`.
4. Notion project dashboard.
5. Historical snapshots and older chat context.

Before implementation, inspect `git status`, the current branch/HEAD, recent history, tags, local handoffs, and relevant logs. Never reset or overwrite newer local work with an older external snapshot.

## Repository

`C:\Users\mythz\Documents\Cortex-Command-Community-Project`

Current local branch: `spectator-random-factions`  
Current local HEAD: `2225e44bd feat: lead spectator camera toward firing targets`

The working tree is dirty with newer post-checkpoint runtime evidence and
unrelated camera/research work. Preserve that state; do not reset, clean,
merge, rebase, or downgrade it.

Important local milestones:

- `spectator-soak-2026-08-31`: approximately 1h44m unattended, round 66, 65 completed matches, observed score 36–29.
- `53c2b1f2d`: V10.1 AI baseline.
- `94ee8e328`: V11 touchdown gate.
- `de7031896`: V11.1 target-spread improvement.
- `46755ce40`: telemetry sink emission fix.
- `1bff421ae`: R1 attachment-boundary trace; retained Arena firearm wrappers
  remain valid/attached while normal actor-owned discovery is empty.

## Current product

Spectator Arena is an autonomous real-time 8v8 AI-vs-AI activity on `Ketanot Hills`. Its loop is:

`spawn -> fight -> winner detection -> score update -> reset -> next round`

The lifecycle is:

`BOOT -> PREPARE_ROUND -> SPAWN_TEAMS -> BATTLE -> ROUND_RESULT -> ROUND_RESET`

Direct launch is source-controlled through `Source/Main.cpp`; `Userdata/Settings.ini` remains runtime state and must not be committed.

## Accepted AI state

V11/V11.1 AI behavior is accepted and frozen for now. Actors spawn in SENTRY, must touch terrain before distributed pursuit, are released individually after touchdown, and landed teammates are redistributed when another teammate lands. Do not resume pursuit-pulse/tap experiments or modify native AI files without a new explicit decision.

## Unresolved camera milestone

The event-aware hybrid camera is packaged in `e7422a9c8` and proposed in
upstream PR #284, but remains pending human visual acceptance. Its priority is:

`LAST_SURVIVOR > CAMERA_EVENT > CAMERA_SOLDIER > CAMERA_POI > CAMERA_CENTER`

Review values are a 400 ms fire window, 2000 ms event hold, 4000 ms cooldown, 180–1200 pixel range, 0.85 aim-dot threshold, and per-round victim deduplication. Attribution is conservative inference, not engine-confirmed killer attribution.

The 2026-09-13 local capture showed generally action-centered hill/valley
framing without a sustained empty-terrain lock, but did not establish a
credible off-screen event cut, return timing, deduplication, last-survivor
priority, or 3–5 complete rounds. Decision remains
`HOLD_FOR_VISUAL_ACCEPTANCE`. Required before acceptance: review 3–5 complete
rounds, observe a credible off-screen event cut, confirm timing, no false cuts,
clean return to soldier-follow, deduplication, and last-survivor priority.

The approved engagement offset is now implemented in PR #284. When the
followed actor fires, the camera selects the nearest opposing living actor in
the firing cone and biases the frame 55% toward that enemy for 900 ms, with a
1400 ms cooldown. Native firearm signals are preferred; a rising
`Controller.WEAPON_FIRE` edge is a guarded fallback for the live actor-wrapper
attachment mismatch. A completed native round emitted
`CAMERA_FIRE_CONTROLLER` followed by `CAMERA_ENGAGEMENT`. This confirms the
runtime trigger path, but does not replace the pending targeted visual review.

Read:

- `docs/HANDOFF_CAMERA_EVENT_AWARE.md`
- `docs/HANDOFF_CAMERA_HYBRID_REVIEW.md`
- `docs/SPECTATOR_ARENA.md`

The separate engagement-camera offset follow-up is implemented on PR #284's
`spectator-random-factions` branch. A focused 50-frame Debug Release capture on
2026-09-13 covered approximately 25 seconds across rounds 28→29 and showed
readable combat, ordinary follow return, no sustained empty-terrain fixation,
and no obvious sampled jitter. This is **visual sanity: PASS**; **camera
behavioral acceptance: HOLD**. The capture does not prove attributable event
cuts, request-to-arrival timing, deduplication/retrigger suppression, return or
reset behavior, survivor priority, or 3–5 complete rounds. Earlier telemetry
also recorded zero events passing the conservative attribution gate, so the
event-selection pipeline remains unproven. The next milestone is a
telemetry-directed window from T − 2 s through request, selection, movement,
arrival, and T + 3–5 s, followed by 3–5 complete-round observation.

That attribution-directed capture was then run on the unchanged camera logic with
review-only trace markers. Across five complete rounds plus a final bounded
round, the runtime recorded 12 `CAMERA_EVENT_REMOVAL_UNCONFIRMED` records but
zero `CAMERA_EVENT_DEATH_OBSERVED`, attribution accepts, event requests, or
target issuances. The rendered sample stayed visually sane, but no attributable
cut occurred. The current diagnostic finding is an actor-removal/death-
observation boundary: victims can leave the live roster before a live→dead
transition is visible, and several removals were already outside the 400 ms
window. Next action is to resolve that boundary in diagnostic-only scope; do
not loosen the conservative gate or add camera-v2 tracking yet.

The next product-facing milestone, the stream-facing HUD overlay, is likewise
accepted for this review build. It adds Lua-only corner team panels, centered
round/time and combat-pressure text, and the existing result banner, without
changing camera or AI behavior. A 100-frame native capture showed readable HUD
placement and the runtime log reached `ROUND_RESULT` without Lua errors; the
result banner was not retained in a frame because the capture ended just before
that transition. The nearby-ally firing aggregation suggestion is recorded as
a future camera-v2 candidate, not an active tracking-system task.

## Observability state

The telemetry helper and Python soak parser are implemented and unit-tested. Root-cause review found that Lua `print` is routed into the in-memory `ConsoleMan` buffer, while `LogConsole.txt` is written only during orderly `ConsoleMan::Destroy()`. The activity now snapshots the console buffer to ignored `SPECTATOR_EVENT_LOG.txt` after telemetry events. A fresh smoke run produced the expected records; a longer soak is still needed for completed-round statistics.

Relevant files:

- `Data/Base.rte/Activities/SpectatorTelemetry.lua`
- `tools/spectator_soak_report.py`
- `tests/spectator_telemetry_test.lua`
- `tests/spectator_camera_event_test.lua`
- `tests/test_spectator_soak_report.py`

## AI V2 status

The first behavior-neutral foundation is present in `Data/Base.rte/Activities/SpectatorAIController.lua`, and `SpectatorArena.lua` now wires it in explicit `OFF` mode. Actors are registered at spawn, released only at the existing accepted touchdown boundary, and sampled at a low cadence after `AI_TOUCHDOWN_ALL_RELEASED`; the controller does not mutate actors, AIMode, waypoints, controllers, or combat behavior. `AI_V2_CONFIG` is emitted through the existing telemetry helper.

This is instrumentation only. Production `AI_V2_MODE` remains explicitly
`OFF`; do not enable `TASKS` or `TACTICAL` behavior until baseline and SHADOW
evidence exists. R1B rules out simple wrapper loss, sampled deletion, simple
world drop, and a SHADOW-only cause, but leaves an unresolved
attachment/discovery-path mismatch. Runtime telemetry capture is functioning
through the activity-scoped `SPECTATOR_EVENT_LOG.txt` snapshot path, but the
50-round OFF-mode baseline is still incomplete.

## Work protocol

Prefer deterministic tests, logs, state, and soak reports during autonomous work. Preserve unrelated changes. Record meaningful progress in `docs/AUTONOMOUS_WORK_LOG.md` and a dated session summary. Synchronize external Drive/Notion state only after verified local milestones.

Next decision gate:

`R2 fixture/Arena identity-topology comparison at T0-T3 -> resolve firearm discovery -> live Arena fire evidence -> D1 damage semantics -> telemetry freeze -> OFF baseline`
