# Spectator telemetry

The activity emits one-line records prefixed with `SPECTATOR_EVENT`. Fields are space-separated `key=value` pairs; unsafe characters are replaced with `_`. Records are emitted only for startup, state transitions, round selection/results, and watchdog intervention.

Examples:

```text
SPECTATOR_EVENT event=ACTIVITY_START
SPECTATOR_EVENT event=ROUND_START round=1 team1=Coalition.rte team2=Ronin.rte
SPECTATOR_EVENT event=STATE round=1 state=BATTLE
SPECTATOR_EVENT event=ROUND_RESULT round=1 winner=COALITION_RTE_WINS durationMS=42000 team1Score=1 team2Score=0
SPECTATOR_EVENT event=WATCHDOG round=2 team1Alive=3 team2Alive=3 reason=timeout
```

`Data/Base.rte/Activities/SpectatorTelemetry.lua` owns encoding and emission. It is intentionally dependency-free and accepts a test sink so behavior can be verified without starting the game. The game’s `print` output is the current transport; future soak tooling can filter on the stable prefix.

The dependency-free Python report tool reads a captured console log:

```text
python tools/spectator_soak_report.py path\to\console.log
```

It reports completed/started rounds, incomplete final rounds, winner counts, duration statistics, and watchdog events.

The checkout has no standalone Lua executable on PATH. The pure-Lua tests have nevertheless been executed with the cached Fengari Lua CLI used for verification in this environment:

```text
lua tests/spectator_camera_event_test.lua
lua tests/spectator_telemetry_test.lua
```

The current live-runtime gap is separate: recent game logs reached `BATTLE` but contained no `SPECTATOR_EVENT` lines, so the soak report cannot yet be trusted for live runs until module loading/output transport is diagnosed.
