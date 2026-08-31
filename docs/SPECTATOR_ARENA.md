# Spectator Arena

## Purpose

Spectator Arena is an autonomous AI-vs-AI Cortex Command activity intended to become a dedicated livestream/spectator application. It keeps the original actors, weapons, AI, projectile physics, gore, particles, destructible terrain, and map systems active while the player observes the match.

The current content is deliberately conservative: two autonomous teams of eight fight in real time on `Ketanot Hills`.

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

### Camera behavior review / next revision

Live review found that the cluster midpoint can sometimes be less useful than the earlier reliable soldier-centered view. The next revision should therefore use a hybrid policy: follow a valid living soldier by default, periodically evaluate combat points of interest, switch to a clearly stronger point of interest only occasionally, hold it briefly, and return to a valid soldier when the point of interest is no longer useful or its anchor disappears. This preserves the dependable soldier basis while still showing meaningful action. No code change is included yet; see `docs/HANDOFF_CAMERA_HYBRID_REVIEW.md` for the implementation handoff.

## Winner and score logic

The first team with no living actors loses. If both teams are eliminated, the result is a draw. `RoundOver` prevents duplicate results, score increments, or reset operations. The score remains cumulative for the life of the activity.

## Watchdog

`MaxRoundDurationMS` is centralized in `StartActivity` and is currently `300000` ms (five minutes). The timer starts when the round enters `BATTLE`.

On timeout, the activity logs `SpectatorArena: WATCHDOG_TIMEOUT`, compares living actor counts, and awards the round to the team with more survivors. Equal survivor counts are recorded as a draw; no fake kills are created. The same `RoundOver` guard prevents a timeout from producing a second result.

## Recovery behavior

The round reset removes surviving team actors without creating artificial gibs, preserves the scene’s real combat damage, and starts the next round automatically. The spectator camera falls back to the center when no valid combatant exists. Spawn and one-team failure cases resolve through the same guarded result path rather than issuing duplicate resets.

## Verification and known issues

The source was rebuilt as `Debug Release|x64` and a fresh process completed four normal rounds and armed a fifth. The direct-launch log confirmed `Ketanot Hills` and `Spectator Arena`; lifecycle logs confirmed battle arming, result, reset, and automatic progression. The camera implementation was exercised by the live activity, but this desktop’s window-capture path did not expose the hardware-rendered game frame for independent visual confirmation; a visual camera review remains recommended on a normal display/recording setup. The existing deterministic short-timeout watchdog run confirmed one timeout, one result, reset, and subsequent round starts.

The runtime still emits an empty-scene-preset warning before successfully loading `Ketanot Hills`, plus repeated sound-device initialization warnings. These are known warnings and are separate from the Lua lifecycle changes. The historical checkpoint/tag `spectator-soak-2026-08-31` remains unchanged.

## Rollback and next milestones

To restore normal menu startup, set `LaunchIntoActivity = 0` for a runtime-only test and remove or conditionally disable the dedicated startup assignments in `Source/Main.cpp` for a normal-menu source build. Do not delete the original menu systems.

Next priorities are:

1. hybrid soldier-follow / point-of-interest camera revision
2. stream-facing HUD
3. configurable teams/loadouts
4. longer-duration soak testing
