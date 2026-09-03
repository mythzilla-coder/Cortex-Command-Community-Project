# Cortex Command spectator AI V2 — project status

Date: 2026-09-03  
Branch: `spectator-random-factions`  
Checkpoint HEAD: `1bff421aefaa5f383aa815502d150a885c5b2735` (`Trace Arena firearm attachment boundary`)

Local evidence state: post-checkpoint R1B/A1 runtime artifacts are present in
the working tree and are authoritative for this status. The working tree is
intentionally dirty with unrelated camera/research work and diagnostic output;
none of that work is being reset or downgraded.

## Current conclusion

The controlled firearm chain is proven end to end: inventory handoff, equipped
idle state, safe activation, physical discharge, native `FiredFrame`, and the
durable SHADOW latch all pass. The Arena also progresses normally after spawn,
and a three-round SHADOW smoke produced real LOS-positive contacts and contact
transitions without watchdog/runtime errors.

The current blocker is narrower: Arena actor-owned firearm discovery is empty by
the first enumerable activity update. R1B retained-reference evidence shows the
firearm wrapper remains valid and attached, with no matching world item, so this
is an unresolved attachment/discovery-path mismatch rather than a proven
deletion or Lua-wrapper lifetime failure. Because live Arena firearm discovery
remains zero, the smoke cannot yet validate live fire-latch events. F3 should
not be modified unless new Arena evidence contradicts the controlled 10/10
result.

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

Run R2: one controlled known-good fixture/Arena identity comparison at T0–T3,
with matching direct `Actor`, `FGArm`/`BGArm`, `HeldDevice`, weapon,
attachment/parent/root, `UniqueID`/`MOID`/`RootMOID`, and bounded world-item
fields. Change no Arena behavior. The retained-reference experiment already
rules out simple wrapper loss; the remaining question is which attachment or
discovery path owns the still-attached object.

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
