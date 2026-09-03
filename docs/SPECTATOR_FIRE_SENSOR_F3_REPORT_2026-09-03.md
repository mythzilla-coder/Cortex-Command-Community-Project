# Spectator firearm sensor F3 report — 2026-09-03

## Gate result

F3 **PASS** on the native Windows `Debug Release|x64` executable. The run used
the temporary `Spectator Fire Sensor Differential` startup target and restored
`Spectator Arena` before the final verification build. No tactical behavior,
waypoint logic, TASKS, TACTICAL mode, or camera/research files were changed by
this gate.

## Evidence

The controlled fixture completed ten held-activation fire cycles:

| Signal | Result |
| --- | ---: |
| Confirmed shots by ammo decrement | 10 |
| Ammo | 30 → 20 |
| `FiredFrame` captures | 10 |
| Durable fire-frame count | 10 |
| Durable discharged-round count | 10 |
| Durable fire-event count | 10 |
| False fire increments | 0 |
| Last fire timestamp | `849.966 ms` retained after the transient frame |
| `FiredRecently` before expiry | true |
| `FiredRecently` after the 1000 ms window | false |
| Fixture result | PASS |

The highest-value transition was observed at the tenth shot: the same update
reported `ammo=20`, `roundsFired=1`, `firedFrame=true`,
`fireFrameCount=10`, `roundsDischargedObserved=10`, and
`lastFireTimeMS=849.966`. The following samples reported
`firedFrame=false` and `roundsFired=0` while retaining the durable counts and
timestamp.

Evidence artifact: `SPECTATOR_FIRE_F3_LOG.txt`.

## Implementation boundary

`RecordFireSensorSample` is now the owner of high-frequency fire latching. It
updates `LastFireTimeMS`, `FireEventCount`, `FireFrameCount`, and
`RoundsDischargedObserved` only when the read-only `FiredFrame` signal is true.
The Arena shadow-observation path no longer passes the transient fire signal,
avoiding duplicate latches while retaining read-only health bookkeeping.

## Verification and restoration

- Focused Fengari controller test: PASS.
- Python integration tests: 3/3 PASS.
- `git diff --check`: PASS.
- Native `RTEA.sln` `Debug Release|x64`: PASS, 0 errors, 11 existing warnings.
- Startup target restored to `Spectator Arena`.
- Production `AI_V2_MODE = "OFF"` verified.
- No native test process remains.
- `Source/Main.cpp` has no temporary startup-target diff.

The native log still contains the known scene/audio initialization warnings
(`Finding Scene preset ''` and sound-device readiness messages). They did not
prevent fixture completion and are unrelated to the F3 acceptance criteria.

## Arena follow-up status — revised after A1

A later native three-round SHADOW run closed the apparent post-spawn stall and
produced real semantic evidence: 199 visible-opponent observations, 188
LOS-positive observations, 132 contact acquisitions, 111 contact losses, 2,396
SHADOW observations, and zero watchdog events. No observation preceded the
accepted touchdown/release gate.

The smoke remains **PARTIAL**, because 73,697 fire-sensor samples discovered no
equipped Arena firearm and therefore emitted no live fire-latch event. A narrow
reconciliation found every actor holding a named `HDFirearm` immediately after
`MovableMan:AddActor`, but no foreground, background, or inventory firearm was
present on the first actor-enumerable update. This is now an Arena
weapon-lifetime problem, not an F3 sensor problem.

Full evidence and the next single-variable diagnostic are documented in
`docs/SPECTATOR_ARENA_A1_FIREARM_RECON_REPORT_2026-09-03.md`.

## Next gate

F3 remains closed as PASS. The next gate is to resolve Arena firearm lifetime
and then rerun the 3–5 round SHADOW smoke to prove live firearm discovery and
fire-latch events. Damage semantics, the canonical OFF baseline, merge/PR, and
TASKS-A remain blocked.

## A0 spawn-progression diagnostic — 2026-09-03

The bounded in-memory spawn trace was run as an OFF control and as a temporary
SHADOW comparison. Both runs reached `ROUND_SPAWN_COMPLETE`; all eight actors
per team passed actor creation, firearm selection, inventory handoff, actor
insertion, and controller registration boundaries. The trace is capped at 256
entries and persisted once at the terminal spawn boundary. No SHADOW-only spawn
boundary was identified.

The later A1 diagnostic supersedes this initial bounded observation: Arena
progression and round completion now pass, while live Arena firearm discovery
remains unresolved. Production was restored to `AI_V2_MODE = "OFF"` and no test
process remains.
