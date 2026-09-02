package.path = "Data/Base.rte/?.lua;" .. package.path
local Telemetry = require("Activities/SpectatorTelemetry")

local function assertEqual(actual, expected, message)
    if actual ~= expected then error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

assertEqual(
    Telemetry.Encode("ROUND_RESULT", { round = 3, winner = "TEAM 1", team1Score = 2, team2Score = 1 }),
    "SPECTATOR_EVENT event=ROUND_RESULT round=3 winner=TEAM_1 team1Score=2 team2Score=1",
    "stable event encoding"
)

local captured
local line = Telemetry.Emit("WATCHDOG", { round = 4, reason = "no progress" }, function(value) captured = value end)
assertEqual(captured, line, "sink receives encoded event")
assertEqual(captured, "SPECTATOR_EVENT event=WATCHDOG round=4 reason=no_progress", "safe field encoding")

local savedPath
ConsoleMan = {
    SaveAllText = function(_, path) savedPath = path end
}
Telemetry.ConfigureRuntime("SPECTATOR_EVENT_LOG.txt")
Telemetry.Emit("ACTIVITY_START", {})
assertEqual(savedPath, nil, "event emission does not force a disk snapshot")
Telemetry.Snapshot()
assertEqual(savedPath, "SPECTATOR_EVENT_LOG.txt", "runtime telemetry snapshot path")
print("spectator_telemetry_test: PASS")
