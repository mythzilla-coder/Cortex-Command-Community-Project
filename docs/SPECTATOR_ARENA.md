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

## Winner and score logic

The first team with no living actors loses. If both teams are eliminated, the result is a draw. `RoundOver` prevents duplicate results, score increments, or reset operations. The score remains cumulative for the life of the activity.

## Watchdog

`MaxRoundDurationMS` is centralized in `StartActivity` and is currently `300000` ms (five minutes). The timer starts when the round enters `BATTLE`.

On timeout, the activity logs `SpectatorArena: WATCHDOG_TIMEOUT`, compares living actor counts, and awards the round to the team with more survivors. Equal survivor counts are recorded as a draw; no fake kills are created. The same `RoundOver` guard prevents a timeout from producing a second result.

## Recovery behavior

The round reset removes surviving team actors without creating artificial gibs, preserves the scene’s real combat damage, and starts the next round automatically. The spectator camera falls back to the center when no valid combatant exists. Spawn and one-team failure cases resolve through the same guarded result path rather than issuing duplicate resets.

## Verification and known issues

The event-aware review build passes its standalone Lua behavioral tests and Lua syntax check. The source was rebuilt as `Debug Release|x64` with zero build errors, and a fresh process directly loaded `Ketanot Hills`, started `Spectator Arena`, and entered `BATTLE`. Hardware-rendered frames were captured successfully and showed soldier-centered combat without an observed empty-terrain lock. The corrected build has not yet completed the required 3–5 visually reviewed rounds, and a deliberately observed off-screen attributed kill has not yet been confirmed. The milestone is therefore **review pending**, not accepted, complete, or committed.

The last committed milestone remains `3d67863e7` (`Document hybrid spectator camera handoff`). The event-aware camera, its pure inference module, tests, and these documentation updates remain uncommitted for review. The existing deterministic short-timeout watchdog evidence and historical soak checkpoint remain unchanged.

The runtime still emits an empty-scene-preset warning before successfully loading `Ketanot Hills`, plus repeated sound-device initialization warnings. These are known warnings and are separate from the Lua lifecycle changes. The historical checkpoint/tag `spectator-soak-2026-08-31` remains unchanged.

Recent live verification also reached `BATTLE` but produced no `SPECTATOR_EVENT` records in `LogConsole.txt`; the telemetry helper passes standalone tests, but live telemetry transport/module resolution remains unresolved.

## Rollback and next milestones

To restore normal menu startup, set `LaunchIntoActivity = 0` for a runtime-only test and remove or conditionally disable the dedicated startup assignments in `Source/Main.cpp` for a normal-menu source build. Do not delete the original menu systems.

Next priorities are:

1. finish human review and tune/accept the event-aware camera
2. commit the accepted event-aware camera milestone
3. stream-facing HUD
4. configurable teams/loadouts
5. longer-duration soak testing
