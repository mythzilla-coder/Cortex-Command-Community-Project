# Spectator Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make autonomous spectator runs auditable from structured log lines and a deterministic soak-report script without changing the proven round lifecycle.

**Architecture:** Add a small Lua telemetry helper that emits stable `SPECTATOR_EVENT` records and is called only at meaningful lifecycle boundaries. Add a dependency-free Lua log parser that aggregates those records into a compact report and tests it with synthetic input. Existing camera and lifecycle changes remain untouched except for instrumentation call sites.

**Tech Stack:** Cortex Command Lua, Lua 5.x standard library, PowerShell test runner.

**Spec:** User-provided Cortex Command Spectator Project brief in the session attachment.

## Global Constraints

- Do not return to turn-based gameplay.
- Do not casually redesign the working round lifecycle.
- Do not spend this session on subjective visual tuning.
- Preserve all pre-existing uncommitted camera work.
- Verification must be test/log based.

---

### Task 1: Structured event emitter

**Files:**
- Create: `Data/Base.rte/Activities/SpectatorTelemetry.lua`
- Test: `tests/spectator_telemetry_test.lua`

- [ ] Define `Telemetry.Encode(event, fields)` with deterministic key ordering and safe scalar encoding.
- [ ] Define `Telemetry.Emit(event, fields, sink)` so tests can capture lines and runtime defaults to `print`.
- [ ] Test lifecycle, faction, score, watchdog, and malformed-field cases.
- [ ] Run the Lua test and require `PASS`.

### Task 2: Instrument meaningful lifecycle events

**Files:**
- Modify: `Data/Base.rte/Activities/SpectatorArena.lua`

- [ ] Require/load the telemetry module using the project’s existing activity module convention.
- [ ] Emit activity start, round start/spawn counts, battle start, round result, watchdog intervention, reset, and cumulative score events.
- [ ] Keep per-frame logging unchanged except for state-transition guards; do not emit frame-rate telemetry.
- [ ] Run static Lua loading checks and the pure Lua tests.

### Task 3: Deterministic soak report

**Files:**
- Create: `tools/spectator_soak_report.lua`
- Create: `tests/spectator_soak_report_test.lua`
- Create: `docs/SPECTATOR_TELEMETRY.md`

- [ ] Parse `SPECTATOR_EVENT` lines and calculate runtime, rounds, wins, draws, duration extrema/average, watchdogs, abnormal resets, and errors.
- [ ] Ignore unrelated log lines and report incomplete final rounds explicitly.
- [ ] Add synthetic-log tests covering normal rounds, watchdog result, duplicate result, and malformed lines.
- [ ] Document event format, parser usage, and output fields.

### Task 4: Audit checkpoint

**Files:**
- Create/update: `docs/AUTONOMOUS_WORK_LOG.md`
- Create: `docs/AUTONOMOUS_SESSION_SUMMARY_2026-09-02.md`

- [ ] Record starting Git state, changed files, commands, and evidence.
- [ ] Run all available tests and inspect `git diff --check`.
- [ ] Commit only this session’s verified changes; leave pre-existing experimental work recoverable and clearly listed.

