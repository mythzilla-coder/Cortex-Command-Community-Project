# Cortex Command spectator AI V2 — project status

Date: 2026-09-03  
Branch: `spectator-random-factions`  
Checkpoint HEAD: `5d045234a721f8cfde9d05815d3955de5716b1d4`

## Current conclusion

The controlled firearm chain is proven end to end: inventory handoff, equipped
idle state, safe activation, physical discharge, native `FiredFrame`, and the
durable SHADOW latch all pass. The Arena also progresses normally after spawn,
and a three-round SHADOW smoke produced real LOS-positive contacts and contact
transitions without watchdog/runtime errors.

The current blocker is narrower: Arena actors lose their equipped firearm
between the immediate post-`AddActor` checkpoint and the first enumerable
activity update. Because live Arena firearm discovery remains zero, the smoke
cannot yet validate live fire-latch events. F3 should not be modified unless
new Arena evidence contradicts the controlled 10/10 result.

## Stable project boundaries

- Production default remains `AI_V2_MODE = "OFF"`.
- Startup remains `Spectator Arena` on `Ketanot Hills`.
- V11/V11.1 touchdown/release and distributed pursuit behavior remain the
  accepted gameplay baseline.
- NativeHumanAI continues to own aiming, firing, movement, jetpack use,
  digging, and local reactions.
- OFF and SHADOW instrumentation must not issue tactical orders.
- Camera/research work is independent and remains untouched by the current AI
  diagnostics.
- No merge or pull request is authorized at this checkpoint.

## Evidence gates

| Gate | Status | Meaning |
| --- | --- | --- |
| B5–B7 | PASS | Controlled inventory, idle equipment, and activation safety are proven. |
| F1–F3 | PASS | A physical shot, native fire signal, and 10/10 durable latch are proven. |
| A0 spawn | PASS | All 16 actors cross creation, handoff, insertion, and registration. |
| A1 progression | PASS | No post-spawn blocker; release, combat, and round completion occur. |
| Arena visibility/contact | PASS | Three rounds produced positive LOS and acquire/loss transitions. |
| Arena weapon discovery | FAIL | 0 equipped discoveries across 73,697 samples. |
| Arena live fire latch | BLOCKED | Cannot evaluate until firearm lifetime is resolved. |
| D1 damage semantics | BLOCKED | Follows Arena live-fire evidence. |
| 50-round OFF baseline | BLOCKED | Preserve until telemetry/runtime schema is trustworthy. |
| SHADOW promotion | BLOCKED | Requires live Arena weapon/fire evidence and larger sample. |
| TASKS-A | NO-GO | No tactical behavior activation. |
| Merge / PR | NO-GO | Branch remains isolated. |

## Next recommended action

Run one diagnostic differential: retain the spawned Arena firearm as an
activity-owned Lua reference until the first actor-enumerable update. Change no
other variable. This tests the strongest remaining difference from the
known-good controlled fixture while preserving the accepted behavior and F3
implementation.

If retention succeeds, isolate the ownership/lifetime semantics and design the
smallest safe correction. If it fails, add read-only foreground-arm attachment
and nearby-world-item observations, then compare one Arena/fixture difference
at a time.

After Arena firearm discovery and live fire-latch evidence pass, proceed in
this order:

```text
D1 damage semantics
→ telemetry schema freeze
→ canonical 50-round OFF baseline
→ larger SHADOW evidence run
→ formal SHADOW promotion review
→ TASKS-A consideration
```

Detailed evidence: `docs/SPECTATOR_ARENA_A1_FIREARM_RECON_REPORT_2026-09-03.md`.

