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

`Data/Base.rte/Activities/SpectatorTelemetry.lua` owns encoding and emission. It is intentionally dependency-free and accepts a test sink so behavior can be verified without starting the game. The game’s Lua `print` output is routed into `ConsoleMan` and is the current transport; future soak tooling can filter on the stable prefix.

`LogConsole.txt` is a shutdown snapshot, not a live append-only file: `ConsoleMan::Destroy()` writes the in-memory console buffer when the engine exits normally. For live capture, launch the executable with `-cout` and capture stdout, or close the game cleanly before reading `LogConsole.txt`. A forced process termination can discard the in-memory records and falsely appear to show a telemetry gap.

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

The runtime transport is now verified: a fresh executable smoke run produced `SPECTATOR_EVENT` records in `SPECTATOR_EVENT_LOG.txt`, including activity start, AI V2 configuration, round start, and state transitions. The snapshot is intentionally ignored by Git. A longer soak is still required for completed-round distributions and watchdog rates.
