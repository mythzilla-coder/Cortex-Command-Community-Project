# Spectator continuation status and R2 investigation — 2026-09-05

## Verified starting state

Repository: C:/Users/mythz/Documents/Cortex-Command-Community-Project
Branch: spectator-random-factions
Starting HEAD: 4bcbd0076e3a41e7378dc8eef11ab72f6791b6da
Historical tag spectator-soak-2026-08-31: 241c42119886c992a020ddfc73482a1dae71e4b4 (preserved).
The starting index was empty. Three existing modified documents and all untracked camera, research, runtime-log and dependency artifacts remain protected. Starting status and a pre-existing tracked-diff snapshot are saved under work/continuation-2026-09-05/. No reset, clean, merge, rebase, broad deletion, settings edit, or gameplay edit was performed. Production remains AI_V2_MODE = "OFF" at SpectatorArena.lua:955.

## Repository integrity

`git grep -n SpectatorCameraEventLogic HEAD -- Data/Base.rte/Activities/SpectatorArena.lua` finds the committed require at line 1124; `git ls-tree HEAD Data/Base.rte/Activities/SpectatorCameraEventLogic.lua` returns no file. The working-tree module and camera test are untracked. Therefore working-tree tests passing does not establish a self-contained clean checkout. The camera handoff explicitly records pending human visual acceptance. This bounded continuation records the defect without adopting or rejecting that candidate or staging existing user work. Next action: review the candidate and package module/test/integration together, or explicitly reject the integration while preserving the candidate.

## Rechecked baseline evidence

Commands: `python tools/spectator_soak_report.py` with each snapshot below.
- logs/session-2026-09-03-debug-release-0924/SPECTATOR_EVENT_LOG.txt: 104/104 completed; incomplete_final_round false; watchdog_events 0.
- logs/session-2026-09-03-debug-release-0924/LogConsole.txt: 104/105 completed; incomplete_final_round true; watchdog_events 0.
- Both: average duration 43078.56525 ms, shortest 22215.778 ms, longest 91712.998 ms.

The count requirement is met by existing OFF evidence. This is not a new native run and does not approve SHADOW, damage semantics, TASKS, or merge. Older statements that the 50-round count itself remains blocked are superseded by this recheck; semantic activation remains blocked.

## R2 evidence and first-divergence limitation

Raw source: SPECTATOR_ARENA_R1B_ATTACHMENT_TRACE_LOG_2026-09-03.txt, first records at lines 251–252. Parsed all 16 WEAPON_FIRST_UPDATE records: 16 equipped=NONE; 16 retainedValid=true and retainedAttached=true; 16 worldItemCount=0; all 16 lack foregroundArmMOID. Example actor 16975 has retainedMOID=8, retainedRootMOID=1, foregroundArmHeld=NONE, equippedMOID=-1, updateCount=2. An attached retained weapon does not establish its exact parent or a usable actor discovery path.

Known-good SPECTATOR_FIRE_F3_LOG.txt lines 14–18 show foregroundPreset=SMG at INVENTORY_HANDOFF and ACTORS_INSERTED; lines 27–30 still show SMG at SAMPLE_1/2. These fixture records do not contain the corresponding arm/root identity schema. The duplicate plain and SPECTATOR_EVENT fixture records must not be counted as separate samples.

Current source SpectatorArena.lua:1897 onward captures FGArm and HeldDevice, but the historical attachment log lacks arm identity values present in current source. Do not backfill those values from source or combine different snapshots into a claimed R2 run. BGArm topology and identical four-stage fixture/Arena samples remain absent. First divergence is UNDETERMINED, not a proven ownership defect.

Next bounded implementation: add the planned pure ordered comparison contract and tests; capture identical T0_AFTER_INVENTORY, T1_AFTER_ADD_ACTOR, T2_FIRST_UPDATE, T3_STABLE_UPDATE schema in fixture and Arena; reject missing stages/fields. Compare attachment relationships and classes; treat numeric MOIDs as run-local identities, not expected equal values across independent runs. Match actor/team/sample identity and normalize plain/PRINT duplicates. Retain wrappers only in diagnostic fixtures, never as production sensing or a gameplay fix. Only then classify the earliest divergence.

## Validation and limits

- python -m unittest discover -s tests -p '*.py' -v: 12 tests, OK (output saved in work/continuation-2026-09-05/python-tests.txt).
- Fengari tests/spectator_camera_event_test.lua: PASS.
- Fengari tests/spectator_ai_controller_test.lua: PASS.
- Fengari tests/spectator_telemetry_test.lua: PASS. An initial command used nonexistent spectator_ai_telemetry_test.lua; corrected after listing actual tests.
- git diff --check: no whitespace errors; existing CRLF conversion warnings only.
- MSBuild not found by Get-Command; no native build attempted. Native executables exist, but the normalized topology fixture is not implemented and no controlled native capture was attempted within the four-minute window.
- Existing Cortex Command.debug.release.exe SHA256: 477AA880D7BC55C3E7D8E6C2B864B21104EC4A7210D028BCDA9D6CDB9D2021A7. This identifies the local binary only, not the provenance of historical logs.

## Recovery and external mirror

This report is the only newly committed file; the existing work log receives an appended continuation entry and remains dirty to preserve its prior changes. No runtime or camera candidate is staged. Drive destination is the observed parent of the existing Cortex project reports: 0AGSQc2hrH2H_Uk9PVA. Upload outcome is recorded separately in the local work log after the connector returns; this report makes no advance upload claim.
