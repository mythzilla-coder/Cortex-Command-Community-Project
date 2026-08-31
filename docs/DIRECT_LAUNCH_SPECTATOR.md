# Direct-launch spectator mode

This fork’s debug-release executable is configured to start the existing autonomous spectator activity directly. The normal menu code and assets remain present; startup selects the activity before the normal menu loop can run.

## Runtime configuration

The activity and scene are:

```ini
LaunchIntoActivity = 1
DefaultActivityType = GAScripted
DefaultActivityName = Spectator Arena
DefaultSceneName = Ketanot Hills
```

These values are also present in `Userdata/Settings.ini` when testing locally. That file is runtime/user state and is not tracked by Git.

## Source-controlled startup behavior

`Source/Main.cpp` applies the same four values through the existing `ActivityMan` and `SceneMan` startup path after data modules load. This makes the standalone executable reproducible even when a user has a different local `Userdata/Settings.ini`. `ActivityMan` still initializes the normal menu systems, so the menu remains available for future rollback or a non-spectator build.

## Restoring normal menu startup

For a local runtime-only test, set `LaunchIntoActivity = 0` in `Userdata/Settings.ini`. For a normal-menu source build, remove or conditionally disable the four dedicated-spectator assignments in `Source/Main.cpp`, then rebuild. The activity registration and Lua spectator implementation should remain unchanged.

## Verification

- Repository checkpoint `spectator-soak-2026-08-31` remained intact before editing.
- `Debug Release|x64` rebuilt successfully with MSBuild after the source change.
- Fresh launches bypassed the menu path and produced: `Scene "Ketanot Hills" was loaded`, `SpectatorArena: autonomous AI vs AI spectator`, and `Activity "Spectator Arena" was successfully started`.
- The fresh-run console log recorded round 1 finishing (`BROWNCOATS WINS`), followed by automatic selection and arming of round 2. The current executable also contains the Spectator Arena lifecycle/watchdog changes documented in `SPECTATOR_ARENA.md`.
- No Lua-loading errors or abort-log update were observed. Repeated audio-device warnings and one `Finding Scene preset '' failed` message were emitted; the requested scene loaded successfully immediately afterward. These should be revisited separately if clean logs are required.

The executable was allowed to run unattended for multiple minutes on repeated fresh launches. The observed round duration was long enough that each verification run reached one completed round and the next round armed before the process was closed for log flushing.

## Distribution recommendation

Keep the source startup selection in Git. Do not commit `Userdata/Settings.ini`; it is user/runtime state. A distribution package may include the four settings as a convenience, but the source-controlled startup path is the reproducible requirement for the dedicated spectator executable.
