# Spectator Arena

## Purpose

Spectator Arena is an autonomous AI-vs-AI Cortex Command activity intended to become a dedicated livestream/spectator application. It keeps the original actors, weapons, AI, projectile physics, gore, particles, destructible terrain, and map systems active while the player observes the match.

The current content is deliberately conservative: two autonomous teams of eight fight in real time on `Ketanot Hills`.

## Current local state

The authoritative local checkout is on branch `spectator-random-factions` at
`1bff421aefaa5f383aa815502d150a885c5b2735` (`Trace Arena firearm attachment
boundary`). The V11/V11.1 AI baseline is committed and accepted for now.
Post-checkpoint R1B/A1 runtime evidence is retained locally; the working tree
also contains unrelated uncommitted camera/research work and diagnostic
artifacts that must not be reset. See
`docs/CORTEX_COMMAND_KNOWLEDGE_BRIDGE.md` for the cross-environment
source-of-truth and continuation protocol.

The current diagnostic conclusion is **UNRESOLVED attachment/discovery-path
mismatch**: a retained Arena firearm wrapper remains valid and attached after
the first enumerable update, but `FGArm.HeldDevice` and ordinary
foreground/background/inventory discovery are empty, with no matching bounded
`MovableMan.Items` entry. This does not justify a production workaround.
Production `AI_V2_MODE` remains explicitly `OFF`.

## Startup flow

The debug-release executable applies the dedicated startup selection in `Source/Main.cpp`:

1. Initialize the normal Cortex Command managers and load data modules.
2. Select activity type `GAScripted`.
3. Select activity `Spectator Arena`.
4. Select scene `Ketanot Hills`.
5. Set direct activity launch, bypassing the normal menu loop.

Launch from the repository root with:

```powershell
.\Cortex Command.debug.release.exe
```

The equivalent runtime settings are `LaunchIntoActivity = 1`, `DefaultActivityType = GAScripted`, `DefaultActivityName = Spectator Arena`, and `DefaultSceneName = Ketanot Hills`. `Userdata/Settings.ini` remains runtime state and is not source controlled.

## Activity implementation

The active registration is in `Data/Base.rte/Activities.ini`; the implementation is `Data/Base.rte/Activities/SpectatorArena.lua` with Lua class `SpectatorArena`.

The activity preserves the existing faction pool, faction-owned weapons, eight actors per side, real-time AI movement/combat, spectator camera, elimination detection, cumulative score, and automatic round restart.

## Procedural close-quarters environments — proposed extension

The fixed `Ketanot Hills` scene remains the current verification baseline. A
planned environment extension will add compact, seedable room-grammar layouts
for short-form spectator encounters: authored room archetypes assembled through
socket constraints, topology/readability scoring, encounter seeds, and a
bounded runtime director for doors, hazards, lights, and route changes.

This is a design-only proposal at present. It is intentionally separated from
the accepted round lifecycle, NativeHumanAI behavior, camera acceptance, and
AI V2 activation gates. See
`docs/SPECTATOR_PROCEDURAL_CLOSE_QUARTERS_DESIGN_2026-09-05.md` for the
detailed contract, manifests, staged gates, and fixed-scene fallback.

## Round state machine

The lifecycle is explicit in `SpectatorArena.lua` and emits one concise transition log per state change:

```text
BOOT -> PREPARE_ROUND -> SPAWN_TEAMS -> BATTLE
     -> ROUND_RESULT -> ROUND_RESET -> PREPARE_ROUND
```

- `BOOT`: initialize teams, score, timers, and spectator view.
- `PREPARE_ROUND`: prepare the next round number and faction selection.
- `SPAWN_TEAMS`: create and place both eight-person teams with faction-owned loadouts.
- `BATTLE`: begin the combat timer once both teams have living actors.
- `ROUND_RESULT`: resolve a winner/draw once, incrementing score at most once.
- `ROUND_RESET`: remove only the previous round’s team actors, then spawn the next round.

## Camera Director v1

During `BATTLE`, `UpdateCameraDirector` evaluates candidate focus areas every `500` ms. Each living actor is scored against nearby opposing actors within a 260-pixel combat radius: multiple nearby enemies dominate the score, with proximity providing a tie-break contribution. The selected focus is the midpoint between the best opposing pair, so the viewer sees the interaction rather than an arbitrary soldier.

The director holds a focus for at least `1500` ms and only switches when a new score is at least `1.25x` the current score, unless the current anchor has disappeared. This limits jitter while still recovering cleanly when a target dies. If one side has only one living actor, that candidate receives a strong priority bonus. Outside `BATTLE`, combat scoring is disabled: result framing holds the last meaningful focus, while preparation/reset framing returns to the deterministic scene center.

The centralized controls are `CameraEvaluationIntervalMS`, `CameraMinimumHoldMS`, and `CameraSwitchThreshold`. Fallback priority is strongest opposing interaction, nearest opposing pair, any living combatant, then the scene center. Existing Cortex Command observation-target smoothing remains responsible for the final camera movement.

### Event-aware hybrid camera — review build

The current uncommitted review build uses the explicit priority `LAST_SURVIVOR > CAMERA_EVENT > CAMERA_SOLDIER > CAMERA_POI > CAMERA_CENTER`. A real living soldier remains the normal anchor. The earlier combat-cluster midpoint remains available only as an occasional secondary POI; Cortex Command's observation-target scrolling supplies transition smoothing.

The engine exposes no direct killer or instigator field to this activity. The implementation therefore uses conservative inference from supported Lua APIs: `AHuman.EquippedItem`, `HDFirearm.FiredFrame`, `HDFirearm.MuzzlePos`, `Actor:GetAimAngle(true)`, `Actor:IsDead()`, `Actor.Health`, `MOSRotating.WoundCount`, and `MovableObject.UniqueID`. A camera event is eligible only when the followed soldier fired within `400` ms, exactly one opposing actor has an observed live-to-dead transition (or is removed after death was already observed), the victim is `180–1200` pixels away, and the victim lies within an aim dot threshold of `0.85` (about ±32 degrees). Unexplained disappearance, ambiguous deaths, stale fire, nearby deaths, out-of-cone deaths, and already-handled victim IDs are rejected.

An accepted event holds the victim's last meaningful position for `2000` ms and starts a `4000` ms event cooldown. The prior soldier reference is retained and reused if still alive; otherwise a new living soldier is selected. Handled victim IDs, tracked actor state, shot context, event state, and cooldown state are cleared between rounds. One event can therefore produce at most one response per round. This is intentionally a high-miss/low-false-positive approximation: kills removed before a death state can be observed may receive no cut.

### Engagement camera offset — review build

When the followed actor begins a firing action, the director searches the
opposing living roster for the nearest actor in the shot direction. If the
target is at least `300` pixels away and within `1600` pixels and the aim dot
is at least `0.80`, the observation target moves to a frame interpolated `55%`
toward that enemy. The engagement frame holds for `900` ms, then returns to
normal soldier follow; a `1400` ms cooldown prevents repeated oscillation.
Death/event framing keeps priority over this short presentation cue.

The detector prefers the native `HDFirearm.FiredFrame`/`RoundsFired` signals
and can fall back to a rising `Controller.WEAPON_FIRE` edge when the live
actor wrapper exposes no firearm. The fallback uses the actor position and aim
angle, and remains gated by the same opposing-target cone and distance checks.
Pure selection/frame tests and a native Debug Release smoke run passed; visual
acceptance still requires a longer targeted capture of several deliberate
opposite-edge exchanges.

## Winner and score logic

The first team with no living actors loses. If both teams are eliminated, the result is a draw. `RoundOver` prevents duplicate results, score increments, or reset operations. The score remains cumulative for the life of the activity.

## Watchdog

`MaxRoundDurationMS` is centralized in `StartActivity` and is currently `300000` ms (five minutes). The timer starts when the round enters `BATTLE`.

On timeout, the activity logs `SpectatorArena: WATCHDOG_TIMEOUT`, compares living actor counts, and awards the round to the team with more survivors. Equal survivor counts are recorded as a draw; no fake kills are created. The same `RoundOver` guard prevents a timeout from producing a second result.

## Recovery behavior

The round reset removes surviving team actors without creating artificial gibs, preserves the scene’s real combat damage, and starts the next round automatically. The spectator camera falls back to the center when no valid combatant exists. Spawn and one-team failure cases resolve through the same guarded result path rather than issuing duplicate resets.

## Verification and known issues

The event-aware review build passes its standalone Lua behavioral tests and Lua syntax check. Its required helper module and pure test are now packaged with the activity so a clean checkout is self-contained. The source was rebuilt as `Debug Release|x64` with zero build errors. The separate engagement-offset follow-up was visually reviewed in an isolated Debug Release capture on 2026-09-13: 50 frames over approximately 25 seconds across rounds 28→29, readable opposing combatants, ordinary follow return, and no sampled jitter or empty-terrain lock. **Visual sanity: PASS. Camera acceptance: HOLD.** A subsequent review-only trace run covered five complete rounds plus a final bounded round and recorded 12 `CAMERA_EVENT_REMOVAL_UNCONFIRMED` records, but zero observed deaths, attribution accepts, event requests, or target issuances. The rendered sample remained visually sane, but no attributable cut occurred. The likely boundary is actor removal before a live→dead observation, with several removals also outside the 400 ms attribution window. The HUD remains **ACCEPTED_FOR_THIS_REVIEW_BUILD** independently.

The stream-facing HUD follow-up is also **ACCEPTED_FOR_THIS_REVIEW_BUILD**. It uses Lua-only screen primitives for upper-corner team panels, a centered round/time header, combat pressure, and the existing centered result banner. A 100-frame native capture showed readable battle HUD placement and the transition into round 2; the runtime log reached `ROUND_RESULT` without Lua errors. The result banner itself was not retained in a frame because the final capture window ended immediately before that transition.

The last pre-checkpoint source milestone remains `48bf4c8e9` (`chore: ignore local dependency and Python cache artifacts`). The camera dependency packaging and this acceptance decision are separate from visual behavior acceptance. The existing deterministic short-timeout watchdog evidence and historical soak checkpoint remain unchanged.

The runtime still emits an empty-scene-preset warning before successfully loading `Ketanot Hills`, plus repeated sound-device initialization warnings. These are known warnings and are separate from the Lua lifecycle changes. The historical checkpoint/tag `spectator-soak-2026-08-31` remains unchanged.

### Native lifecycle boundary — 2026-09-13

Source inspection confirms that `g_ActivityMan.Update()` runs before
`g_MovableMan.Update()` in `Source/Main.cpp`. Native actor update changes an
actor to `DYING` at health `<= 0`, later changes it to `DEAD`, and the following
MovableMan pass moves dead actors out of the live list and team rosters. Lua
exposes `Status`, `Health`, `PrevHealth`, `IsDead()`, and the `DYING`/`DEAD`
values, so `DYING` is the last authoritative in-roster signal available to the
activity. The runtime trace and source ordering therefore identify lifecycle
observability—not camera presentation—as the primary blocker. The next test is
to correlate `DYING` under the existing conservative attribution gates; no gate
widening or camera-v2 ally tracking is authorized by this checkpoint.

Recent live verification also reached `BATTLE` but produced no `SPECTATOR_EVENT` records in `LogConsole.txt`; the telemetry helper passes standalone tests, but live telemetry transport/module resolution remains unresolved.

## Rollback and next milestones

To restore normal menu startup, set `LaunchIntoActivity = 0` for a runtime-only test and remove or conditionally disable the dedicated startup assignments in `Source/Main.cpp` for a normal-menu source build. Do not delete the original menu systems.

Next priorities are:

1. test the Lua-visible `DYING` transition as the authoritative in-roster death signal without loosening attribution gates
2. prove the first attributable camera cut with a telemetry-directed capture: T − 2 s through request, selection, movement, arrival, and T + 3–5 s
3. observe 3–5 complete rounds for deduplication/retrigger suppression, return/reset behavior, and survivor/end-of-round priority
4. keep the HUD accepted and the nearby-ally firing aggregation idea deferred as a camera-v2 candidate
5. configurable teams/loadouts
6. define and fixture-test procedural close-quarters environment descriptors
7. longer-duration soak testing for any accepted generated-scene candidate
