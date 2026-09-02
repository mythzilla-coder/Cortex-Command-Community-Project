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
    self.RoundElapsedTimer:Reset();

    self.AISpawnSettleTimer:Reset();
    self.AISpawnSettled = false;
    self.AIReleasedActors = {};
    self.AIDistributedTargetTimer:Reset();
    -- Actor UniqueIDs and routes belong only to this round.
    self.AIPursuitTargets = {};
    self.AIPursuitProgress = {};
    self.AIRetargetTimer:Reset();

    self.AICombatPressureTimer:Reset();
    self.AIPreviousTeam1Alive = nil;
    self.AIPreviousTeam2Alive = nil;

    self:ResetCameraDirector();

    self.RoundNumber = self.RoundNumber + 1;
    self.AIController:BeginRound(self.RoundNumber, nil);

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

    self.Telemetry.Emit("ROUND_START", {
        round = self.RoundNumber,
        team1 = self.Team1Faction,
        team2 = self.Team2Faction
    });


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

            -- V8: recovered Spectator Mod dependency.
            -- BRAINHUNT's BrainSearch requires enemy actors
            -- exposed through the "Brains" group.
            actor:AddToGroup("Brains");

            actor.Pos = Vector(
                team1X + ((i - 1) * 18),
                50
            );

            -- V7 baseline based on recovered Spectator Mod:
            -- offensive actors start directly in native hunt mode.
            actor.AIMode = Actor.AIMODE_SENTRY;

            MovableMan:AddActor(actor);
            self.AIController:RegisterActor(actor.UniqueID, self.Team1, i);
        end
    end


    for i = 1, 8 do
        local actor =
            self:CreateFactionSoldier(
                self.Team2Faction
            );

        if actor then
            actor.Team = self.Team2;

            -- V8: make this combatant a valid enemy
            -- target for native BRAINHUNT BrainSearch.
            actor:AddToGroup("Brains");

            actor.Pos = Vector(
                team2X - ((i - 1) * 18),
                50
            );

            -- V7 baseline based on recovered Spectator Mod:
            -- offensive actors start directly in native hunt mode.
            actor.AIMode = Actor.AIMODE_SENTRY;

            MovableMan:AddActor(actor);
            self.AIController:RegisterActor(actor.UniqueID, self.Team2, i);
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

function SpectatorArena:AssignDistributedMovingTargets(
    actors,
    enemies,
    forceRefresh
)
    local livingActors = {};
    local livingEnemies = {};

    for _, actor in ipairs(actors) do
        if MovableMan:IsActor(actor)
            and not actor:IsDead()
            and (
                not self.AITouchdownGateActive
                or (
                    self.AIReleasedActors
                    and self.AIReleasedActors[actor.UniqueID]
                )
            )
        then
            table.insert(livingActors, actor);
        end
    end

    for _, enemy in ipairs(enemies) do
        if MovableMan:IsActor(enemy) and not enemy:IsDead() then
            table.insert(livingEnemies, enemy);
        end
    end

    if #livingEnemies == 0 then
        return;
    end

    -- Stable spatial ordering helps spread nearby soldiers across
    -- different enemy targets instead of having all actors select
    -- the same easiest BrainSearch destination.
    table.sort(
        livingActors,
        function(a, b)
            return a.Pos.X < b.Pos.X;
        end
    );

    table.sort(
        livingEnemies,
        function(a, b)
            return a.Pos.X < b.Pos.X;
        end
    );

    for index, actor in ipairs(livingActors) do
        local currentTarget = actor.MOMoveTarget;

        local targetInvalid =
            not currentTarget
            or not MovableMan:IsActor(currentTarget)
            or currentTarget.Team == actor.Team;

        if forceRefresh or targetInvalid then
            local enemyIndex =
                ((index - 1) % #livingEnemies) + 1;

            local target =
                livingEnemies[enemyIndex];

            actor:ClearAIWaypoints();
            actor:AddAIMOWaypoint(target);
            actor.AIMode = Actor.AIMODE_GOTO;

            print(
                "SpectatorArena: AI_DISTRIBUTED_TARGET actor="
                .. tostring(actor.UniqueID)
                .. " target="
                .. tostring(target.UniqueID)
            );
        end
    end
end


function SpectatorArena:UpdateDistributedMovingTargets(
    team1Actors,
    team2Actors
)
    if self.State ~= "BATTLE" then
        return;
    end

    if not self.AIDistributedTargetTimer:IsPastSimMS(
        self.AIDistributedTargetRefreshMS
    ) then
        return;
    end

    self.AIDistributedTargetTimer:Reset();

    self:AssignDistributedMovingTargets(
        team1Actors,
        team2Actors,
        false
    );

    self:AssignDistributedMovingTargets(
        team2Actors,
        team1Actors,
        false
    );
end

function SpectatorArena:UpdateSpawnSettle(team1Actors, team2Actors)
    if self.AISpawnSettled then
        return;
    end

    local function releaseLandedActors(
        arena,
        actors,
        enemies
    )
        local newlyReleased = false;

        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
                and not arena.AIReleasedActors[actor.UniqueID]
            then
                -- Probe from actor center toward the feet.
                -- Ground contact should put terrain within roughly
                -- half an actor-height below the center.
                local probeDistance =
                    math.max(
                        18,
                        actor.Height * 0.70
                    );

                local groundDistance =
                    SceneMan:CastObstacleRay(
                        actor.Pos,
                        Vector(0, probeDistance),
                        Vector(),
                        Vector(),
                        actor.ID,
                        actor.IgnoresWhichTeam,
                        rte.grassID,
                        3
                    );

                -- Require both terrain under the actor and a mostly
                -- settled vertical velocity.
                local touchedGround =
                    groundDistance >= 0
                    and math.abs(actor.Vel.Y) <= 3;

                if touchedGround then
                    arena.AIReleasedActors[actor.UniqueID] =
                        true;
                    arena.AIController:ReleaseActor(
                        actor.UniqueID,
                        arena.RoundElapsedTimer.ElapsedSimTimeMS
                    );

                    newlyReleased = true;

                    print(
                        "SpectatorArena: AI_TOUCHDOWN_RELEASE actor="
                        .. tostring(actor.UniqueID)
                        .. " velY="
                        .. tostring(actor.Vel.Y)
                        .. " groundDistance="
                        .. tostring(groundDistance)
                    );
                else
                    -- Absolutely no pursuit before first touchdown.
                    actor:ClearAIWaypoints();
                    actor.AIMode = Actor.AIMODE_SENTRY;
                end
            end
        end

        -- Whenever another actor touches down, redistribute all
        -- currently released teammates together. This preserves
        -- the touchdown gate while avoiding the one-actor target
        -- assignment that made early landers converge on one enemy.
        if newlyReleased then
            local releasedActors = {};

            for _, actor in ipairs(actors) do
                if MovableMan:IsActor(actor)
                    and not actor:IsDead()
                    and arena.AIReleasedActors[actor.UniqueID]
                then
                    table.insert(
                        releasedActors,
                        actor
                    );
                end
            end

            arena:AssignDistributedMovingTargets(
                releasedActors,
                enemies,
                true
            );

            print(
                "SpectatorArena: AI_TOUCHDOWN_REDISTRIBUTE count="
                .. tostring(#releasedActors)
            );
        end
    end

    releaseLandedActors(
        self,
        team1Actors,
        team2Actors
    );

    releaseLandedActors(
        self,
        team2Actors,
        team1Actors
    );

    local livingActorCount = 0;
    local releasedActorCount = 0;

    local function countTeam(arena, actors)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
            then
                livingActorCount =
                    livingActorCount + 1;

                if arena.AIReleasedActors[actor.UniqueID] then
                    releasedActorCount =
                        releasedActorCount + 1;
                end
            end
        end
    end

    countTeam(self, team1Actors);
    countTeam(self, team2Actors);

    if livingActorCount > 0
        and releasedActorCount == livingActorCount
    then
        self.AISpawnSettled = true;
        self.AIDistributedTargetTimer:Reset();

        print(
            "SpectatorArena: AI_TOUCHDOWN_ALL_RELEASED"
            .. " living="
            .. tostring(livingActorCount)
        );
    end
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
    self.Telemetry.Emit("ROUND_RESULT", {
        round = self.RoundNumber,
        winner = self.RoundResultText,
        durationMS = self.RoundElapsedTimer.ElapsedSimTimeMS,
        team1Score = self.Team1Score,
        team2Score = self.Team2Score
    });
    if self.AI_V2_MODE == "SHADOW" then
        local aiSnapshot = self.AIController:Snapshot();
        self.Telemetry.Emit("AI_SHADOW_ROUND_SUMMARY", {
            round = self.RoundNumber,
            observations = aiSnapshot.ShadowObservations,
            losChecks = aiSnapshot.LOSChecks,
            losPositive = aiSnapshot.LOSPositive,
            fireEvents = aiSnapshot.FireEvents,
            damageEvents = aiSnapshot.DamageEvents,
            visibleOpponents = aiSnapshot.VisibleOpponents,
            visibleOpponentChecks = aiSnapshot.VisibleOpponentChecks,
            losProbeRays = aiSnapshot.LOSProbeRays,
            actorSkips = aiSnapshot.ActorSkips,
            contactAcquisitions = aiSnapshot.ContactAcquisitions,
            contactLosses = aiSnapshot.ContactLosses,
            shadowObservationTimeMS = aiSnapshot.ShadowObservationTimeMS
        });
    end
    self.Telemetry.Snapshot();
end


function SpectatorArena:TransitionState(nextState)
    if self.State ~= nextState then
        self.State = nextState;
        self.Telemetry.Emit("STATE", { round = self.RoundNumber, state = nextState });
        print("SpectatorArena: " .. nextState .. " " .. tostring(self.RoundNumber));
    end
end


function SpectatorArena:ResolveWatchdog(team1Alive, team2Alive)
    print("SpectatorArena: WATCHDOG_TIMEOUT");
    self.Telemetry.Emit("WATCHDOG", {
        round = self.RoundNumber,
        team1Alive = team1Alive,
        team2Alive = team2Alive,
        reason = "timeout"
    });

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
    self.Telemetry = require("Activities/SpectatorTelemetry");
    self.Telemetry.ConfigureRuntime("SPECTATOR_EVENT_LOG.txt");
    self.Telemetry.Emit("ACTIVITY_START", {});
    self.AI_V2_MODE = "OFF";
    self.AIController = require("Activities/SpectatorAIController").Create({
        mode = self.AI_V2_MODE,
        positionHistoryLimit = 4
    });
    self.Telemetry.Emit("AI_V2_CONFIG", {
        version = "2",
        mode = self.AI_V2_MODE
    });

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
    self.RoundElapsedTimer = Timer();
    -- Spectator Arena always runs at the engine-supported maximum.
    -- These reproduce the maximum values exposed by the old setup menu:
    -- Difficulty 100 / AI Skill "Unfair" 100.
    self.Difficulty = Activity.MAXDIFFICULTY;
    self:SetTeamAISkill(self.Team1, Activity.UNFAIRSKILL);
    self:SetTeamAISkill(self.Team2, Activity.UNFAIRSKILL);

    print(
        "SpectatorArena: AI_CONFIG difficulty="
        .. tostring(self.Difficulty)
        .. " team1Skill="
        .. tostring(self:GetTeamAISkill(self.Team1))
        .. " team2Skill="
        .. tostring(self:GetTeamAISkill(self.Team2))
    );
    -- Force absolute maximum AI settings for Spectator Arena.

    self.SpawnGraceDelayMS = 5000;
    self.SpawnGraceTimer = Timer();

    -- V9: let freshly spawned actors land before aggressive hunting.
    self.AISpawnSettleDelayMS = 1500;
    self.AISpawnSettleTimer = Timer();
    self.AISpawnSettled = false;
    self.AITouchdownGateActive = true;
    self.AIReleasedActors = {};
    self.AIInstrumentationTimer = Timer();
    self.AIInstrumentationIntervalMS = 500;

    -- V10 distributed moving-target experiment.
    self.AIDistributedTargetTimer = Timer();
    self.AIDistributedTargetRefreshMS = 2000;

    -- TEMPORARY dynamic-pursuit experiment.
    self.AIRetargetIntervalMS = 6000;
    self.AIRetargetTimer = Timer();
    self.AIPursuitTargets = {};
    self.AIPursuitProgress = {};

    -- Anti-stall thresholds.
    -- Two bad 6-second samples = roughly 12 seconds without progress.
    self.AIStallDistanceThreshold = 24;
    self.AIStallSamplesBeforeRepath = 2;
    self.AIStallRepathEnemyDistance = 320;

    -- V5 global combat-pressure controller.
    -- Prevent long spectator dead periods even when individual AI
    -- technically considers its current state/path valid.
    self.AICombatPressureTimer = Timer();
    self.AICombatPressureNormalMS = 12000;
    self.AICombatPressureLowSurvivorMS = 6000;
    self.AICombatPressureCriticalMS = 4000;
    self.AICombatActivityRange = 800;
    self.AIPreviousTeam1Alive = nil;
    self.AIPreviousTeam2Alive = nil;
    self.CameraEvaluationIntervalMS = 250;
    self.CameraMinimumHoldMS = 1500;
    self.CameraSwitchThreshold = 1.25;
    self.CameraSoldierMinimumHoldMS = 750;
    self.CameraPOIMinimumHoldMS = 2500;
    self.CameraPOIMaximumHoldMS = 3000;
    self.CameraPOISwitchThreshold = 1.35;
    self.CameraPOICooldownMS = 3500;
    self.CameraRecentFireWindowMS = 400;
    self.CameraEventHoldMS = 2000;
    self.CameraEventCooldownMS = 4000;
    self.CameraEventMinimumAimDot = 0.85;
    self.CameraEventMinimumDistance = 180;
    self.CameraEventMaximumRange = 1200;

    -- TEMPORARY RAW CAMERA DIAGNOSTIC.
    -- Bypasses normal timing/cooldown policy so selector behavior can be observed.
    self.CameraRawDiagnosticMode = false;
    self.CameraRawLastTargetType = nil;
    self.CameraRawLastActorID = nil;
    self.CameraRawLastEnemyID = nil;
    self.CameraRawNextIdleTeam = 1;
    self.CameraRawCurrentIdleTeam = nil;

    self.CameraEvaluationTimer = Timer();
    self.CameraHoldTimer = Timer();
    self.CameraModeTimer = Timer();
    self.CameraPOICooldownTimer = Timer();
    self.CameraRecentFireTimer = Timer();
    self.CameraEventCooldownTimer = Timer();
    self.CameraPOICooldownReady = true;
    self.CameraEventCooldownReady = true;
    self.CameraMode = "CAMERA_CENTER";
    self.CameraFollowActor = nil;
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraEventLogic = require("Activities/SpectatorCameraEventLogic");
    self.CameraLastShot = nil;
    self.CameraTrackedActors = {};
    self.CameraHandledVictims = {};
    self.CameraEventPosition = nil;
    self.CameraFocusPosition = self.CameraPos;
    self.CameraFocusScore = 0;
    self.CameraFocusActor = nil;
    self.CameraHasFocus = false;

    self:SetPlayerBrain(nil, Activity.PLAYER_1);
    self:SetTeamOfPlayer(Activity.PLAYER_1, self.SpectatorTeam);
    self:SetViewState(Activity.OBSERVE, Activity.PLAYER_1);

    self.CameraPos = Vector(
        SceneMan.SceneWidth * 0.5,
        SceneMan.SceneHeight * 0.45
    );

    self:ResetCameraDirector();

    self:SetObservationTarget(
        self.CameraPos,
        Activity.PLAYER_1
    );

    self:TransitionState("PREPARE_ROUND");
    self:SpawnRound();
end


function SpectatorArena:FindBestCombatFocus(team1Actors, team2Actors)
    local combatRadius = 260;
    local combatRadiusSquared = combatRadius * combatRadius;
    local bestScore = -1;
    local bestPosition = nil;
    local bestActor = nil;
    local bestEnemy = nil;

    local function considerCandidates(candidates, enemies)
        for _, candidate in ipairs(candidates) do
            local nearbyEnemies = 0;
            local nearestEnemyDistance = math.huge;
            local nearestEnemy = nil;

            for _, enemy in ipairs(enemies) do
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

            if nearestEnemy then
                local score = nearbyEnemies * 1000;

                -- Distance remains useful, but should not dominate actual combat activity.
                local proximity =
                    math.max(0, combatRadiusSquared - nearestEnemyDistance)
                    / combatRadiusSquared;

                score = score + (proximity * 250);

                -- RAW ACTION-AWARE CAMERA TEST:
                -- firing should outweigh passive actor density.
                local candidateFiring = false;
                local enemyFiring = false;

                local candidateItem = candidate.EquippedItem;
                if candidateItem and IsHDFirearm(candidateItem) then
                    candidateFiring = ToHDFirearm(candidateItem).FiredFrame;
                end

                local enemyItem = nearestEnemy.EquippedItem;
                if enemyItem and IsHDFirearm(enemyItem) then
                    enemyFiring = ToHDFirearm(enemyItem).FiredFrame;
                end

                if candidateFiring then
                    score = score + 5000;
                end

                if enemyFiring then
                    score = score + 5000;
                end

                -- Two actors actively exchanging fire should be overwhelmingly preferred.
                if candidateFiring and enemyFiring then
                    score = score + 5000;
                end

                -- Preserve last-survivor importance.
                if #candidates == 1 then
                    score = score + 750;
                end

                if score > bestScore then
                    bestScore = score;
                    bestActor = candidate;
                    bestEnemy = nearestEnemy;
                end
            end
        end
    end

    considerCandidates(team1Actors, team2Actors);
    considerCandidates(team2Actors, team1Actors);

    if bestActor and bestEnemy then
        local distance = SceneMan:ShortestDistance(
            bestActor.Pos,
            bestEnemy.Pos,
            SceneMan.SceneWrapsX
        );
        bestPosition = bestActor.Pos + (distance * 0.5);
    elseif team1Actors[1] then
        bestScore = 0;
        bestActor = team1Actors[1];
        bestPosition = bestActor.Pos;
    elseif team2Actors[1] then
        bestScore = 0;
        bestActor = team2Actors[1];
        bestPosition = bestActor.Pos;
    end

    return bestPosition, bestScore, bestActor, bestEnemy;
end


function SpectatorArena:FindNearestDirectEnemy(actor, enemies)
    local bestEnemy = nil;
    local bestDistanceSquared = math.huge;

    for _, enemy in ipairs(enemies) do
        if MovableMan:IsActor(enemy) and not enemy:IsDead() then
            -- Deliberately direct/non-wrapped distance.
            -- Ketanot Hills wraps horizontally, but spectator combat
            -- should prefer the physically nearby opponent on screen.
            local dx = enemy.Pos.X - actor.Pos.X;
            local dy = enemy.Pos.Y - actor.Pos.Y;
            local distanceSquared = (dx * dx) + (dy * dy);

            if distanceSquared < bestDistanceSquared then
                bestDistanceSquared = distanceSquared;
                bestEnemy = enemy;
            end
        end
    end

    return bestEnemy, bestDistanceSquared;
end


function SpectatorArena:UpdateDynamicPursuit(team1Actors, team2Actors)
    if self.State ~= "BATTLE" then
        return;
    end

    if not self.AIRetargetTimer:IsPastSimMS(self.AIRetargetIntervalMS) then
        return;
    end

    self.AIRetargetTimer:Reset();

    -- V4: detect whether actors are actually making progress
    -- toward enemies instead of merely moving/shuffling.
    local requiredProgress = 32;

    local function retargetTeam(actors, enemies)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor) and not actor:IsDead() then
                local enemy, enemyDistanceSquared =
                    self:FindNearestDirectEnemy(actor, enemies);

                if enemy then
                    local actorID = actor.UniqueID;
                    local enemyID = enemy.UniqueID;
                    local enemyDistance =
                        math.sqrt(enemyDistanceSquared);

                    local previousTargetID =
                        self.AIPursuitTargets[actorID];

                    local progress =
                        self.AIPursuitProgress[actorID];

                    local targetChanged =
                        previousTargetID ~= enemyID;

                    if targetChanged or not progress then
                        progress = {
                            TargetID = enemyID,
                            LastDistance = enemyDistance,
                            StalledSamples = 0
                        };

                        self.AIPursuitProgress[actorID] = progress;
                    else
                        local distanceImprovement =
                            progress.LastDistance - enemyDistance;

                        if distanceImprovement < requiredProgress then
                            progress.StalledSamples =
                                progress.StalledSamples + 1;
                        else
                            progress.StalledSamples = 0;
                        end

                        progress.LastDistance = enemyDistance;
                    end

                    local stalled =
                        progress.StalledSamples
                            >= self.AIStallSamplesBeforeRepath;

                    if targetChanged or stalled then
                        local destination =
                            SceneMan:MovePointToGround(
                                Vector(enemy.Pos.X, enemy.Pos.Y),
                                actor.Height * 0.5,
                                4
                            );

                        actor:ClearAIWaypoints();
                        actor:AddAISceneWaypoint(destination);
                        actor.AIMode = Actor.AIMODE_GOTO;
                        actor:UpdateMovePath();

                        self.AIPursuitTargets[actorID] = enemyID;

                        if stalled then
                            print(
                                "SpectatorArena: AI_STALL_REPATH actor="
                                .. tostring(actorID)
                                .. " target="
                                .. tostring(enemyID)
                                .. " distance="
                                .. tostring(math.floor(enemyDistance))
                                .. " no_progress"
                            );
                        end

                        progress.TargetID = enemyID;
                        progress.LastDistance = enemyDistance;
                        progress.StalledSamples = 0;
                    end
                end
            end
        end
    end

    retargetTeam(team1Actors, team2Actors);
    retargetTeam(team2Actors, team1Actors);
end

function SpectatorArena:ForceCombatPressurePursuit(actors, enemies)
    self:AssignDistributedMovingTargets(
        actors,
        enemies,
        true
    );

    print(
        "SpectatorArena: AI_DISTRIBUTED_PRESSURE_REFRESH"
    );
end

function SpectatorArena:HasMeaningfulCombatFire(team1Actors, team2Actors)
    local activityRangeSquared =
        self.AICombatActivityRange * self.AICombatActivityRange;

    local function teamHasCombatFire(actors, enemies)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor) and not actor:IsDead() then
                local item = actor.EquippedItem;

                if item and IsHDFirearm(item) then
                    local firearm = ToHDFirearm(item);

                    if firearm.FiredFrame then
                        local enemy, enemyDistanceSquared =
                            self:FindNearestDirectEnemy(actor, enemies);

                        if enemy
                            and enemyDistanceSquared
                                <= activityRangeSquared then
                            return true;
                        end
                    end
                end
            end
        end

        return false;
    end

    return
        teamHasCombatFire(team1Actors, team2Actors)
        or teamHasCombatFire(team2Actors, team1Actors);
end


function SpectatorArena:UpdateCombatPressure(
    team1Actors,
    team2Actors,
    team1Alive,
    team2Alive
)
    if self.State ~= "BATTLE" then
        return;
    end

    local totalAlive = team1Alive + team2Alive;

    if totalAlive <= 1 then
        return;
    end

    -- V6: only an actual casualty counts as meaningful
    -- round progress. Gunfire alone no longer suppresses
    -- anti-stall pressure, because actors elsewhere may fire
    -- while other survivors remain parked indefinitely.
    local aliveCountChanged =
        self.AIPreviousTeam1Alive ~= nil
        and (
            team1Alive ~= self.AIPreviousTeam1Alive
            or team2Alive ~= self.AIPreviousTeam2Alive
        );

    self.AIPreviousTeam1Alive = team1Alive;
    self.AIPreviousTeam2Alive = team2Alive;

    if aliveCountChanged then
        self.AICombatPressureTimer:Reset();

        print(
            "SpectatorArena: AI_COMBAT_PROGRESS"
            .. " team1="
            .. tostring(team1Alive)
            .. " team2="
            .. tostring(team2Alive)
        );

        return;
    end

    local pressureThresholdMS =
        self.AICombatPressureNormalMS;

    if totalAlive <= 3 then
        pressureThresholdMS =
            self.AICombatPressureCriticalMS;
    elseif totalAlive <= 4 then
        pressureThresholdMS =
            self.AICombatPressureLowSurvivorMS;
    end

    if not self.AICombatPressureTimer:IsPastSimMS(
        pressureThresholdMS
    ) then
        return;
    end

    print(
        "SpectatorArena: AI_COMBAT_PRESSURE_HUNT"
        .. " totalAlive="
        .. tostring(totalAlive)
        .. " team1="
        .. tostring(team1Alive)
        .. " team2="
        .. tostring(team2Alive)
        .. " thresholdMS="
        .. tostring(pressureThresholdMS)
    );

    self:ForceCombatPressurePursuit(
        team1Actors,
        team2Actors
    );

    self:ForceCombatPressurePursuit(
        team2Actors,
        team1Actors
    );

    self.AICombatPressureTimer:Reset();
end

function SpectatorArena:UpdateAIShadowObservations(team1Actors, team2Actors)
    if self.AI_V2_MODE ~= "SHADOW"
        or not self.AIController
        or not self.AISpawnSettled
    then
        return;
    end

    local timestampMS = self.RoundElapsedTimer.ElapsedSimTimeMS;
    local cpuStartSeconds = os.clock();
    local visibleOpponentTotal = 0;
    local visibleOpponentChecks = 0;
    local losProbeRays = 0;
    local actorSkips = 0;

    local function observeTeam(actors, enemies)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
                and self.AIReleasedActors[actor.UniqueID]
            then
                local nearestEnemy, nearestDistanceSquared =
                    self:FindNearestDirectEnemy(actor, enemies);
                local opponents = {};
                local visibilityByID = {};
                local rayDetailsByID = {};

                for _, opponent in ipairs(enemies) do
                    if MovableMan:IsActor(opponent) and not opponent:IsDead() then
                        -- Mirror Cortex's native target-acquisition profile: eyes
                        -- first cast to the body, then fall back to the eye point.
                        -- This remains SHADOW-only and read-only.
                        local origin = actor.EyePos or actor.Pos;
                        local ray = SceneMan:ShortestDistance(origin, opponent.Pos, false);
                        local distanceSquared = ray.X * ray.X + ray.Y * ray.Y;
                        local targetRootMOID = MovableMan:GetRootMOID(opponent.ID);
                        local hitMOID = rte.NoMOID;
                        local selectedTarget = nil;
                        local rayClassification = "NO_MOID";
                        local isVisible = false;

                        for _, probe in ipairs(
                            self.AIController.BuildSightProbeTargets(
                                opponent.Pos,
                                opponent.EyePos
                            )
                        ) do
                            ray = SceneMan:ShortestDistance(origin, probe.position, false);
                            hitMOID = SceneMan:CastMORay(
                                origin,
                                ray,
                                actor.ID,
                                actor.IgnoresWhichTeam,
                                rte.grassID,
                                false,
                                5
                            );
                            losProbeRays = losProbeRays + 1;
                            selectedTarget = probe;
                            rayClassification = self.AIController.ClassifyRayHit(
                                hitMOID,
                                opponent.ID,
                                targetRootMOID,
                                rte.NoMOID
                            );
                            isVisible = rayClassification == "TARGET"
                                or rayClassification == "TARGET_ROOT";
                            if isVisible then
                                break;
                            end
                        end
                        opponents[#opponents + 1] = {
                            UniqueID = opponent.UniqueID,
                            distanceSquared = distanceSquared,
                            actor = opponent
                        };
                        visibilityByID[opponent.UniqueID] = isVisible;
                        rayDetailsByID[opponent.UniqueID] = {
                            rayReturn = hitMOID,
                            hitMOID = hitMOID,
                            targetMOID = opponent.ID,
                            targetRootMOID = targetRootMOID,
                            noMOID = rte.NoMOID,
                            rayClassification = rayClassification,
                            probeTarget = selectedTarget and selectedTarget.kind or nil,
                            startX = origin.X,
                            startY = origin.Y,
                            endX = selectedTarget and selectedTarget.position.X or nil,
                            endY = selectedTarget and selectedTarget.position.Y or nil
                        };
                        visibleOpponentChecks = visibleOpponentChecks + 1;
                    end
                end

                local visibleEnemy, visibleDistanceSquared, visibleOpponentCount =
                    self.AIController.SelectVisibleOpponent(opponents, visibilityByID);
                visibleOpponentTotal = visibleOpponentTotal + visibleOpponentCount;
                local enemy = visibleEnemy and visibleEnemy.actor or nil;
                local distanceSquared = visibleDistanceSquared or nearestDistanceSquared;
                local nearestRayDetails = nearestEnemy and rayDetailsByID[nearestEnemy.UniqueID] or nil;
                local waypoint = actor:GetLastAIWaypoint();
                local item = actor.EquippedItem;
                local firing = false;

                if item and IsHDFirearm(item) then
                    firing = ToHDFirearm(item).FiredFrame == true;
                end

                local hasLOS = enemy ~= nil;
                if enemy then
                    self.AIController:RecordContact(
                        actor.Team,
                        enemy.UniqueID,
                        timestampMS,
                        enemy.Pos.X,
                        enemy.Pos.Y,
                        1.0,
                        "DIRECT"
                    );
                end

                self.AIController:RecordShadowObservation(
                    actor.UniqueID,
                    timestampMS,
                    hasLOS,
                    firing,
                    actor.Health,
                    actor.PrevHealth,
                    enemy and enemy.UniqueID or nil
                );
                local firedRecently = self.AIController:FiredRecently(
                    actor.UniqueID,
                    timestampMS,
                    1000
                );

                local waypointDistance = SceneMan:ShortestDistance(
                    actor.Pos,
                    waypoint,
                    SceneMan.SceneWrapsX
                );
                local progress = -math.sqrt(
                    waypointDistance.X * waypointDistance.X
                    + waypointDistance.Y * waypointDistance.Y
                );
                self.AIController:RecordProgress(
                    actor.UniqueID,
                    timestampMS,
                    progress
                );

                if firedRecently and enemy and hasLOS then
                    self.AIController:RecordEngagement(
                        actor.UniqueID,
                        timestampMS,
                        "FIRE_LOS",
                        timestampMS + 2500
                    );
                end

                self.Telemetry.Emit("AI_SHADOW_OBSERVATION", {
                    round = self.RoundNumber,
                    actor = actor.UniqueID,
                    team = actor.Team,
                    enemy = nearestEnemy and nearestEnemy.UniqueID or nil,
                    nearestVisibleEnemy = enemy and enemy.UniqueID or nil,
                    rayReturn = nearestRayDetails and nearestRayDetails.rayReturn or nil,
                    hitMOID = nearestRayDetails and nearestRayDetails.hitMOID or nil,
                    targetMOID = nearestRayDetails and nearestRayDetails.targetMOID or nil,
                    targetRootMOID = nearestRayDetails and nearestRayDetails.targetRootMOID or nil,
                    rayNoMOID = nearestRayDetails and nearestRayDetails.noMOID or nil,
                    rayClassification = nearestRayDetails and nearestRayDetails.rayClassification or nil,
                    rayStartX = nearestRayDetails and nearestRayDetails.startX or nil,
                    rayStartY = nearestRayDetails and nearestRayDetails.startY or nil,
                    rayEndX = nearestRayDetails and nearestRayDetails.endX or nil,
                    rayEndY = nearestRayDetails and nearestRayDetails.endY or nil,
                    rayProbeTarget = nearestRayDetails and nearestRayDetails.probeTarget or nil,
                    distance = distanceSquared and math.sqrt(distanceSquared) or nil,
                    health = actor.Health,
                    prevHealth = actor.PrevHealth,
                    firing = firing,
                    firedRecently = firedRecently,
                    hasLOS = hasLOS,
                    visibleOpponentCount = visibleOpponentCount,
                    visibleOpponentChecks = #opponents,
                    waypointX = waypoint.X,
                    waypointY = waypoint.Y,
                    pathSize = actor.MovePathSize,
                    pathPending = actor.IsWaitingOnNewMovePath,
                    recoveryStage = self.AIController:GetRecoveryStage(actor.UniqueID)
                });
            else
                actorSkips = actorSkips + 1;
            end
        end
    end

    observeTeam(team1Actors, team2Actors);
    observeTeam(team2Actors, team1Actors);
    self.AIController:RecordShadowBatchMetrics({
        visibleOpponents = visibleOpponentTotal,
        visibleOpponentChecks = visibleOpponentChecks,
        losProbeRays = losProbeRays,
        actorSkips = actorSkips,
        elapsedMS = self.AIController.CalculateCPUTimeMS(cpuStartSeconds, os.clock())
    });
end

function SpectatorArena:UpdateAIFireDamageLatches(team1Actors, team2Actors)
    if self.AI_V2_MODE ~= "SHADOW"
        or not self.AIController
        or not self.AISpawnSettled
    then
        return;
    end

    local timestampMS = self.RoundElapsedTimer.ElapsedSimTimeMS;

    local function sampleSignals(actors)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
                and self.AIReleasedActors[actor.UniqueID]
            then
                local item = actor.EquippedItem;
                local firing = false;
                if item and IsHDFirearm(item) then
                    firing = ToHDFirearm(item).FiredFrame == true;
                end
                self.AIController:RecordCombatSignals(
                    actor.UniqueID,
                    timestampMS,
                    firing,
                    actor.Health,
                    actor.PrevHealth
                );
            end
        end
    end

    sampleSignals(team1Actors);
    sampleSignals(team2Actors);
end

function SpectatorArena:UpdateAIInstrumentation(team1Actors, team2Actors)
    if not self.AIController
        or not self.AISpawnSettled
        or not self.AIInstrumentationTimer:IsPastSimMS(self.AIInstrumentationIntervalMS) then
        return;
    end

    self.AIInstrumentationTimer:Reset();

    local function sampleActors(actors)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
                and self.AIReleasedActors[actor.UniqueID]
            then
                local waypoint = actor:GetLastAIWaypoint();
                self.AIController:RecordPosition(
                    actor.UniqueID,
                    self.RoundElapsedTimer.ElapsedSimTimeMS,
                    actor.Pos.X,
                    actor.Pos.Y,
                    waypoint.X,
                    waypoint.Y,
                    false,
                    actor.IsWaitingOnNewMovePath
                );
            end
        end
    end

    sampleActors(team1Actors);
    sampleActors(team2Actors);

    self:UpdateAIShadowObservations(team1Actors, team2Actors);
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


    self:UpdateCameraDirector(team1Actors, team2Actors);
    self:UpdateSpawnSettle(
        team1Actors,
        team2Actors
    );
    self:UpdateAIFireDamageLatches(team1Actors, team2Actors);
    self:UpdateAIInstrumentation(team1Actors, team2Actors);

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

    local elapsedRoundSeconds =
        math.floor(self.RoundElapsedTimer.ElapsedSimTimeMS / 1000);

    local elapsedRoundMinutes =
        math.floor(elapsedRoundSeconds / 60);

    local elapsedRoundSecondsPart =
        elapsedRoundSeconds % 60;

    local elapsedRoundText =
        string.format(
            "%02d:%02d",
            elapsedRoundMinutes,
            elapsedRoundSecondsPart
        );
    local totalAliveForPressure =
        team1Alive + team2Alive;

    local pressureThresholdForHUD =
        self.AICombatPressureNormalMS;

    if totalAliveForPressure <= 3 then
        pressureThresholdForHUD =
            self.AICombatPressureCriticalMS;
    elseif totalAliveForPressure <= 4 then
        pressureThresholdForHUD =
            self.AICombatPressureLowSurvivorMS;
    end

    local pressureElapsedSeconds =
        math.floor(
            self.AICombatPressureTimer.ElapsedSimTimeMS / 1000
        );

    local pressureThresholdSeconds =
        math.floor(
            pressureThresholdForHUD / 1000
        );

    FrameMan:SetScreenText(
        "ROUND " .. tostring(self.RoundNumber) ..
        " | TIME " .. elapsedRoundText ..
        " | HUNT " ..
        tostring(pressureElapsedSeconds) ..
        "/" ..
        tostring(pressureThresholdSeconds) ..
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

    -- Navigation and anti-idle pressure run only after the
    -- round has definitively entered BATTLE.
    -- V7 BRAINHUNT BASELINE:
    -- periodic GOTO retargeting disabled for this experiment.
    -- Native BRAINHUNT owns normal movement/combat.

    self:UpdateDistributedMovingTargets(
        team1Actors,
        team2Actors
    );

    self:UpdateCombatPressure(
        team1Actors,
        team2Actors,
        team1Alive,
        team2Alive
    );
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


-- Hybrid camera revision: reliable soldier follow with occasional combat POIs.
function SpectatorArena:IsCameraAnchorValid(actor)
    return actor ~= nil and MovableMan:IsActor(actor);
end


function SpectatorArena:SelectSoldierAnchor(team1Actors, team2Actors)
    if #team1Actors == 1 then
        return team1Actors[1];
    end

    if #team2Actors == 1 then
        return team2Actors[1];
    end

    local _, _, combatActor = self:FindBestCombatFocus(team1Actors, team2Actors);

    if combatActor then
        return combatActor;
    end

    return team1Actors[1] or team2Actors[1];
end


-- TEMPORARY RAW CAMERA DIAGNOSTIC:
-- choose a useful idle soldier while alternating teams.
function SpectatorArena:SelectRawIdleSoldier(team1Actors, team2Actors)
    local selectedTeam = self.CameraRawNextIdleTeam or 1;

    local candidates = selectedTeam == 1 and team1Actors or team2Actors;
    local enemies = selectedTeam == 1 and team2Actors or team1Actors;

    -- If the requested team has nobody alive, use the other one.
    if #candidates == 0 then
        selectedTeam = selectedTeam == 1 and 2 or 1;
        candidates = selectedTeam == 1 and team1Actors or team2Actors;
        enemies = selectedTeam == 1 and team2Actors or team1Actors;
    end

    local bestActor = nil;
    local bestDistanceSquared = math.huge;

    for _, actor in ipairs(candidates) do
        local nearestDistanceSquared = math.huge;

        for _, enemy in ipairs(enemies) do
            local distance = SceneMan:ShortestDistance(
                actor.Pos,
                enemy.Pos,
                SceneMan.SceneWrapsX
            );

            local distanceSquared =
                (distance.X * distance.X) +
                (distance.Y * distance.Y);

            if distanceSquared < nearestDistanceSquared then
                nearestDistanceSquared = distanceSquared;
            end
        end

        if nearestDistanceSquared < bestDistanceSquared then
            bestDistanceSquared = nearestDistanceSquared;
            bestActor = actor;
        end
    end

    -- Alternate the requested team for the next idle phase.
    self.CameraRawNextIdleTeam = selectedTeam == 1 and 2 or 1;
    self.CameraRawCurrentIdleTeam = selectedTeam;

    return bestActor, selectedTeam;
end


function SpectatorArena:FindBestCombatPOI(team1Actors, team2Actors)
    local position, score, actor, enemy = self:FindBestCombatFocus(team1Actors, team2Actors);

    if not actor or not enemy or score < 1000 then
        return nil, 0, nil, nil;
    end

    return position, score, actor, enemy;
end


function SpectatorArena:ReturnToSoldierFollow(team1Actors, team2Actors)
    self.CameraMode = "CAMERA_SOLDIER";
    if not self:IsCameraAnchorValid(self.CameraFollowActor) then
        self.CameraFollowActor = self:SelectSoldierAnchor(team1Actors, team2Actors);
    end
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraFocusScore = 0;
    self.CameraModeTimer:Reset();
    self.CameraEvaluationTimer:Reset();
end


function SpectatorArena:EnterPOIMode(position, score, actor, enemy)
    self.CameraMode = "CAMERA_POI";
    self.CameraFocusPosition = position;
    self.CameraFocusScore = score;
    self.CameraPOIActor = actor;
    self.CameraPOIEnemy = enemy;
    self.CameraModeTimer:Reset();
    self.CameraPOICooldownTimer:Reset();
    self.CameraPOICooldownReady = false;
end


function SpectatorArena:TrackCameraFire()
    if not self:IsCameraAnchorValid(self.CameraFollowActor) then
        return;
    end

    local equippedItem = self.CameraFollowActor.EquippedItem;
    if not equippedItem or not IsHDFirearm(equippedItem) then
        return;
    end

    local firearm = ToHDFirearm(equippedItem);
    if not firearm.FiredFrame then
        return;
    end

    local aimDirection = Vector(1, 0):RadRotate(self.CameraFollowActor:GetAimAngle(true));
    self.CameraLastShot = {
        shooterID = self.CameraFollowActor.UniqueID,
        shooterTeam = self.CameraFollowActor.Team,
        originX = firearm.MuzzlePos.X,
        originY = firearm.MuzzlePos.Y,
        directionX = aimDirection.X,
        directionY = aimDirection.Y
    };
    self.CameraRecentFireTimer:Reset();
end


function SpectatorArena:DetectCameraEvent(team1Actors, team2Actors)
    local currentActors = {};
    for _, actor in ipairs(team1Actors) do
        currentActors[actor.UniqueID] = actor;
    end
    for _, actor in ipairs(team2Actors) do
        currentActors[actor.UniqueID] = actor;
    end

    local disappearedActors = {};
    if self.CameraLastShot then
        for uniqueID, tracked in pairs(self.CameraTrackedActors) do
            local currentActor = currentActors[uniqueID];
            local hasObservedDeath = self.CameraEventLogic.HasObservedDeath(
                tracked.dead,
                currentActor ~= nil,
                currentActor and currentActor:IsDead() or false
            );

            if tracked.team ~= self.CameraLastShot.shooterTeam
                and hasObservedDeath then
                local eventPosition = currentActor and currentActor.Pos or tracked.position;
                local offset = SceneMan:ShortestDistance(
                    Vector(self.CameraLastShot.originX, self.CameraLastShot.originY),
                    eventPosition,
                    SceneMan.SceneWrapsX
                );
                table.insert(disappearedActors, {
                    id = uniqueID,
                    team = tracked.team,
                    x = self.CameraLastShot.originX + offset.X,
                    y = self.CameraLastShot.originY + offset.Y,
                    position = Vector(eventPosition.X, eventPosition.Y),
                    deathObserved = true
                });
            end
        end
    end

    self.CameraTrackedActors = {};
    for _, actor in ipairs(team1Actors) do
        self.CameraTrackedActors[actor.UniqueID] = {
            team = actor.Team,
            position = Vector(actor.Pos.X, actor.Pos.Y),
            dead = actor:IsDead(),
            health = actor.Health,
            wounds = actor.WoundCount
        };
    end
    for _, actor in ipairs(team2Actors) do
        self.CameraTrackedActors[actor.UniqueID] = {
            team = actor.Team,
            position = Vector(actor.Pos.X, actor.Pos.Y),
            dead = actor:IsDead(),
            health = actor.Health,
            wounds = actor.WoundCount
        };
    end

    if not self.CameraLastShot
        or not self.CameraEventCooldownReady
        or self:IsCameraAnchorValid(self.CameraFollowActor)
            and self.CameraFollowActor.UniqueID ~= self.CameraLastShot.shooterID then
        return nil;
    end

    local shot = {
        ageMS = self.CameraRecentFireTimer.ElapsedSimTimeMS,
        shooterTeam = self.CameraLastShot.shooterTeam,
        originX = self.CameraLastShot.originX,
        originY = self.CameraLastShot.originY,
        directionX = self.CameraLastShot.directionX,
        directionY = self.CameraLastShot.directionY
    };

    return self.CameraEventLogic.SelectEventCandidate(
        shot,
        disappearedActors,
        self.CameraHandledVictims,
        self.CameraRecentFireWindowMS,
        self.CameraEventMinimumAimDot,
        self.CameraEventMinimumDistance,
        self.CameraEventMaximumRange
    );
end


function SpectatorArena:EnterEventMode(event)
    self.CameraMode = "CAMERA_EVENT";
    self.CameraEventPosition = event.position;
    self.CameraFocusPosition = event.position;
    self.CameraHandledVictims[event.id] = true;
    self.CameraModeTimer:Reset();
    self.CameraEventCooldownTimer:Reset();
    self.CameraEventCooldownReady = false;
    print("SpectatorArena: CAMERA_EVENT");
end


function SpectatorArena:ResetCameraDirector()
    self.CameraMode = "CAMERA_CENTER";
    self.CameraFollowActor = nil;
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraEventPosition = nil;
    self.CameraLastShot = nil;
    self.CameraTrackedActors = {};
    self.CameraHandledVictims = {};
    self.CameraHasFocus = false;
    self.CameraFocusPosition = self.CameraPos;
    self.CameraFocusScore = 0;
    self.CameraEvaluationTimer:Reset();
    self.CameraModeTimer:Reset();
    self.CameraPOICooldownTimer:Reset();
    self.CameraRecentFireTimer:Reset();
    self.CameraEventCooldownTimer:Reset();
    self.CameraPOICooldownReady = true;
    self.CameraEventCooldownReady = true;
end


function SpectatorArena:UpdateCameraDirector(team1Actors, team2Actors)
    if self.State ~= "BATTLE" then
        if self.RoundOver and self:IsCameraAnchorValid(self.CameraFollowActor) then
            self:SetObservationTarget(self.CameraFollowActor.Pos, Activity.PLAYER_1);
        elseif self.RoundOver and self.CameraFocusPosition then
            self:SetObservationTarget(self.CameraFocusPosition, Activity.PLAYER_1);
        else
            if self.CameraMode ~= "CAMERA_CENTER" then
                self:ResetCameraDirector();
            end
            self:SetObservationTarget(self.CameraPos, Activity.PLAYER_1);
        end
        return;
    end

    local allTeam1Actors = team1Actors;
    local allTeam2Actors = team2Actors;
    local livingTeam1Actors = {};
    local livingTeam2Actors = {};

    for _, actor in ipairs(allTeam1Actors) do
        if not actor:IsDead() then
            table.insert(livingTeam1Actors, actor);
        end
    end
    for _, actor in ipairs(allTeam2Actors) do
        if not actor:IsDead() then
            table.insert(livingTeam2Actors, actor);
        end
    end

    team1Actors = livingTeam1Actors;
    team2Actors = livingTeam2Actors;

    -- TEMPORARY RAW CAMERA DIAGNOSTIC.
    -- No holds, no cooldowns, no event timing:
    -- show exactly what the current selector prefers.
    if self.CameraRawDiagnosticMode then
        if self.CameraEventLogic.HasLastSurvivorPriority(#team1Actors, #team2Actors) then
            local survivor = self.CameraEventLogic.SelectLastSurvivor(team1Actors, team2Actors);

            if self:IsCameraAnchorValid(survivor) then
                local survivorID = survivor.UniqueID;

                if self.CameraRawLastTargetType ~= "SURVIVOR"
                    or self.CameraRawLastActorID ~= survivorID then

                    print("SpectatorArena: CAMERA_RAW SURVIVOR actor=" .. tostring(survivorID));

                    self.CameraRawLastTargetType = "SURVIVOR";
                    self.CameraRawLastActorID = survivorID;
                    self.CameraRawLastEnemyID = nil;
                end

                self.CameraFollowActor = survivor;
                self:SetObservationTarget(survivor.Pos, Activity.PLAYER_1);
            end

            return;
        end

        local position, score, actor, enemy =
            self:FindBestCombatPOI(team1Actors, team2Actors);

        if position and actor and enemy then
            local actorID = actor.UniqueID;
            local enemyID = enemy.UniqueID;

            if self.CameraRawLastTargetType ~= "POI"
                or self.CameraRawLastActorID ~= actorID
                or self.CameraRawLastEnemyID ~= enemyID then

                print(
                    "SpectatorArena: CAMERA_RAW POI actor="
                    .. tostring(actorID)
                    .. " enemy="
                    .. tostring(enemyID)
                    .. " score="
                    .. tostring(math.floor(score))
                );

                self.CameraRawLastTargetType = "POI";
                self.CameraRawLastActorID = actorID;
                self.CameraRawLastEnemyID = enemyID;
            end

            self:SetObservationTarget(position, Activity.PLAYER_1);
            return;
        end

        -- Every time active combat ends and we return to idle observation,
        -- deliberately choose the opposite team from the previous idle phase.
        if self.CameraRawLastTargetType ~= "SOLDIER"
            or not self:IsCameraAnchorValid(self.CameraFollowActor) then

            local idleActor, idleTeam =
                self:SelectRawIdleSoldier(team1Actors, team2Actors);

            self.CameraFollowActor = idleActor;
            self.CameraRawCurrentIdleTeam = idleTeam;
        end

        if self:IsCameraAnchorValid(self.CameraFollowActor) then
            local actorID = self.CameraFollowActor.UniqueID;

            if self.CameraRawLastTargetType ~= "SOLDIER"
                or self.CameraRawLastActorID ~= actorID then

                print(
                    "SpectatorArena: CAMERA_RAW SOLDIER team="
                    .. tostring(self.CameraRawCurrentIdleTeam)
                    .. " actor="
                    .. tostring(actorID)
                );

                self.CameraRawLastTargetType = "SOLDIER";
                self.CameraRawLastActorID = actorID;
                self.CameraRawLastEnemyID = nil;
            end

            self:SetObservationTarget(
                self.CameraFollowActor.Pos,
                Activity.PLAYER_1
            );
        else
            if self.CameraRawLastTargetType ~= "CENTER" then
                print("SpectatorArena: CAMERA_RAW CENTER");

                self.CameraRawLastTargetType = "CENTER";
                self.CameraRawLastActorID = nil;
                self.CameraRawLastEnemyID = nil;
            end

            self:SetObservationTarget(
                self.CameraPos,
                Activity.PLAYER_1
            );
        end

        return;
    end

    if not self.CameraPOICooldownReady
        and self.CameraPOICooldownTimer:IsPastSimMS(self.CameraPOICooldownMS) then
        self.CameraPOICooldownReady = true;
    end

    if not self.CameraEventCooldownReady
        and self.CameraEventCooldownTimer:IsPastSimMS(self.CameraEventCooldownMS) then
        self.CameraEventCooldownReady = true;
    end

    if self.CameraEventLogic.HasLastSurvivorPriority(#team1Actors, #team2Actors) then
        self.CameraMode = "CAMERA_SOLDIER";
        self.CameraFollowActor = self.CameraEventLogic.SelectLastSurvivor(team1Actors, team2Actors);
        self.CameraPOIActor = nil;
        self.CameraPOIEnemy = nil;
        self.CameraEventPosition = nil;
        if self:IsCameraAnchorValid(self.CameraFollowActor) then
            self:SetObservationTarget(self.CameraFollowActor.Pos, Activity.PLAYER_1);
        end
        self:DetectCameraEvent(allTeam1Actors, allTeam2Actors);
        return;
    end

    self:TrackCameraFire();
    local cameraEvent = self:DetectCameraEvent(allTeam1Actors, allTeam2Actors);
    if cameraEvent then
        self:EnterEventMode(cameraEvent);
    end

    if self.CameraMode == "CAMERA_EVENT" then
        if not self.CameraEventPosition
            or self.CameraModeTimer:IsPastSimMS(self.CameraEventHoldMS) then
            self.CameraEventPosition = nil;
            self:ReturnToSoldierFollow(team1Actors, team2Actors);
        else
            self:SetObservationTarget(self.CameraEventPosition, Activity.PLAYER_1);
            return;
        end
    end

    if self.CameraMode == "CAMERA_POI" then
        local poiActorsValid = self:IsCameraAnchorValid(self.CameraPOIActor)
            and self:IsCameraAnchorValid(self.CameraPOIEnemy);
        local poiDistanceValid = false;

        if poiActorsValid then
            local distance = SceneMan:ShortestDistance(
                self.CameraPOIActor.Pos,
                self.CameraPOIEnemy.Pos,
                SceneMan.SceneWrapsX
            );
            poiDistanceValid = (distance.X * distance.X) + (distance.Y * distance.Y) <= 260 * 260;
        end

        if not poiActorsValid
            or not poiDistanceValid
            or self.CameraModeTimer:IsPastSimMS(self.CameraPOIMaximumHoldMS) then
            self:ReturnToSoldierFollow(team1Actors, team2Actors);
        else
            self:SetObservationTarget(self.CameraFocusPosition, Activity.PLAYER_1);
            return;
        end
    end

    if self.CameraMode ~= "CAMERA_SOLDIER"
        or not self:IsCameraAnchorValid(self.CameraFollowActor) then
        self:ReturnToSoldierFollow(team1Actors, team2Actors);
    end

    if self:IsCameraAnchorValid(self.CameraFollowActor) then
        self:SetObservationTarget(self.CameraFollowActor.Pos, Activity.PLAYER_1);
    else
        self:SetObservationTarget(self.CameraPos, Activity.PLAYER_1);
    end

    if self.CameraEvaluationTimer:IsPastSimMS(self.CameraEvaluationIntervalMS)
        and self.CameraPOICooldownReady
        and self.CameraModeTimer:IsPastSimMS(self.CameraSoldierMinimumHoldMS) then
        self.CameraEvaluationTimer:Reset();
        local position, score, actor, enemy = self:FindBestCombatPOI(team1Actors, team2Actors);

        if position and score >= self.CameraFocusScore * self.CameraPOISwitchThreshold then
            self:EnterPOIMode(position, score, actor, enemy);
        end
    end
end
