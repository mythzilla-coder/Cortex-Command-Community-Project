# Spectator Arena A1 and firearm reconciliation report — 2026-09-03

## Executive result

The apparent post-spawn Arena stall is closed as an A1 **PASS**. Native OFF,
SHADOW, and OFF-control runs all continued through actor insertion, touchdown,
release, combat, and normal activity updates. A three-round SHADOW run also
completed without a watchdog or Lua runtime failure.

The three-round smoke is nevertheless only **PARTIAL**: visibility and contact
semantics produced real positive evidence, but the Arena never discovered an
equipped firearm after spawn. The controlled F1–F3 firearm fixture remains the
reference implementation and is not contradicted. The open defect is now the
Arena firearm lifetime between actor insertion and the first enumerable
activity update.

## A1 post-spawn progression

The diagnostic used a bounded 256-entry in-memory trace and sparse lifecycle
heartbeats. It sampled BEFORE/AFTER boundaries around actor scanning, camera,
touchdown, fire sensing, AI instrumentation, SHADOW observation, target
distribution, combat pressure, and round-result evaluation. It persisted only
once at the diagnostic timeout or round result; per-event snapshots were not
reintroduced.

Observed native runs:

| Run | Evidence |
| --- | --- |
| OFF control 1 | 1,183 updates and 19.73 simulated seconds by the 20-second wall checkpoint; all 16 actors released; combat progressed. |
| SHADOW comparison 1 | 396 updates and 6.616 simulated seconds by the checkpoint; all 16 actors released; every sampled boundary returned. |
| OFF control 2 | 395 updates and 6.6 simulated seconds; pacing closely matched the SHADOW comparison. |
| SHADOW completion | Round result reached after 48.614 simulated seconds; the process continued through three completed rounds. |

The OFF → SHADOW → OFF comparison rules out a SHADOW-specific blocking call in
the traced path. The large wall/simulation-rate variation is environmental or
native frame pacing in these unattended launches, not evidence of a SHADOW
post-spawn deadlock.

## Three-round semantic SHADOW smoke

| Metric | Round 1 | Round 2 | Round 3 | Total |
| --- | ---: | ---: | ---: | ---: |
| Duration (ms) | 48,614.722 | 51,031.292 | 43,698.252 | — |
| Visible opponents | 56 | 67 | 76 | 199 |
| LOS-positive observations | 56 | 59 | 73 | 188 |
| Contact acquisitions | 37 | 41 | 54 | 132 |
| Contact losses | 36 | 29 | 46 | 111 |
| SHADOW observations | 954 | 552 | 890 | 2,396 |
| Damage events | 263 | 69 | 119 | 451 |
| Fire-sensor samples | 29,398 | 16,870 | 27,429 | 73,697 |
| Equipped-firearm samples | 0 | 0 | 0 | 0 |
| Missing-firearm samples | 29,398 | 16,870 | 27,429 | 73,697 |
| Fire/latch events | 0 | 0 | 0 | 0 |
| SHADOW observation cost (ms) | 135 | 76 | 118 | 329 |

All three rounds represented both teams, completed normally, emitted positive
LOS/contact transitions, and recorded execution cost. No SHADOW observation
preceded the accepted touchdown/release gate, and no world-truth/team-memory
violation or watchdog event was observed. The only `ERROR` text in the native
log was the pre-existing empty-scene lookup warning; no Lua stack trace was
present.

This passes lifecycle, visibility, contact, gating, and bounded execution-cost
evidence. It does not pass Arena firearm discovery or live Arena fire-latch
evidence.

## Exact firearm lifetime boundary

A narrow read-only reconciliation sampled all 16 spawned actors at four points:

1. candidate firearm creation;
2. inventory handoff;
3. immediately after `MovableMan:AddActor`;
4. the first update in which the actor appeared in the MovableMan actor scan.

Every actor had a named `HDFirearm` immediately after insertion, with
`equippedIsFirearm=true`, valid actor/team state, and no background or inventory
item. At that point the held firearm reported `MOID=255` and `RootMOID=255`.
On the first enumerable update, all 16 actors were still valid but foreground,
background, and inventory firearm discovery were all empty.

Therefore:

```text
valid equipped firearm immediately after AddActor
        ↓
weapon disappears before first enumerable activity update
        ↓
73,697 Arena sensor samples see no firearm
```

This is not evidence that `FiredFrame`, the durable F3 latch, or generic
`AddInventoryItem` is broken. Controlled fixture evidence already proves those
primitives. It is an Arena-specific lifetime/ownership transition.

## R1 identity/lifetime differential

The retained-reference differential was run with production behavior OFF. The
flag was explicitly verified before launch and restored afterward. All 16
post-insertion records showed `retentionEnabled=true` and
`retainedReference=true`. At the first actor-enumerable update, all 16 retained
wrappers were still valid named firearms with populated identity fields. The
sampled retained firearms also reported `retainedAttached=true`; none appeared
in the bounded `MovableMan.Items` scan. At the same update, the actor’s
foreground-arm holder and normal foreground/background/inventory discovery
paths were empty.

The no-retention OFF control reported empty actor discovery and zero nearby world
items, matching the original R1A boundary. The known-good controlled fixture
comparison remains consistent: it stores the created weapon as `self.Weapon` and
still reports the SMG as foreground at its first update, but its historical log
does not include the same MOID/arm identity fields.

Classification: **UNRESOLVED** attachment/discovery-path mismatch.

Native evidence rules out simple Lua wrapper loss, firearm deletion during the
sampled interval, a simple world drop into `MovableMan.Items`, and a SHADOW-only
cause. It does not yet prove which parent/attachment path owns the still-attached
object, or whether the `EquippedItem`/arm discovery path is failing for this
Arena topology. Do not turn retained wrapper storage into a production fix.

The next discriminator is a controlled fixture/Arena identity comparison that
adds the same direct `FGArm`/`HeldDevice`, attachment, parent/root identity, and
bounded world-item fields to the known-good fixture. Keep the Arena unchanged
and compare one lifecycle difference at a time.

## Gate status

| Gate | Status |
| --- | --- |
| B5 inventory handoff | PASS in controlled fixture |
| B6 equipped idle | PASS in controlled fixture |
| B7 activation safety | PASS in controlled fixture |
| F1 real discharge | PASS in controlled fixture |
| F2 native `FiredFrame` signal | PASS in controlled fixture |
| F3 durable fire latch | PASS, 10/10 controlled cycles |
| A1 Arena post-spawn progression | PASS |
| Arena visibility/contact | PASS for the three-round smoke |
| Arena firearm discovery/fire latch | FAIL / unresolved lifetime boundary |
| D1 damage semantics | BLOCKED |
| Canonical 50-round OFF baseline | BLOCKED |
| Larger SHADOW evidence/promotion | BLOCKED |
| TASKS-A | NO-GO |
| Merge / PR | NO-GO |

## Safety and evidence artifacts

- Branch remains `spectator-random-factions`; no merge or PR was created.
- Startup target is `Spectator Arena`.
- Production `AI_V2_MODE = "OFF"`.
- No Cortex Command process remains running.
- Camera/research work was not modified by this diagnostic.
- `SPECTATOR_ARENA_A1_OFF_TRACE_LOG.txt`
- `SPECTATOR_ARENA_A1_OFF2_TRACE_LOG.txt`
- `SPECTATOR_ARENA_A1_SHADOW_TRACE_LOG.txt`
- `SPECTATOR_ARENA_A1_SHADOW2_TRACE_LOG.txt`
- `SPECTATOR_ARENA_SHADOW_3_ROUND_LOG_2026-09-03.txt`
- `SPECTATOR_ARENA_LOADOUT_RECON_TRACE_LOG_2026-09-03.txt`
- `ARENA_LOADOUT_RECON_NATIVE_STDOUT.txt`
- `ARENA_LOADOUT_RECON_NATIVE_STDERR.txt`
- `SPECTATOR_ARENA_R1B_ATTACHMENT_TRACE_LOG_2026-09-03.txt`
- `SPECTATOR_ARENA_R1_ATTACHMENT_OFF_TRACE_LOG_2026-09-03.txt`
