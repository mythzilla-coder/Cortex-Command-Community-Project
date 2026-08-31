# Cortex Command AI-vs-AI Spectator Simulation

## Proven checkpoint  2026-08-31

This build is the first proven long-running autonomous spectator version.

### Soak test

- Approximate unattended runtime: 1 hour 44 minutes
- State at manual exit: Round 66
- Completed matches: 65
- Visible cumulative score: 3629
- No manual intervention was required during the run

The following loop operated repeatedly:

1. Spawn two AI teams
2. Give actors their combat loadouts
3. Run real-time autonomous Cortex Command combat
4. Detect team elimination / winner
5. Update persistent match score
6. Reset the battlefield / round state
7. Spawn the next match
8. Continue indefinitely

This demonstrates that the autonomous livestream/spectator concept is viable.

## Project direction

This is no longer being developed as a turn-based game.

The goal is a dedicated autonomous AI-vs-AI spectator simulation suitable
for TikTok, livestreaming, recordings and tournament-style content.

Cortex Command is primarily being retained for the parts that make the
simulation visually and mechanically interesting:

- actors and sprites
- factions
- weapons
- projectiles
- AI combat
- wounds and gore
- gibbing
- particles
- explosions
- physics
- destructible terrain
- usable maps/scenes
- sound and combat effects

Unrelated Cortex Command systems such as campaign/conquest, editors,
traditional player modes and unnecessary menus should not be aggressively
removed yet. They may have hidden dependencies. Strip them only after the
spectator application is mature and verified.

## Current working capabilities

- Real-time AI-vs-AI combat
- 8v8 baseline
- Automatic actor spawning
- Automatic weapon assignment
- Autonomous movement and engagement
- Spectator camera
- Winner/elimination detection
- Correct winner state
- Automatic round restart
- Persistent Red/Blue scoring across rounds
- Continuous unattended match cycling

## Development policy

Preserve this checkpoint before major modifications.

Do not reintroduce turn-based behavior unless that concept is explicitly
revisited later.

Avoid rewriting Cortex Command's native combat systems when the existing
engine already provides the desired behavior.

## Next priorities

1. Automatic camera director
   - follow meaningful firefights
   - detect explosions / concentrated action
   - avoid staring at isolated or inactive actors
   - special handling for last survivors

2. Stream-facing HUD
   - team names
   - current score
   - round number
   - alive counts
   - winner transition
   - clean presentation for viewers

3. Reliability
   - maximum match duration
   - stuck-round detection
   - automatic recovery/reset
   - protection against empty or broken spawns
   - long-duration soak testing

4. Match configuration
   - team sizes
   - factions
   - actors
   - weapons/loadouts
   - maps
   - randomization
   - tournament formats

5. Streaming presentation
   - OBS-friendly capture
   - vertical 9:16 layout
   - TikTok-oriented framing
   - eventually optional viewer interaction/voting

## Launch

From PowerShell:

    cd "$HOME\Documents\Cortex-Command-Community-Project"
    & ".\Cortex Command.debug.release.exe"

## Git checkpoint

An annotated Git tag named:

    spectator-soak-2026-08-31

marks the proven unattended spectator build associated with this document.
