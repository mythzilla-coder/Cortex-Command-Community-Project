package.path = "Data/Base.rte/?.lua;" .. package.path

local HUDLogic = require("Activities/SpectatorHUDLogic")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local battle = HUDLogic.BuildBattleHUD(
    3,
    "01:07",
    12,
    20,
    "Browncoats.rte",
    5,
    2,
    "Ronin.rte",
    7,
    1
)

assertEqual(battle.header, "ROUND 3  |  01:07", "battle header")
assertEqual(battle.team1, "BROWNCOATS  5  |  SCORE 2", "team one panel")
assertEqual(battle.team2, "RONIN  7  |  SCORE 1", "team two panel")
assertEqual(battle.pressure, "COMBAT PRESSURE 12/20", "pressure panel")

local resultHUD = HUDLogic.BuildResultHUD(
    3,
    "Browncoats.rte",
    0,
    2,
    "Ronin.rte",
    0,
    1
)

assertEqual(resultHUD.header, "ROUND 3 COMPLETE", "result header")
assertEqual(resultHUD.team1, "BROWNCOATS  0  |  SCORE 2", "result team one panel")
assertEqual(resultHUD.team2, "RONIN  0  |  SCORE 1", "result team two panel")

local result = HUDLogic.BuildResultText("Browncoats Wins", 2, 1)

assertEqual(
    result,
    "BROWNCOATS WINS  |  SCORE 2 - 1  |  NEXT ROUND...",
    "result banner"
)

print("spectator_hud_test: PASS")
