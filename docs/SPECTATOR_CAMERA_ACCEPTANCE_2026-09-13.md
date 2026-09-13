# Spectator camera acceptance — 2026-09-13

## Decision

**HOLD_FOR_VISUAL_ACCEPTANCE**

The event-aware camera helper and integration remain behaviorally unaccepted. The
required native review of 3–5 complete rounds could not be completed in this
session because the Windows computer-use surface exposed no native app window,
and the fresh process did not produce a reviewable runtime capture. This is an
infrastructure/review limitation, not evidence that the camera behavior passed
or failed.

## Integrity checkpoint

- Branch: `spectator-random-factions`
- Starting HEAD: `48bf4c8e980a0d9410cce83fd35a0eba456b2b88`
- Production mode remains `AI_V2_MODE = "OFF"`.
- `SpectatorArena.lua` already contained the runtime require for
  `Activities/SpectatorCameraEventLogic`; the module and its pure test were
  untracked. This checkpoint packages that existing dependency atomically so a
  clean checkout is self-contained.
- No gameplay, AI, faction, loadout, map, scoring, watchdog, or telemetry
  semantics were changed.

## Verification

- `spectator_camera_event_test.lua`: PASS.
- Existing preserved OFF evidence: 104/104 completed rounds in the event
  snapshot, 104/105 in the console snapshot with one incomplete trailing start,
  and 0 watchdog events.
- The Debug Release x64 build completed with exit code 0; existing MSBuild and
  LuaJIT warnings remain.

## Native review attempt

The freshly built executable was launched from the repository root and exposed
a responsive game process with title `Cortex Command Community Project (Debug
Release)`. The computer-use inventory nevertheless returned no native app
windows, so no rendered-frame inspection was possible. The process did not
produce a new `LogConsole.txt` capture suitable for round review; the existing
`AbortLog.txt` predates this attempt and was not used to classify the result.

The following acceptance items therefore remain unverified:

- soldier-follow dominance across 3–5 complete rounds;
- one credible off-screen event response;
- smooth return and victim deduplication;
- last-survivor framing and clean round reset;
- absence of empty-terrain holds or camera jitter.

## Next gate

Run the self-contained package on a host with native rendered-frame capture,
review the required complete rounds, and then mark this decision `ACCEPT`,
`HOLD_FOR_TUNING`, or `REJECT`. Do not enable HUD work or change the AI gate
based on this report alone.
