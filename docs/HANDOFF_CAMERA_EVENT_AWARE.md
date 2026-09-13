# ChatGPT handoff — event-aware Spectator Arena camera

Continue development at:

`C:\Users\mythz\Documents\Cortex-Command-Community-Project`

Current branch state:

- The pre-checkpoint source milestone is `48bf4c8e9 chore: ignore local dependency and Python cache artifacts`.
- The hybrid soldier-follow/temporary-POI implementation is present in `Data/Base.rte/Activities/SpectatorArena.lua`; its required helper module and pure test are packaged by this integrity checkpoint.
- The historical stability tag `spectator-soak-2026-08-31` must remain unchanged.

## Current review snapshot

The event-aware hybrid implementation is packaged as a self-contained dependency checkpoint, but remains **unaccepted pending human visual review**. The current camera acceptance decision is recorded in `docs/SPECTATOR_CAMERA_ACCEPTANCE_2026-09-13.md`. Do not describe the behavior as complete without reviewing rendered frames from the running camera.

Files added or materially changed for this review build:

- `Data/Base.rte/Activities/SpectatorArena.lua`
- `Data/Base.rte/Activities/SpectatorCameraEventLogic.lua`
- `tests/spectator_camera_event_test.lua`
- `docs/SPECTATOR_ARENA.md`
- `docs/HANDOFF_CAMERA_HYBRID_REVIEW.md`
- `docs/HANDOFF_CAMERA_EVENT_AWARE.md`

The active priority is:

```text
LAST_SURVIVOR
> CONFIDENT INFERRED EVENT
> SOLDIER FOLLOW
> ORDINARY COMBAT POI
> CENTER FALLBACK
```

### Engine/API research result

No activity-level Lua API was found that directly exposes an actor killer, instigator, damage source, projectile owner, or durable projectile-to-victim attribution. Available and used signals are `AHuman.EquippedItem`, `HDFirearm.FiredFrame`, `HDFirearm.MuzzlePos`, `Actor:GetAimAngle(true)`, `Actor:IsDead()`, `Actor.Health`, `MOSRotating.WoundCount`, and stable `MovableObject.UniqueID`. Collision fields such as `HitWhatMOID` are frame-local and do not provide durable killer attribution.

### Implemented conservative inference

The followed soldier must have fired within `CameraRecentFireWindowMS = 400`. Exactly one opposing actor must then have an observed live-to-dead transition, or be removed after death was already observed. Unexplained disappearance alone is rejected. The victim must be `180–1200` pixels from the muzzle and within `CameraEventMinimumAimDot = 0.85` (about ±32 degrees) of the shot direction. Ambiguous, stale, nearby, out-of-cone, and previously handled victim candidates produce no event.

This remains inference, not proof of authorship. It deliberately favors missed events over false cuts. In particular, a victim removed before the activity observes its dead state will not trigger an event. Reviewers should reject any implementation or documentation change that calls this engine-confirmed attribution.

### Event state and timing

- Default mode: `CAMERA_SOLDIER`.
- Event mode: `CAMERA_EVENT` at the victim's last meaningful position.
- Event hold: `CameraEventHoldMS = 2000`.
- Event cooldown: `CameraEventCooldownMS = 4000`.
- Dedupe: round-scoped handled-victim map keyed by `UniqueID`.
- Return: reuse the prior soldier if still alive; otherwise select a new living soldier.
- Last survivor: explicitly re-anchor to the lone living actor and suppress event/POI cuts.
- Round reset: clear tracked actors, shot context, event position, handled IDs, POI state, and cooldowns.

### Verification completed

- Standalone Lua behavior tests pass under `fengari-node-cli`.
- Lua syntax loading passes.
- `git diff --check` passes.
- `Debug Release|x64` builds with zero errors; existing MSBuild/LuaJIT warnings remain.
- A fresh `Cortex Command.debug.release.exe` process loaded `Ketanot Hills`, automatically started `Spectator Arena`, entered `BATTLE`, and remained responsive.
- Hardware-rendered capture works and sampled frames showed soldier-centered combat without an observed empty-terrain lock.
- `AbortLog.txt` predates this run; the known empty-scene warning still precedes a successful `Ketanot Hills` load.

### Review still required

The corrected build has not yet completed the required 3–5 visually reviewed rounds. A reviewer must confirm event usefulness/timing, no unrelated cut, smooth return, dedupe, last-survivor framing, ordinary POI secondary behavior, clean round reset, and no empty-terrain hold. Do not commit, mark complete, or advance to the stream-facing HUD until this review is accepted.

## Human visual review

The hybrid revision is acceptable as a baseline:

- The camera usually follows a soldier.
- The general behavior works.
- The temporary POI switch is too abrupt.
- POI selection is usually late, after the interesting action has already happened.

New requirement: if the followed soldier shoots and kills an opponent off screen, the camera should recognize that likely event and temporarily move to the event location so the viewer can see the result. Preserve normal soldier-following when no high-confidence event exists.

## Requested next milestone: event-aware camera response

Extend the hybrid camera conservatively:

1. Keep `CAMERA_SOLDIER` as the default mode.
2. Investigate the available Cortex Command Lua/engine APIs for reliable kill attribution, projectile impact, wound, or firearm firing information.
3. Track enough recent context to associate an off-screen kill with the followed soldier when possible:
   - followed actor identity;
   - recent firing/attack activity;
   - victim disappearance or death;
   - victim position and/or last known position;
   - event timestamp and confidence.
4. When confidence is high that the followed soldier caused a kill, enter a short event-focus mode at the victim/event location.
5. Use observation-target smoothing or a short transition so the move is readable rather than an abrupt hard cut.
6. Return to the followed soldier after the event hold, or immediately if the event focus becomes invalid.

## Important constraints

- Do not invent fake kill attribution.
- Do not trigger on every shot, actor disappearance, or unrelated death.
- If the engine cannot provide trustworthy attribution, implement the safest useful approximation and document its confidence limitations rather than pretending certainty.
- Prefer an event-focus lead: identify the likely event as early as possible from firing/projectile/wound state, then move toward the victim before or as the kill resolves.
- Keep event focus brief and cooldown-limited so soldier-follow remains dominant.
- Keep the existing POI cluster detector as a secondary occasional behavior.
- Do not change factions, weapons, loadouts, team size, map, combat rules, scoring, lifecycle state machine, watchdog, or direct launch.
- Do not add HUD, zoom cinematography, tournaments, map rotation, stream integrations, or viewer voting.

## Camera quality targets

- Soldier-follow remains the normal view.
- Event response should be useful without feeling like a hard cut.
- The camera should show the aftermath or active engagement caused by the followed soldier, including an off-screen kill when the event can be identified.
- No stale empty terrain, repeated triggers, or rapid oscillation.

## Verification required

- Build `Debug Release|x64`.
- Launch a fresh process and visually review several rounds.
- Confirm soldier-follow remains dominant.
- Confirm a deliberately observed off-screen kill triggers a useful event response if attribution is available.
- Confirm event response does not trigger repeatedly for one kill.
- Confirm return to soldier-follow after the event hold.
- Inspect `LogConsole.txt` and current abort/error logs.
- Do not commit until human visual review accepts the transition timing and usefulness.

After acceptance, update `docs/SPECTATOR_ARENA.md`, synchronize the existing Drive documentation, update the existing Notion project record, and commit with a clear event-aware camera message.
