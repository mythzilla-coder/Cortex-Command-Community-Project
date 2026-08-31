function TurnBasedSkirmish:StartActivity()
    self.RoundOver = false;
    self.BattleStarted = false;
    print("TurnBasedSkirmish: AI vs AI spectator");

    self.Team1 = Activity.TEAM_1;
    self.Team2 = Activity.TEAM_2;
    self.SpectatorTeam = Activity.TEAM_3;

    self:SetPlayerBrain(nil, Activity.PLAYER_1);
    self:SetTeamOfPlayer(Activity.PLAYER_1, self.SpectatorTeam);

-- Critical: observation targets only drive the camera while
-- the player is actually in OBSERVE view state.
self:SetViewState(Activity.OBSERVE, Activity.PLAYER_1);

    self.CameraPos = Vector(
        SceneMan.SceneWidth * 0.5,
        SceneMan.SceneHeight * 0.45
    );

    self.Team1Actors = {};
    self.Team2Actors = {};

    local sceneWidth = SceneMan.SceneWidth;

    for i = 1, 8 do
        local actor = CreateAHuman("Soldier Heavy", "Base.rte");

        if actor then
            actor.Team = self.Team1;

            local x = math.floor(sceneWidth * 0.20) + ((i - 1) * 25);
            actor.Pos = SceneMan:MovePointToGround(Vector(x, 0), 0, 0);

            actor.AIMode = Actor.AIMODE_GOTO;
            local weapon = CreateHDFirearm("Coalition/Assault Rifle");
            if weapon then
                actor:AddInventoryItem(weapon);
            end

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

            actor.AIMode = Actor.AIMODE_GOTO;
            local weapon = CreateHDFirearm("Coalition/Assault Rifle");
            if weapon then
                actor:AddInventoryItem(weapon);
            end

            MovableMan:AddActor(actor);
            table.insert(self.Team2Actors, actor);
        end
    end

    -- Initial orders: each team advances toward the other side.
    for _, actor in ipairs(self.Team1Actors) do
        actor:ClearAIWaypoints();
        actor:AddAISceneWaypoint(
            Vector(sceneWidth * 0.70, actor.Pos.Y)
        );
        actor.AIMode = Actor.AIMODE_GOTO;
    end

    for _, actor in ipairs(self.Team2Actors) do
        actor:ClearAIWaypoints();
        actor:AddAISceneWaypoint(
            Vector(sceneWidth * 0.30, actor.Pos.Y)
        );
        actor.AIMode = Actor.AIMODE_GOTO;
    end

    self:SetObservationTarget(self.CameraPos, Activity.PLAYER_1);
end


function TurnBasedSkirmish:UpdateActivity()

    local team1Alive = 0;
    local team2Alive = 0;
    local followActor = nil;

    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 then
            team1Alive = team1Alive + 1;

            if not followActor then
                followActor = actor;
            end

        elseif actor.Team == self.Team2 then
            team2Alive = team2Alive + 1;
        end
    end

    -- Follow a real Team 1 soldier so the camera cannot point at empty space.
    if followActor then
        self:SetObservationTarget(
            followActor.Pos,
            Activity.PLAYER_1
        );
    end

    FrameMan:SetScreenText(
        "AI BATTLE | TEAM 1: " .. tostring(team1Alive) ..
        " | TEAM 2: " .. tostring(team2Alive) ..
        " | FOLLOWING SOLDIER",
        self:ScreenOfPlayer(Activity.PLAYER_1),
        0,
        -1,
        false
    );
    -- Arm elimination only after both armies have actually appeared.
    if not self.BattleStarted then
        if team1Alive > 0 and team2Alive > 0 then
            self.BattleStarted = true;
            print("TurnBasedSkirmish: battle armed");
        end

    elseif not self.RoundOver then
        if team1Alive <= 0 and team2Alive > 0 then
            self.RoundOver = true;
            self.WinnerTeam = self.Team2;
            self:SetTeamOfPlayer(Activity.PLAYER_1, self.Team2);
            self.ActivityState = Activity.OVER;

        elseif team2Alive <= 0 and team1Alive > 0 then
            self.RoundOver = true;
            self.WinnerTeam = self.Team1;
            self:SetTeamOfPlayer(Activity.PLAYER_1, self.Team1);
            self.ActivityState = Activity.OVER;

        elseif team1Alive <= 0 and team2Alive <= 0 then
            self.RoundOver = true;
            self.WinnerTeam = Activity.NOTEAM;
            self.ActivityState = Activity.OVER;
        end
    end
end
function TurnBasedSkirmish:PauseActivity(pause)
end


function TurnBasedSkirmish:EndActivity()
end











