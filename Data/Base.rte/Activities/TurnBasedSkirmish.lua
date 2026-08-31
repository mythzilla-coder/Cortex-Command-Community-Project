function TurnBasedSkirmish:SpawnRound()
    self.RoundOver = false;
    self.BattleStarted = false;
    self.WinnerTeam = Activity.NOTEAM;

    self.Team1Actors = {};
    self.Team2Actors = {};

    local sceneWidth = SceneMan.SceneWidth;

    for i = 1, 8 do
        local actor = CreateAHuman("Soldier Heavy", "Base.rte");

        if actor then
            actor.Team = self.Team1;

            local x = math.floor(sceneWidth * 0.20) + ((i - 1) * 25);
            actor.Pos = SceneMan:MovePointToGround(Vector(x, 0), 0, 0);

            local weapon = CreateHDFirearm("Coalition/Assault Rifle");
            if weapon then
                actor:AddInventoryItem(weapon);
            end

            actor:ClearAIWaypoints();
            actor:AddAISceneWaypoint(
                Vector(sceneWidth * 0.70, actor.Pos.Y)
            );
            actor.AIMode = Actor.AIMODE_GOTO;

            MovableMan:AddActor(actor);
            table.insert(self.Team1Actors, actor);
        end
    end

    for i = 1, 8 do
        local actor = CreateAHuman("Soldier Heavy", "Base.rte");

        if actor then
            actor.Team = self.Team2;

            local x = math.floor(sceneWidth * 0.80) - ((i - 1) * 25);
            actor.Pos = SceneMan:MovePointToGround(Vector(x, 0), 0, 0);

            local weapon = CreateHDFirearm("Coalition/Assault Rifle");
            if weapon then
                actor:AddInventoryItem(weapon);
            end

            actor:ClearAIWaypoints();
            actor:AddAISceneWaypoint(
                Vector(sceneWidth * 0.30, actor.Pos.Y)
            );
            actor.AIMode = Actor.AIMODE_GOTO;

            MovableMan:AddActor(actor);
            table.insert(self.Team2Actors, actor);
        end
    end

    self.RoundNumber = self.RoundNumber + 1;

    print(
        "TurnBasedSkirmish: starting round " ..
        tostring(self.RoundNumber)
    );
end


function TurnBasedSkirmish:ClearRoundActors()
    local actorsToRemove = {};

    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 or actor.Team == self.Team2 then
            table.insert(actorsToRemove, actor);
        end
    end

    for _, actor in ipairs(actorsToRemove) do
        if MovableMan:IsActor(actor) then
            actor:GibThis();
        end
    end
end


function TurnBasedSkirmish:FinishRound(winner)
    if self.RoundOver then
        return;
    end

    self.RoundOver = true;
    self.WinnerTeam = winner;
    self.RoundEndTimer:Reset();

    if winner == self.Team1 then
        self.Team1Score = self.Team1Score + 1;
        self.RoundResultText = "TEAM 1 WINS";

    elseif winner == self.Team2 then
        self.Team2Score = self.Team2Score + 1;
        self.RoundResultText = "TEAM 2 WINS";

    else
        self.RoundResultText = "DRAW";
    end

    print(
        "TurnBasedSkirmish: round " ..
        tostring(self.RoundNumber) ..
        " finished - " ..
        self.RoundResultText
    );
end


function TurnBasedSkirmish:StartActivity()
    print("TurnBasedSkirmish: continuous AI vs AI spectator");

    self.Team1 = Activity.TEAM_1;
    self.Team2 = Activity.TEAM_2;
    self.SpectatorTeam = Activity.TEAM_3;

    self.Team1Score = 0;
    self.Team2Score = 0;
    self.RoundNumber = 0;

    self.RoundOver = false;
    self.BattleStarted = false;
    self.RoundResultText = "";

    self.RoundEndDelay = 3000;
    self.RoundEndTimer = Timer();

    self:SetPlayerBrain(nil, Activity.PLAYER_1);
    self:SetTeamOfPlayer(Activity.PLAYER_1, self.SpectatorTeam);
    self:SetViewState(Activity.OBSERVE, Activity.PLAYER_1);

    self.CameraPos = Vector(
        SceneMan.SceneWidth * 0.5,
        SceneMan.SceneHeight * 0.45
    );

    self:SetObservationTarget(
        self.CameraPos,
        Activity.PLAYER_1
    );

    self:SpawnRound();
end


function TurnBasedSkirmish:UpdateActivity()
    local team1Alive = 0;
    local team2Alive = 0;

    local team1Actors = {};
    local team2Actors = {};

    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 then
            team1Alive = team1Alive + 1;
            table.insert(team1Actors, actor);

        elseif actor.Team == self.Team2 then
            team2Alive = team2Alive + 1;
            table.insert(team2Actors, actor);
        end
    end


    -- Find the actual contact point.
    --
    -- We make NO assumptions about left/right movement.
    -- The winning pair is simply the two opposing soldiers
    -- with the smallest ordinary map-space distance.

    local followActor = nil;
    local closestEnemy = nil;

    -- Spectator-interest selection.
    --
    -- Do NOT simply pick the mathematically closest opposing pair:
    -- that can lock the camera onto an isolated 1-v-1 while the
    -- main battle is happening elsewhere.
    --
    -- Instead, score every living soldier by how many enemies are
    -- near them. This favors the densest active firefight.

    local combatRadius = 260;
    local combatRadiusSquared = combatRadius * combatRadius;

    local bestEnemyCount = -1;
    local bestNearestDistance = math.huge;

    local allActors = {};

    for _, actor in ipairs(team1Actors) do
        table.insert(allActors, actor);
    end

    for _, actor in ipairs(team2Actors) do
        table.insert(allActors, actor);
    end

    for _, candidate in ipairs(allActors) do
        local nearbyEnemies = 0;
        local nearestEnemyDistance = math.huge;
        local nearestEnemy = nil;

        local enemies = team2Actors;

        if candidate.Team == self.Team2 then
            enemies = team1Actors;
        end

        for _, enemy in ipairs(enemies) do
            -- Use Cortex Command's wrapped scene distance.
            -- On horizontally wrapping maps, soldiers can be visually
            -- beside each other even when their raw X coordinates are
            -- near opposite ends of the scene.
            local distanceVector = SceneMan:ShortestDistance(
                candidate.Pos,
                enemy.Pos,
                SceneMan.SceneWrapsX
            );

            local distanceSquared =
                (distanceVector.X * distanceVector.X) +
                (distanceVector.Y * distanceVector.Y);

            if distanceSquared <= combatRadiusSquared then
                nearbyEnemies = nearbyEnemies + 1;
            end

            if distanceSquared < nearestEnemyDistance then
                nearestEnemyDistance = distanceSquared;
                nearestEnemy = enemy;
            end
        end

        if nearbyEnemies > bestEnemyCount
            or (
                nearbyEnemies == bestEnemyCount
                and nearestEnemyDistance < bestNearestDistance
            ) then

            bestEnemyCount = nearbyEnemies;
            bestNearestDistance = nearestEnemyDistance;

            followActor = candidate;
            closestEnemy = nearestEnemy;
        end
    end


    if followActor then

        self:SetObservationTarget(
            followActor.Pos,
            Activity.PLAYER_1
        );
    else
        self:SetObservationTarget(
            self.CameraPos,
            Activity.PLAYER_1
        );
    end


    if self.RoundOver then
        FrameMan:SetScreenText(
            self.RoundResultText ..
            " | SCORE " ..
            tostring(self.Team1Score) ..
            " - " ..
            tostring(self.Team2Score) ..
            " | NEXT ROUND...",
            self:ScreenOfPlayer(Activity.PLAYER_1),
            0,
            -1,
            false
        );

        if self.RoundEndTimer:IsPastSimMS(self.RoundEndDelay) then
            self:ClearRoundActors();
            self:SpawnRound();
        end

        return;
    end


    FrameMan:SetScreenText(
        "ROUND " .. tostring(self.RoundNumber) ..
        " | TEAM 1: " .. tostring(team1Alive) ..
        " | TEAM 2: " .. tostring(team2Alive) ..
        " | SCORE " ..
        tostring(self.Team1Score) ..
        " - " ..
        tostring(self.Team2Score),
        self:ScreenOfPlayer(Activity.PLAYER_1),
        0,
        -1,
        false
    );


    if not self.BattleStarted then
        if team1Alive > 0 and team2Alive > 0 then
            self.BattleStarted = true;

            print(
                "TurnBasedSkirmish: round " ..
                tostring(self.RoundNumber) ..
                " armed"
            );
        end

        return;
    end


    if team1Alive <= 0 and team2Alive > 0 then
        self:FinishRound(self.Team2);

    elseif team2Alive <= 0 and team1Alive > 0 then
        self:FinishRound(self.Team1);

    elseif team1Alive <= 0 and team2Alive <= 0 then
        self:FinishRound(Activity.NOTEAM);
    end
end


function TurnBasedSkirmish:PauseActivity(pause)
end


function TurnBasedSkirmish:EndActivity()
end
