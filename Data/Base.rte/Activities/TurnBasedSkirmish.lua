function TurnBasedSkirmish:StartActivity()
    print("TurnBasedSkirmish: StartActivity");

    self.PlayerTeam = Activity.TEAM_1;
    self.EnemyTeam = Activity.TEAM_2;
    self.ActiveTeam = self.PlayerTeam;
    self.TurnNumber = 1;

    self.Team1Actors = {};
    self.Team2Actors = {};

    local sceneWidth = SceneMan.SceneWidth;

    -- Spawn Team 1 on the left.
    for i = 1, 8 do
        local actor = CreateAHuman("Soldier Heavy", "Base.rte");

        if actor then
            actor.Team = self.PlayerTeam;

            local x = math.floor(sceneWidth * 0.20) + ((i - 1) * 25);
            actor.Pos = SceneMan:MovePointToGround(Vector(x, 0), 0, 0);

            actor.AIMode = Actor.AIMODE_SENTRY;

            MovableMan:AddActor(actor);
            table.insert(self.Team1Actors, actor);
        end
    end

    -- Spawn Team 2 on the right.
    for i = 1, 8 do
        local actor = CreateAHuman("Soldier Heavy", "Base.rte");

        if actor then
            actor.Team = self.EnemyTeam;

            local x = math.floor(sceneWidth * 0.80) - ((i - 1) * 25);
            actor.Pos = SceneMan:MovePointToGround(Vector(x, 0), 0, 0);

            actor.AIMode = Actor.AIMODE_SENTRY;

            MovableMan:AddActor(actor);
            table.insert(self.Team2Actors, actor);
        end
    end

    -- Give Player 1 control of the first Team 1 soldier.
    if #self.Team1Actors > 0 then
        local actor = self.Team1Actors[1];

        self:SetPlayerBrain(actor, Activity.PLAYER_1);
        self:SwitchToActor(actor, Activity.PLAYER_1, self.PlayerTeam);
        self:SetObservationTarget(actor.Pos, Activity.PLAYER_1);
    end
end


function TurnBasedSkirmish:UpdateActivity()

    local message = "TEAM 1 TURN  |  Turn " .. tostring(self.TurnNumber);

    if self.ActiveTeam == self.EnemyTeam then
        message = "TEAM 2 TURN  |  Turn " .. tostring(self.TurnNumber);
    end

    FrameMan:SetScreenText(
        message .. "  |  Press 1 to end turn",
        self:ScreenOfPlayer(Activity.PLAYER_1),
        0,
        -1,
        false
    );

    -- Temporary turn-switch key.
    if UInputMan:KeyPressed(Key.K_1) then

        if self.ActiveTeam == self.PlayerTeam then
            self.ActiveTeam = self.EnemyTeam;

            if #self.Team2Actors > 0 then
                local actor = self.Team2Actors[1];

                self:SetPlayerBrain(actor, Activity.PLAYER_1);
                self:SwitchToActor(actor, Activity.PLAYER_1, self.EnemyTeam);
                self:SetObservationTarget(actor.Pos, Activity.PLAYER_1);
            end

        else
            self.ActiveTeam = self.PlayerTeam;
            self.TurnNumber = self.TurnNumber + 1;

            if #self.Team1Actors > 0 then
                local actor = self.Team1Actors[1];

                self:SetPlayerBrain(actor, Activity.PLAYER_1);
                self:SwitchToActor(actor, Activity.PLAYER_1, self.PlayerTeam);
                self:SetObservationTarget(actor.Pos, Activity.PLAYER_1);
            end
        end
    end
end


function TurnBasedSkirmish:PauseActivity(pause)
end


function TurnBasedSkirmish:EndActivity()
    print("TurnBasedSkirmish: EndActivity");
end
