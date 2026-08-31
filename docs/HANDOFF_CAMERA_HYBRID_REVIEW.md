# ChatGPT handoff — hybrid Spectator Arena camera revision

Continue development at:

`C:\Users\mythz\Documents\Cortex-Command-Community-Project`

Current milestone: commit `9049540d0` (`Add automatic Spectator Arena camera director`). The historical stability tag `spectator-soak-2026-08-31` must remain unchanged.

## Review finding

The current Camera Director sometimes approaches active combat correctly, but the midpoint/cluster focus is not consistently readable. At other times it does not center on a soldier as reliably as the earlier implementation. The reliable soldier-centered behavior should become the basis again.

## Requested next design

Implement a conservative hybrid camera policy:

1. Default to following a valid living combatant, preserving the earlier soldier-centered behavior.
2. Periodically evaluate nearby opposing actors for a meaningful point of interest.
3. Switch to the point of interest only when it is clearly stronger than the current soldier focus.
4. Hold the point of interest briefly, without hard cuts or jitter.
5. Return to a valid living soldier after the point-of-interest hold, or immediately if its anchor disappears.
6. Fall back to another living combatant, then the scene center.

The camera should occasionally show action, not permanently abandon the soldier-follow basis. Keep the existing real-time combat, factions, weapons, map, scoring, watchdog, lifecycle state machine, and direct launch unchanged.

## Constraints

- Do not add zoom cinematography, stream HUD, event hooks, randomized factions/loadouts, tournaments, map rotation, or viewer integration.
- Reuse Cortex Command observation-target smoothing.
- Keep camera evaluation timer-driven and avoid per-frame log spam.
- Preserve last-survivor handling and safe non-`BATTLE` framing.

## Suggested implementation questions

- Store a `CameraMode` such as `SOLDIER_FOLLOW` or `POINT_OF_INTEREST`.
- Keep a `CameraFollowActor` and a separate `CameraPOIPosition`/score.
- Evaluate POI candidates on the existing interval, but require a meaningful score margin before leaving soldier-follow mode.
- Use a modest POI hold duration, then return to the best valid soldier.
- If the followed soldier dies, immediately select another living actor; do not wait for the POI timer.
- Prefer the selected soldier’s nearby engagement location as the POI rather than an arbitrary empty midpoint.

## Verification required before implementation is accepted

- Build `Debug Release|x64`.
- Launch a fresh `Cortex Command.debug.release.exe` process.
- Visually confirm the camera normally centers on a soldier.
- Visually confirm occasional switches to active combat points.
- Confirm no rapid jitter or empty-terrain lock.
- Confirm recovery when the selected soldier dies.
- Let several normal rounds complete and verify scoring/reset/watchdog behavior remains unchanged.
- Inspect `LogConsole.txt` and current abort/error logs.

Do not claim completion until the hybrid behavior has been visually reviewed. After implementation, update `docs/SPECTATOR_ARENA.md`, synchronize the existing Drive documentation, update the existing Notion project record, and report the resulting commit and remaining issues.
