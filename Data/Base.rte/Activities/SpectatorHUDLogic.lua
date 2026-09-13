local SpectatorHUDLogic = {}

local function factionLabel(faction, fallback)
    return string.upper(
        string.gsub(faction or fallback, "%.rte$", "")
    )
end

function SpectatorHUDLogic.BuildTeamPanel(faction, alive, score, fallback)
    return factionLabel(faction, fallback) ..
        "  " .. tostring(alive) ..
        "  |  SCORE " .. tostring(score)
end

function SpectatorHUDLogic.BuildBattleHUD(
    roundNumber,
    elapsedRoundText,
    pressureElapsedSeconds,
    pressureThresholdSeconds,
    team1Faction,
    team1Alive,
    team1Score,
    team2Faction,
    team2Alive,
    team2Score
)
    return {
        header = "ROUND " .. tostring(roundNumber) ..
            "  |  " .. tostring(elapsedRoundText),
        team1 = SpectatorHUDLogic.BuildTeamPanel(
            team1Faction,
            team1Alive,
            team1Score,
            "TEAM 1"
        ),
        team2 = SpectatorHUDLogic.BuildTeamPanel(
            team2Faction,
            team2Alive,
            team2Score,
            "TEAM 2"
        ),
        pressure = "COMBAT PRESSURE " ..
            tostring(pressureElapsedSeconds) ..
            "/" .. tostring(pressureThresholdSeconds)
    }
end

function SpectatorHUDLogic.BuildResultHUD(
    roundNumber,
    team1Faction,
    team1Alive,
    team1Score,
    team2Faction,
    team2Alive,
    team2Score
)
    return {
        header = "ROUND " .. tostring(roundNumber) .. " COMPLETE",
        team1 = SpectatorHUDLogic.BuildTeamPanel(
            team1Faction,
            team1Alive,
            team1Score,
            "TEAM 1"
        ),
        team2 = SpectatorHUDLogic.BuildTeamPanel(
            team2Faction,
            team2Alive,
            team2Score,
            "TEAM 2"
        )
    }
end

function SpectatorHUDLogic.BuildResultText(
    resultText,
    team1Score,
    team2Score
)
    return string.upper(resultText or "ROUND RESULT") ..
        "  |  SCORE " .. tostring(team1Score) ..
        " - " .. tostring(team2Score) ..
        "  |  NEXT ROUND..."
end

return SpectatorHUDLogic
