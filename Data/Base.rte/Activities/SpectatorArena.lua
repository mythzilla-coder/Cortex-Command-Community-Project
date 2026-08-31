function SpectatorArena:CreateFactionSoldier(factionName)
    local moduleID = PresetMan:GetModuleID(factionName);

    local actorGroups = {
        "Actors",
        "Actors - Light",
        "Actors - Heavy"
    };

    local actor = nil;

    -- Try several random infantry classes, but only accept an actor
    -- actually belonging to the selected faction.
    for attempt = 1, 20 do
        local group =
            actorGroups[math.random(1, #actorGroups)];

        local candidate =
            RandomAHuman(group, factionName);

        if candidate then
            if candidate.ModuleID == moduleID then
                actor = candidate;
                break;
            else
                DeleteEntity(candidate);
            end
        end
    end

    -- Conservative fallback within the same faction.
    if not actor then
        for attempt = 1, 20 do
            local candidate =
                RandomAHuman("Actors", factionName);

            if candidate then
                if candidate.ModuleID == moduleID then
                    actor = candidate;
                    break;
                else
                    DeleteEntity(candidate);
                end
            end
        end
    end

    if not actor then
        return nil;
    end


    local weaponGroups = {
        "Weapons - Primary",
        "Weapons - Light",
        "Weapons - Heavy",
        "Weapons - Sniper",
        "Weapons - Secondary"
    };

    local weapon = nil;

    -- Give every soldier one random firearm from its own faction.
    for attempt = 1, 30 do
        local group =
            weaponGroups[math.random(1, #weaponGroups)];

        local candidate =
            RandomHDFirearm(group, factionName);

        if candidate then
            if candidate.ModuleID == moduleID then
                weapon = candidate;
                break;
            else
                DeleteEntity(candidate);
            end
        end
    end

    if weapon then
        actor:AddInventoryItem(weapon);
    end

    return actor;
end


function SpectatorArena:SpawnRound()
    self:TransitionState("SPAWN_TEAMS");
    self.RoundOver = false;
    self.BattleStarted = false;
    self.RoundResultText = "";
    self.SpawnGraceTimer:Reset();

    self.RoundNumber = self.RoundNumber + 1;

    self.FactionPool = {
        "Coalition.rte",
        "Ronin.rte",
        "Dummy.rte",
        "Imperatus.rte",
        "Techion.rte",
        "Browncoats.rte"
    };

    self.Team1Faction =
        self.FactionPool[
            math.random(1, #self.FactionPool)
        ];

    repeat
        self.Team2Faction =
            self.FactionPool[
                math.random(1, #self.FactionPool)
            ];
    until self.Team2Faction ~= self.Team1Faction;


    local team1X =
        SceneMan.SceneWidth * 0.20;

    local team2X =
        SceneMan.SceneWidth * 0.80;


    for i = 1, 8 do
        local actor =
            self:CreateFactionSoldier(
                self.Team1Faction
            );

        if actor then
            actor.Team = self.Team1;

            actor.Pos = Vector(
                team1X + ((i - 1) * 18),
                50
            );

            actor:AddAISceneWaypoint(
                Vector(
                    SceneMan.SceneWidth * 0.80,
                    SceneMan.SceneHeight * 0.50
                )
            );

            actor.AIMode = Actor.AIMODE_GOTO;

            MovableMan:AddActor(actor);
        end
    end


    for i = 1, 8 do
        local actor =
            self:CreateFactionSoldier(
                self.Team2Faction
            );

        if actor then
            actor.Team = self.Team2;

            actor.Pos = Vector(
                team2X - ((i - 1) * 18),
                50
            );

            actor:AddAISceneWaypoint(
                Vector(
                    SceneMan.SceneWidth * 0.20,
                    SceneMan.SceneHeight * 0.50
                )
            );

            actor.AIMode = Actor.AIMODE_GOTO;

            MovableMan:AddActor(actor);
        end
    end


    print(
        "SpectatorArena: round " ..
        tostring(self.RoundNumber) ..
        " | " ..
        self.Team1Faction ..
        " vs " ..
        self.Team2Faction
    );
end

function SpectatorArena:ClearRoundActors()
    local actorsToRemove = {};

    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 or actor.Team == self.Team2 then
            table.insert(actorsToRemove, actor);
        end
    end

    for _, actor in ipairs(actorsToRemove) do
        if MovableMan:IsActor(actor) then
            -- Round-reset cleanup only.
        -- Surviving combatants disappear without creating artificial
        -- gibs. Real battle gore, limbs, dropped equipment and terrain
        -- destruction remain in the scene.
        local removedActor = MovableMan:RemoveActor(actor);

        if removedActor then
            DeleteEntity(removedActor);
        end
        end
    end
end


function SpectatorArena:FinishRound(winner)
    if self.RoundOver then
        return;
    end

    self.RoundOver = true;
    self.WinnerTeam = winner;
    self.RoundEndTimer:Reset();
    self:TransitionState("ROUND_RESULT");

    if winner == self.Team1 then
        self.Team1Score = self.Team1Score + 1;
        self.RoundResultText = string.upper(string.gsub(self.Team1Faction or "TEAM 1", "%.rte$", "")) .. " WINS";

    elseif winner == self.Team2 then
        self.Team2Score = self.Team2Score + 1;
        self.RoundResultText = string.upper(string.gsub(self.Team2Faction or "TEAM 2", "%.rte$", "")) .. " WINS";

    else
        self.RoundResultText = "DRAW";
    end

    print(
        "SpectatorArena: round " ..
        tostring(self.RoundNumber) ..
        " finished - " ..
        self.RoundResultText
    );
end


function SpectatorArena:TransitionState(nextState)
    if self.State ~= nextState then
        self.State = nextState;
        print("SpectatorArena: " .. nextState .. " " .. tostring(self.RoundNumber));
    end
end


function SpectatorArena:ResolveWatchdog(team1Alive, team2Alive)
    print("SpectatorArena: WATCHDOG_TIMEOUT");

    if team1Alive > team2Alive then
        print("SpectatorArena: WATCHDOG_RESULT TEAM_1");
        self:FinishRound(self.Team1);
    elseif team2Alive > team1Alive then
        print("SpectatorArena: WATCHDOG_RESULT TEAM_2");
        self:FinishRound(self.Team2);
    else
        print("SpectatorArena: WATCHDOG_RESULT DRAW");
        self:FinishRound(Activity.NOTEAM);
    end
end


function SpectatorArena:StartActivity()
    print("SpectatorArena: autonomous AI vs AI spectator");

    self.Team1 = Activity.TEAM_1;
    self.Team2 = Activity.TEAM_2;
    self.SpectatorTeam = Activity.TEAM_3;

    self.Team1Score = 0;
    self.Team2Score = 0;
    self.RoundNumber = 0;

    self.State = "BOOT";
    self.MaxRoundDurationMS = 300000;
    self.RoundOver = false;
    self.BattleStarted = false;
    self.RoundResultText = "";

    self.RoundEndDelay = 3000;
    self.RoundEndTimer = Timer();
    self.RoundTimer = Timer();
    self.SpawnGraceDelayMS = 5000;
    self.SpawnGraceTimer = Timer();

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

    self:TransitionState("PREPARE_ROUND");
    self:SpawnRound();
end


function SpectatorArena:UpdateActivity()
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
            self:TransitionState("ROUND_RESET");
            self:ClearRoundActors();
            self:TransitionState("PREPARE_ROUND");
            self:SpawnRound();
        end

        return;
    end


    local team1FactionName =
        string.gsub(self.Team1Faction or "TEAM 1", "%.rte$", "");

    local team2FactionName =
        string.gsub(self.Team2Faction or "TEAM 2", "%.rte$", "");

    FrameMan:SetScreenText(
        "ROUND " .. tostring(self.RoundNumber) ..
        " | " .. string.upper(team1FactionName) ..
        " " .. tostring(team1Alive) ..
        " vs " ..
        string.upper(team2FactionName) ..
        " " .. tostring(team2Alive) ..
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
        if self.SpawnGraceTimer:IsPastSimMS(self.SpawnGraceDelayMS) then
            if team1Alive <= 0 and team2Alive <= 0 then
                self:FinishRound(Activity.NOTEAM);
                return;
            elseif team1Alive <= 0 then
                self:FinishRound(self.Team2);
                return;
            elseif team2Alive <= 0 then
                self:FinishRound(self.Team1);
                return;
            end
        end

        if team1Alive > 0 and team2Alive > 0 then
            self.BattleStarted = true;

            self:TransitionState("BATTLE");
            self.RoundTimer:Reset();
            print(
                "SpectatorArena: BATTLE_STARTED " ..
                tostring(self.RoundNumber) ..
                " armed"
            );
        end

        return;
    end

    if self.RoundTimer:IsPastSimMS(self.MaxRoundDurationMS) then
        self:ResolveWatchdog(team1Alive, team2Alive);
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


function SpectatorArena:PauseActivity(pause)
end


function SpectatorArena:EndActivity()
end
