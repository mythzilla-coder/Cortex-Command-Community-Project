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

    local followActor = nil;
    local bestDistance = math.huge;
    local sceneCenter = Vector(
        SceneMan.SceneWidth * 0.5,
        SceneMan.SceneHeight * 0.5
    );

    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 then
            team1Alive = team1Alive + 1;

        elseif actor.Team == self.Team2 then
            team2Alive = team2Alive + 1;
        end

        if actor.Team == self.Team1 or actor.Team == self.Team2 then
            local distance = SceneMan:ShortestDistance(
                actor.Pos,
                sceneCenter,
                SceneMan.SceneWrapsX
            ).Magnitude;

            if distance < bestDistance then
                bestDistance = distance;
                followActor = actor;
            end
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
