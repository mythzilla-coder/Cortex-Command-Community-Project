function SpectatorArena:RecordLoadoutDiagnostic(stage, fields)
    if not self.LoadoutDiagnosticEnabled or not self.Telemetry then
        return
    end

    fields = fields or {};
    fields.stage = stage;
    self.LoadoutDiagnosticCount = self.LoadoutDiagnosticCount + 1;
    self.Telemetry.Emit("LOADOUT_DIAGNOSTIC", fields);

    if self.LoadoutDiagnosticCount >= self.LoadoutDiagnosticLimit then
        self.LoadoutDiagnosticEnabled = false;
    end
end

function SpectatorArena:RecordSpawnTrace(stage, team, actorIndex, success, durationMS)
    if not self.ArenaSpawnTrace then
        return
    end
    self.ArenaSpawnTraceSequence = self.ArenaSpawnTraceSequence + 1
    if #self.ArenaSpawnTrace >= self.ArenaSpawnTraceLimit then
        table.remove(self.ArenaSpawnTrace, 1)
    end
    table.insert(self.ArenaSpawnTrace, {
        sequence = self.ArenaSpawnTraceSequence,
        wallMS = self.ArenaSpawnWallTimer.ElapsedRealTimeMS,
        simMS = self.RoundElapsedTimer and self.RoundElapsedTimer.ElapsedSimTimeMS or 0,
        stage = stage,
        team = team,
        actorIndex = actorIndex,
        success = success,
        durationMS = durationMS
    })
end

function SpectatorArena:PersistSpawnTrace(reason)
    if self.ArenaSpawnTracePersisted or not self.Telemetry then
        return
    end
    self.ArenaSpawnTracePersisted = true
    print("SpectatorArena: SPAWN_TRACE_BEGIN reason=" .. tostring(reason))
    for _, entry in ipairs(self.ArenaSpawnTrace) do
        print("SpectatorArena: SPAWN_TRACE"
            .. " sequence=" .. tostring(entry.sequence)
            .. " wallMS=" .. tostring(entry.wallMS)
            .. " simMS=" .. tostring(entry.simMS)
            .. " stage=" .. tostring(entry.stage)
            .. " team=" .. tostring(entry.team)
            .. " actorIndex=" .. tostring(entry.actorIndex)
            .. " success=" .. tostring(entry.success)
            .. " durationMS=" .. tostring(entry.durationMS))
    end
    print("SpectatorArena: SPAWN_TRACE_END reason=" .. tostring(reason))
    self.Telemetry.Snapshot("SPECTATOR_ARENA_SPAWN_TRACE_LOG.txt")
end

function SpectatorArena:RecordPostSpawnTrace(stage, fields)
    if not self.A1PostSpawnTrace or self.A1PostSpawnTracePersisted then
        return
    end

    fields = fields or {}
    self.A1PostSpawnTraceSequence = self.A1PostSpawnTraceSequence + 1
    if #self.A1PostSpawnTrace >= self.A1PostSpawnTraceLimit then
        table.remove(self.A1PostSpawnTrace, 1)
    end
    table.insert(self.A1PostSpawnTrace, {
        sequence = self.A1PostSpawnTraceSequence,
        wallMS = self.A1PostSpawnWallTimer and self.A1PostSpawnWallTimer.ElapsedRealTimeMS or 0,
        simMS = self.RoundElapsedTimer and self.RoundElapsedTimer.ElapsedSimTimeMS or 0,
        stage = stage,
        updateCount = self.A1UpdateCount or 0,
        round = self.RoundNumber or 0,
        state = self.State,
        mode = self.AI_V2_MODE,
        spawned = fields.spawned or self.A1SpawnedActorCount,
        landed = fields.landed or self.A1LandedActorCount,
        released = fields.released or self.A1ReleasedActorCount,
        team1Alive = fields.team1Alive or self.A1Team1Alive,
        team2Alive = fields.team2Alive or self.A1Team2Alive,
        pendingActorIDs = fields.pendingActorIDs or self.A1PendingActorIDs,
        pendingActorID = fields.pendingActorID or self.A1PendingActorID,
        pendingVelY = fields.pendingVelY or self.A1PendingVelY,
        pendingGroundDistance = fields.pendingGroundDistance or self.A1PendingGroundDistance,
        detail = fields.detail
    })
end

function SpectatorArena:TracePostSpawnBoundary(stage, fields, force)
    if self.A1PostSpawnTracePersisted then
        return
    end

    self.A1LastStage = stage
    if force or self.A1HeartbeatUpdates[self.A1UpdateCount or 0] then
        self:RecordPostSpawnTrace(stage, fields)
    end
end

function SpectatorArena:PersistPostSpawnTrace(reason)
    if self.A1PostSpawnTracePersisted or not self.Telemetry then
        return
    end

    self:RecordPostSpawnTrace("A1_COMPLETE", { detail = reason })
    self.A1PostSpawnTracePersisted = true
    print("SpectatorArena: A1_TRACE_BEGIN reason=" .. tostring(reason)
        .. " lastStage=" .. tostring(self.A1LastStage)
        .. " updates=" .. tostring(self.A1UpdateCount)
        .. " spawned=" .. tostring(self.A1SpawnedActorCount)
        .. " landed=" .. tostring(self.A1LandedActorCount)
        .. " released=" .. tostring(self.A1ReleasedActorCount)
        .. " team1Alive=" .. tostring(self.A1Team1Alive)
        .. " team2Alive=" .. tostring(self.A1Team2Alive)
        .. " mode=" .. tostring(self.AI_V2_MODE))
    for _, entry in ipairs(self.A1PostSpawnTrace) do
        print("SpectatorArena: A1_TRACE"
            .. " sequence=" .. tostring(entry.sequence)
            .. " wallMS=" .. tostring(entry.wallMS)
            .. " simMS=" .. tostring(entry.simMS)
            .. " stage=" .. tostring(entry.stage)
            .. " updateCount=" .. tostring(entry.updateCount)
            .. " round=" .. tostring(entry.round)
            .. " state=" .. tostring(entry.state)
            .. " mode=" .. tostring(entry.mode)
            .. " spawned=" .. tostring(entry.spawned)
            .. " landed=" .. tostring(entry.landed)
            .. " released=" .. tostring(entry.released)
            .. " team1Alive=" .. tostring(entry.team1Alive)
            .. " team2Alive=" .. tostring(entry.team2Alive)
            .. " pendingActorIDs=" .. tostring(entry.pendingActorIDs)
            .. " pendingActorID=" .. tostring(entry.pendingActorID)
            .. " pendingVelY=" .. tostring(entry.pendingVelY)
            .. " pendingGroundDistance=" .. tostring(entry.pendingGroundDistance)
            .. " detail=" .. tostring(entry.detail))
    end
    print("SpectatorArena: A1_TRACE_END reason=" .. tostring(reason))
    self.Telemetry.Snapshot("SPECTATOR_ARENA_POST_SPAWN_TRACE_LOG.txt")
end

function SpectatorArena:RecordA1ProgressMarkers()
    if self.A1PostSpawnTracePersisted
        or self.AI_V2_MODE ~= "SHADOW"
        or not self.AIController
    then
        return
    end

    local snapshot = self.AIController:Snapshot()
    local markers = {
        { key = "A1FirstVisibilityObserved", stage = "FIRST_VISIBILITY_OBSERVATION",
            value = snapshot.VisibleOpponents },
        { key = "A1FirstContactObserved", stage = "FIRST_CONTACT_ACQUISITION",
            value = snapshot.ContactAcquisitions },
        { key = "A1FirstFirearmObserved", stage = "FIRST_FIREARM_DISCOVERY",
            value = snapshot.FirearmEquippedSamples },
        { key = "A1FirstFiredFrameObserved", stage = "FIRST_FIRED_FRAME",
            value = snapshot.FiredFrameSamples },
        { key = "A1FirstFireLatchObserved", stage = "FIRST_DURABLE_FIRE_LATCH",
            value = snapshot.FireFrameCount },
        { key = "A1FirstDamageObserved", stage = "FIRST_DAMAGE_OBSERVATION",
            value = snapshot.DamageEvents }
    }

    for _, marker in ipairs(markers) do
        if marker.value and marker.value > 0 and not self[marker.key] then
            self[marker.key] = true
            self:TracePostSpawnBoundary(marker.stage, {
                detail = marker.value
            }, true)
        end
    end
end

function SpectatorArena:CreateFactionSoldier(factionName, team, actorIndex)
local moduleID = PresetMan:GetModuleID(factionName);
    local tracePrefix = "T" .. tostring(team) .. "_A" .. tostring(actorIndex)

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

        self:RecordSpawnTrace(tracePrefix .. "_CREATE_BEGIN", team, actorIndex)
        local createStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
        local candidate = RandomAHuman(group, factionName)
        self:RecordSpawnTrace(tracePrefix .. "_CREATE_RETURN", team, actorIndex, candidate ~= nil,
            self.ArenaSpawnWallTimer.ElapsedRealTimeMS - createStart)

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
            self:RecordSpawnTrace(tracePrefix .. "_CREATE_FALLBACK_BEGIN", team, actorIndex)
            local createStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
            local candidate = RandomAHuman("Actors", factionName)
            self:RecordSpawnTrace(tracePrefix .. "_CREATE_FALLBACK_RETURN", team, actorIndex,
                candidate ~= nil, self.ArenaSpawnWallTimer.ElapsedRealTimeMS - createStart)

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

        self:RecordSpawnTrace(tracePrefix .. "_WEAPON_BEGIN", team, actorIndex)
        local weaponStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
        local candidate = RandomHDFirearm(group, factionName)
        self:RecordSpawnTrace(tracePrefix .. "_WEAPON_RETURN", team, actorIndex, candidate ~= nil,
            self.ArenaSpawnWallTimer.ElapsedRealTimeMS - weaponStart)

        self:RecordLoadoutDiagnostic("WEAPON_CANDIDATE", {
            attempt = attempt,
            candidate = candidate and candidate.PresetName or "NONE",
            candidateModule = candidate and candidate.ModuleID or -1,
            expectedModule = moduleID,
            faction = factionName,
            group = group,
            accepted = candidate and candidate.ModuleID == moduleID or false
        });

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
        self:RecordSpawnTrace(tracePrefix .. "_INVENTORY_BEGIN", team, actorIndex)
        local inventoryStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
        actor:AddInventoryItem(weapon)
        self:RecordSpawnTrace(tracePrefix .. "_INVENTORY_RETURN", team, actorIndex, true,
            self.ArenaSpawnWallTimer.ElapsedRealTimeMS - inventoryStart)
        self:RecordLoadoutDiagnostic("WEAPON_HANDOFF", {
            actor = actor.UniqueID,
            actorModule = actor.ModuleID,
            equipped = actor.EquippedItem and actor.EquippedItem.PresetName or "NONE",
            faction = factionName,
            inventory = actor.InventorySize,
            weapon = weapon.PresetName,
            weaponModule = weapon.ModuleID
        });
        if self.A1RetainWeaponReference then
            -- Diagnostic only: retain the Lua wrapper for the C++-owned item
            -- through the first enumerable update. Do not mutate the weapon.
            self.A1DiagnosticWeaponRefs[actor.UniqueID] = weapon;
        end
    end

    return actor;
end


function SpectatorArena:SpawnRound()
    self.ArenaSpawnInProgress = true
    self.ArenaSpawnComplete = false
    self:RecordSpawnTrace("ROUND_SETUP_BEGIN")
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
    self:RecordSpawnTrace("FACTIONS_SELECTED")

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
        self:RecordSpawnTrace("TEAM0_SPAWN_BEGIN", self.Team1, i)
        local actor =
            self:CreateFactionSoldier(
                self.Team1Faction,
                self.Team1,
                i
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

            self:RecordSpawnTrace("T0_A" .. tostring(i) .. "_ADD_ACTOR_BEGIN", self.Team1, i)
            local addActorStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
            MovableMan:AddActor(actor)
            self:RecordSpawnTrace("T0_A" .. tostring(i) .. "_ADD_ACTOR_RETURN", self.Team1, i,
                MovableMan:IsActor(actor), self.ArenaSpawnWallTimer.ElapsedRealTimeMS - addActorStart)
            local postInsertionItem = actor.EquippedItem;
            local postInsertionBGItem = actor.EquippedBGItem;
            self:RecordLoadoutDiagnostic("WEAPON_POST_INSERTION", {
                actor = actor.UniqueID,
                actorValid = MovableMan:IsActor(actor),
                equipped = postInsertionItem and postInsertionItem.PresetName or "NONE",
                equippedClass = postInsertionItem and postInsertionItem.ClassName or "NONE",
                equippedIsFirearm = postInsertionItem and IsHDFirearm(postInsertionItem) or false,
                equippedMOID = postInsertionItem and postInsertionItem.ID or -1,
                equippedRootMOID = postInsertionItem and postInsertionItem.RootID or -1,
                retentionEnabled = self.A1RetainWeaponReference,
                retainedReference = self.A1DiagnosticWeaponRefs[actor.UniqueID] ~= nil,
                background = postInsertionBGItem and postInsertionBGItem.PresetName or "NONE",
                backgroundClass = postInsertionBGItem and postInsertionBGItem.ClassName or "NONE",
                inventory = actor.InventorySize,
                team = actor.Team
            });
            if not self.A1PostSpawnStarted and MovableMan:IsActor(actor) then
                self.A1SpawnedActorCount = self.A1SpawnedActorCount + 1
            end
            self:RecordSpawnTrace("T0_A" .. tostring(i) .. "_REGISTER_BEGIN", self.Team1, i)
            self.AIController:RegisterActor(actor.UniqueID, self.Team1, i);
            self:RecordSpawnTrace("T0_A" .. tostring(i) .. "_REGISTER_RETURN", self.Team1, i, true)
        end
    end
    self:RecordSpawnTrace("TEAM0_SPAWN_END", self.Team1, 8, true)


    for i = 1, 8 do
        self:RecordSpawnTrace("TEAM1_SPAWN_BEGIN", self.Team2, i)
        local actor =
            self:CreateFactionSoldier(
                self.Team2Faction,
                self.Team2,
                i
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

            self:RecordSpawnTrace("T1_A" .. tostring(i) .. "_ADD_ACTOR_BEGIN", self.Team2, i)
            local addActorStart = self.ArenaSpawnWallTimer.ElapsedRealTimeMS
            MovableMan:AddActor(actor)
            self:RecordSpawnTrace("T1_A" .. tostring(i) .. "_ADD_ACTOR_RETURN", self.Team2, i,
                MovableMan:IsActor(actor), self.ArenaSpawnWallTimer.ElapsedRealTimeMS - addActorStart)
            local postInsertionItem = actor.EquippedItem;
            local postInsertionBGItem = actor.EquippedBGItem;
            self:RecordLoadoutDiagnostic("WEAPON_POST_INSERTION", {
                actor = actor.UniqueID,
                actorValid = MovableMan:IsActor(actor),
                equipped = postInsertionItem and postInsertionItem.PresetName or "NONE",
                equippedClass = postInsertionItem and postInsertionItem.ClassName or "NONE",
                equippedIsFirearm = postInsertionItem and IsHDFirearm(postInsertionItem) or false,
                equippedMOID = postInsertionItem and postInsertionItem.ID or -1,
                equippedRootMOID = postInsertionItem and postInsertionItem.RootID or -1,
                retentionEnabled = self.A1RetainWeaponReference,
                retainedReference = self.A1DiagnosticWeaponRefs[actor.UniqueID] ~= nil,
                background = postInsertionBGItem and postInsertionBGItem.PresetName or "NONE",
                backgroundClass = postInsertionBGItem and postInsertionBGItem.ClassName or "NONE",
                inventory = actor.InventorySize,
                team = actor.Team
            });
            if not self.A1PostSpawnStarted and MovableMan:IsActor(actor) then
                self.A1SpawnedActorCount = self.A1SpawnedActorCount + 1
            end
            self:RecordSpawnTrace("T1_A" .. tostring(i) .. "_REGISTER_BEGIN", self.Team2, i)
            self.AIController:RegisterActor(actor.UniqueID, self.Team2, i);
            self:RecordSpawnTrace("T1_A" .. tostring(i) .. "_REGISTER_RETURN", self.Team2, i, true)
        end
    end
    self:RecordSpawnTrace("TEAM1_SPAWN_END", self.Team2, 8, true)
    self:RecordSpawnTrace("ROUND_SPAWN_COMPLETE", nil, nil, true)
    self.ArenaSpawnComplete = true
    self.ArenaSpawnInProgress = false
    self:PersistSpawnTrace("ROUND_SPAWN_COMPLETE")
    if not self.A1PostSpawnStarted then
        self.A1PostSpawnStarted = true
        self.A1PostSpawnWallTimer:Reset()
        self:RecordPostSpawnTrace("ROUND_SPAWN_COMPLETE", {
            spawned = self.A1SpawnedActorCount,
            landed = 0,
            released = 0
        })
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

    self.A1PendingActorID = nil;
    self.A1PendingVelY = nil;
    self.A1PendingGroundDistance = nil;

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
                    arena.A1LandedActors[actor.UniqueID] = true;
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
                    if not arena.A1PendingActorID then
                        arena.A1PendingActorID = actor.UniqueID;
                        arena.A1PendingVelY = actor.Vel.Y;
                        arena.A1PendingGroundDistance = groundDistance;
                    end
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
    local landedActorCount = 0;
    local releasedActorCount = 0;
    local pendingActorIDs = {};

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
                else
                    table.insert(pendingActorIDs, tostring(actor.UniqueID));
                end

                if arena.A1LandedActors[actor.UniqueID] then
                    landedActorCount =
                        landedActorCount + 1;
                end
            end
        end
    end

    countTeam(self, team1Actors);
    countTeam(self, team2Actors);
    self.A1SpawnedActorCount = livingActorCount;
    self.A1LandedActorCount = landedActorCount;
    self.A1ReleasedActorCount = releasedActorCount;
    self.A1PendingActorIDs = #pendingActorIDs > 0
        and table.concat(pendingActorIDs, ",")
        or "NONE";

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
        if not self.A1AllActorsReleasedObserved then
            self.A1AllActorsReleasedObserved = true;
            self:TracePostSpawnBoundary("ALL_ACTORS_RELEASED", nil, true)
        end
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
    self:TracePostSpawnBoundary("ROUND_RESULT", {
        team1Alive = self.A1Team1Alive,
        team2Alive = self.A1Team2Alive,
        detail = self.RoundResultText
    }, true)
    self:PersistPostSpawnTrace("ROUND_RESULT")
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
            shadowObservationTimeMS = aiSnapshot.ShadowObservationTimeMS,
            fireSensorSamples = aiSnapshot.FireSensorSamples,
            firearmEquippedSamples = aiSnapshot.FirearmEquippedSamples,
            firearmMissingSamples = aiSnapshot.FirearmMissingSamples,
            firedFrameSamples = aiSnapshot.FiredFrameSamples,
            firedFrameTransitions = aiSnapshot.FiredFrameTransitions,
            roundsFiredSamples = aiSnapshot.RoundsFiredSamples,
            roundsFiredTotal = aiSnapshot.RoundsFiredTotal,
            alarmEventSnapshots = aiSnapshot.AlarmEventSnapshots,
            alarmEventsObserved = aiSnapshot.AlarmEventsObserved,
            fireFrameCount = aiSnapshot.FireFrameCount,
            roundsDischargedObserved = aiSnapshot.RoundsDischargedObserved
        });
        for _, state in ipairs(self.AIController:GetFireSensorStates()) do
            self.Telemetry.Emit("AI_SHADOW_FIRE_SENSOR_SUMMARY", {
                round = self.RoundNumber,
                actor = state.ActorID,
                team = state.Team,
                firearmFound = state.FirearmMOID ~= nil,
                firearmMOID = state.FirearmMOID,
                firearmRootMOID = state.FirearmRootMOID,
                firearmSlot = state.FirearmSlot,
                equippedItemClass = state.EquippedItemClass,
                equippedBGItemClass = state.EquippedBGItemClass,
                inventorySize = state.InventorySize,
                inventoryFirearmCount = state.InventoryFirearmCount,
                sampleCount = state.SampleCount,
                firstSampleTimeMS = state.FirstSampleTimeMS,
                lastSampleTimeMS = state.LastSampleTimeMS,
                firedFrameTransitions = state.FiredFrameTransitions,
                roundsFiredSamples = state.RoundsFiredSamples,
                lastFiredFrame = state.LastFiredFrame,
                lastRoundsFired = state.LastRoundsFired,
                lastFireTimeMS = state.LastFireTimeMS,
                fireEventCount = state.FireEventCount,
                fireFrameCount = state.FireFrameCount,
                roundsDischargedObserved = state.RoundsDischargedObserved
            });
        end
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
    self.LoadoutDiagnosticEnabled = true;
    self.LoadoutDiagnosticCount = 0;
    self.LoadoutDiagnosticLimit = 64;
    self.LoadoutDiagnosticSnapshotFactions = {};
    self.A1RetainWeaponReference = false;
    self.A1DiagnosticWeaponRefs = {};
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
    self.ArenaSpawnWallTimer = Timer();
    self.ArenaSpawnTrace = {};
    self.ArenaSpawnTraceSequence = 0;
    self.ArenaSpawnTraceLimit = 256;
    self.ArenaSpawnTracePersisted = false;
    self.ArenaSpawnTraceStartupTimeoutMS = 15000;
    self.ArenaSpawnInProgress = false;
    self.ArenaSpawnComplete = false;
    self.A1PostSpawnWallTimer = Timer();
    self.A1PostSpawnTrace = {};
    self.A1PostSpawnTraceSequence = 0;
    self.A1PostSpawnTraceLimit = 256;
    self.A1PostSpawnTracePersisted = false;
    self.A1PostSpawnStarted = false;
    self.A1PostSpawnTimeoutMS = 20000;
    self.A1UpdateCount = 0;
    self.A1HeartbeatUpdates = {
        [1] = true,
        [2] = true,
        [10] = true,
        [60] = true,
        [300] = true,
        [600] = true,
        [1200] = true
    };
    self.A1LastStage = "NOT_STARTED";
    self.A1LandedActors = {};
    self.A1SpawnedActorCount = 0;
    self.A1LandedActorCount = 0;
    self.A1ReleasedActorCount = 0;
    self.A1Team1Alive = 0;
    self.A1Team2Alive = 0;
    self.A1PendingActorIDs = "NONE";
    self.A1PendingActorID = nil;
    self.A1PendingVelY = nil;
    self.A1PendingGroundDistance = nil;
    self.A1AllActorsReleasedObserved = false;
    self.A1FirstVisibilityObserved = false;
    self.A1FirstContactObserved = false;
    self.A1FirstFirearmObserved = false;
    self.A1FirstFiredFrameObserved = false;
    self.A1FirstFireLatchObserved = false;
    self.A1FirstDamageObserved = false;
    self.A1FirstUpdateLoadoutObserved = {};
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
    self.CameraEngagementHoldMS = 900;
    self.CameraEngagementCooldownMS = 1400;
    self.CameraEngagementMinimumAimDot = 0.80;
    self.CameraEngagementMinimumDistance = 300;
    self.CameraEngagementMaximumRange = 1600;
    self.CameraEngagementEnemyBias = 0.55;

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
    self.CameraEngagementCooldownTimer = Timer();
    self.CameraPOICooldownReady = true;
    self.CameraEventCooldownReady = true;
    self.CameraEngagementCooldownReady = true;
    self.CameraMode = "CAMERA_CENTER";
    self.CameraFollowActor = nil;
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraEventLogic = require("Activities/SpectatorCameraEventLogic");
    self.CameraLastShot = nil;
    self.CameraRoundsFiredByActor = {};
    self.CameraControllerFireByActor = {};
    self.CameraTrackedActors = {};
    self.CameraHandledVictims = {};
    self.CameraEventPosition = nil;
    self.CameraEngagementPosition = nil;
    self.CameraEngagementEnemy = nil;
    -- Review-only trace state. This records camera evidence without changing
    -- selection, priority, hold, or cooldown behavior.
    self.CameraEventTraceEnabled = true;
    self.CameraTraceSequence = 0;
    self.CameraEventTraceID = nil;
    self.CameraEventTargetIssued = false;
    self.CameraFocusPosition = self.CameraPos;
    self.CameraFocusScore = 0;
    self.CameraFocusActor = nil;
    self.CameraHasFocus = false;
    self.HUDLogic = require("Activities/SpectatorHUDLogic");

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
                    false,
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
    local alarmEventCount = 0;
    for _ in MovableMan.AlarmEvents do
        alarmEventCount = alarmEventCount + 1;
    end

    local function sampleSignals(actors)
        for _, actor in ipairs(actors) do
            if MovableMan:IsActor(actor)
                and not actor:IsDead()
                and self.AIReleasedActors[actor.UniqueID]
            then
                local item = actor.EquippedItem;
                local backgroundItem = actor.EquippedBGItem;
                local firing = false;
                local firearmMOID = nil;
                local firearmRootMOID = nil;
                local roundsFired = 0;
                local firearmSlot = nil;
                local inventoryFirearmCount = 0;
                if item and IsHDFirearm(item) then
                    local firearm = ToHDFirearm(item);
                    firearmMOID = firearm.ID;
                    firearmRootMOID = firearm.RootID;
                    firing = firearm.FiredFrame == true;
                    roundsFired = firearm.RoundsFired;
                    firearmSlot = "FG";
                elseif backgroundItem and IsHDFirearm(backgroundItem) then
                    local firearm = ToHDFirearm(backgroundItem);
                    firearmMOID = firearm.ID;
                    firearmRootMOID = firearm.RootID;
                    firing = firearm.FiredFrame == true;
                    roundsFired = firearm.RoundsFired;
                    firearmSlot = "BG";
                end
                for inventoryItem in actor.Inventory do
                    if IsHDFirearm(inventoryItem) then
                        inventoryFirearmCount = inventoryFirearmCount + 1;
                    end
                end
                self.AIController:RecordFireSensorSample(
                    actor.UniqueID,
                    timestampMS,
                    firearmMOID,
                    firearmRootMOID,
                    firing,
                    roundsFired,
                    alarmEventCount
                );
                -- The sensor path owns fire latching; retain the generic
                -- read-only signal call for health bookkeeping only.
                self.AIController:RecordCombatSignals(
                    actor.UniqueID,
                    timestampMS,
                    false
                );
                self.AIController:RecordFireSensorContext(
                    actor.UniqueID,
                    firearmSlot,
                    item and item.ClassName or nil,
                    backgroundItem and backgroundItem.ClassName or nil,
                    actor.InventorySize,
                    inventoryFirearmCount
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

    self:TracePostSpawnBoundary("BEFORE_SHADOW_UPDATE")
    self:UpdateAIShadowObservations(team1Actors, team2Actors);
    self:TracePostSpawnBoundary("AFTER_SHADOW_UPDATE")
    self:RecordA1ProgressMarkers()
end

function SpectatorArena:DrawSpectatorHUD(hud)
    local screen = self:ScreenOfPlayer(Activity.PLAYER_1);
    local screenWidth = FrameMan.PlayerScreenWidth;
    local centerX = math.floor(screenWidth * 0.5);
    local cameraOffset = CameraMan:GetOffset(screen);

    PrimitiveMan:DrawTextPrimitive(
        screen,
        cameraOffset + Vector(12, 28),
        hud.team1,
        true,
        0
    );
    PrimitiveMan:DrawTextPrimitive(
        screen,
        cameraOffset + Vector(screenWidth - 12, 28),
        hud.team2,
        true,
        2
    );
    PrimitiveMan:DrawTextPrimitive(
        screen,
        cameraOffset + Vector(centerX, 12),
        hud.header,
        true,
        1
    );

    if hud.pressure then
        PrimitiveMan:DrawTextPrimitive(
            screen,
            cameraOffset + Vector(centerX, 25),
            hud.pressure,
            true,
            1
        );
    end
end

function SpectatorArena:UpdateActivity()
    if self.ArenaSpawnInProgress
        and not self.ArenaSpawnTracePersisted
        and self.ArenaSpawnWallTimer.ElapsedRealTimeMS >= self.ArenaSpawnTraceStartupTimeoutMS
    then
        self:RecordSpawnTrace("STARTUP_DIAGNOSTIC_TIMEOUT", nil, nil, false)
        self:PersistSpawnTrace("STARTUP_DIAGNOSTIC_TIMEOUT")
    end
    if self.A1PostSpawnStarted
        and not self.A1PostSpawnTracePersisted
        and self.A1PostSpawnWallTimer.ElapsedRealTimeMS >= self.A1PostSpawnTimeoutMS
    then
        self:PersistPostSpawnTrace("DIAGNOSTIC_TIMEOUT")
    end

    self.A1UpdateCount = self.A1UpdateCount + 1;
    self:TracePostSpawnBoundary("UPDATE_ACTIVITY_ENTER")
    local team1Alive = 0;
    local team2Alive = 0;

    local team1Actors = {};
    local team2Actors = {};

    self:TracePostSpawnBoundary("BEFORE_ACTOR_SCAN")
    for actor in MovableMan.Actors do
        if actor.Team == self.Team1 then
            team1Alive = team1Alive + 1;
            table.insert(team1Actors, actor);

        elseif actor.Team == self.Team2 then
            team2Alive = team2Alive + 1;
            table.insert(team2Actors, actor);
        end
    end
    self.A1Team1Alive = team1Alive;
    self.A1Team2Alive = team2Alive;
    self.A1SpawnedActorCount = #team1Actors + #team2Actors;
    self:TracePostSpawnBoundary("AFTER_ACTOR_SCAN")

    local function recordFirstUpdateLoadout(arena, actors)
        for _, actor in ipairs(actors) do
            if not arena.A1FirstUpdateLoadoutObserved[actor.UniqueID] then
                arena.A1FirstUpdateLoadoutObserved[actor.UniqueID] = true;
                local equippedItem = actor.EquippedItem;
                local backgroundItem = actor.EquippedBGItem;
                local retainedWeapon = arena.A1DiagnosticWeaponRefs[actor.UniqueID];
                local foregroundArm = actor.FGArm;
                local foregroundHeldDevice = foregroundArm and foregroundArm.HeldDevice;
                local retainedAttached = false;
                if retainedWeapon and IsAttachable(retainedWeapon) then
                    retainedAttached = retainedWeapon:IsAttached();
                end
                local worldItemCount = 0;
                local retainedWorldItem = false;
                if retainedWeapon then
                    for item in MovableMan.Items do
                        worldItemCount = worldItemCount + 1;
                        if item.ID == retainedWeapon.ID then
                            retainedWorldItem = true;
                        end
                    end
                end
                arena:RecordLoadoutDiagnostic("WEAPON_FIRST_UPDATE", {
                    actor = actor.UniqueID,
                    actorValid = MovableMan:IsActor(actor),
                    equipped = equippedItem and equippedItem.PresetName or "NONE",
                    equippedClass = equippedItem and equippedItem.ClassName or "NONE",
                    equippedIsFirearm = equippedItem and IsHDFirearm(equippedItem) or false,
                    equippedMOID = equippedItem and equippedItem.ID or -1,
                    equippedRootMOID = equippedItem and equippedItem.RootID or -1,
                    retained = retainedWeapon ~= nil,
                    retainedValid = retainedWeapon and IsHDFirearm(retainedWeapon) or false,
                    retainedPreset = retainedWeapon and retainedWeapon.PresetName or "NONE",
                    retainedMOID = retainedWeapon and retainedWeapon.ID or -1,
                    retainedRootMOID = retainedWeapon and retainedWeapon.RootID or -1,
                    retainedAttached = retainedAttached,
                    foregroundArmAttached = foregroundArm and foregroundArm:IsAttached() or false,
                    foregroundArmMOID = foregroundArm and foregroundArm.ID or -1,
                    foregroundArmHeld = foregroundHeldDevice and foregroundHeldDevice.PresetName or "NONE",
                    foregroundArmHeldMOID = foregroundHeldDevice and foregroundHeldDevice.ID or -1,
                    worldItemCount = worldItemCount,
                    retainedWorldItem = retainedWorldItem,
                    background = backgroundItem and backgroundItem.PresetName or "NONE",
                    backgroundClass = backgroundItem and backgroundItem.ClassName or "NONE",
                    inventory = actor.InventorySize,
                    team = actor.Team,
                    updateCount = arena.A1UpdateCount
                });
            end
        end
    end
    recordFirstUpdateLoadout(self, team1Actors);
    recordFirstUpdateLoadout(self, team2Actors);

    if self.A1HeartbeatUpdates[self.A1UpdateCount] then
        self:RecordPostSpawnTrace("UPDATE_" .. tostring(self.A1UpdateCount), {
            spawned = self.A1SpawnedActorCount,
            team1Alive = team1Alive,
            team2Alive = team2Alive
        })
    end


    self:TracePostSpawnBoundary("BEFORE_CAMERA_UPDATE")
    self:UpdateCameraDirector(team1Actors, team2Actors);
    self:TracePostSpawnBoundary("AFTER_CAMERA_UPDATE")
    self:TracePostSpawnBoundary("BEFORE_TOUCHDOWN_UPDATE")
    self:UpdateSpawnSettle(
        team1Actors,
        team2Actors
    );
    self:TracePostSpawnBoundary("AFTER_TOUCHDOWN_UPDATE")
    self:TracePostSpawnBoundary("BEFORE_FIRE_LATCH_UPDATE")
    self:UpdateAIFireDamageLatches(team1Actors, team2Actors);
    self:TracePostSpawnBoundary("AFTER_FIRE_LATCH_UPDATE")
    self:TracePostSpawnBoundary("BEFORE_AI_INSTRUMENTATION")
    self:UpdateAIInstrumentation(team1Actors, team2Actors);
    self:TracePostSpawnBoundary("AFTER_AI_INSTRUMENTATION")

    if self.RoundOver then
        local resultHUD = self.HUDLogic.BuildResultHUD(
            self.RoundNumber,
            self.Team1Faction,
            team1Alive,
            self.Team1Score,
            self.Team2Faction,
            team2Alive,
            self.Team2Score
        );
        self:DrawSpectatorHUD(resultHUD);
        FrameMan:SetScreenText(
            self.HUDLogic.BuildResultText(
                self.RoundResultText,
                self.Team1Score,
                self.Team2Score
            ),
            self:ScreenOfPlayer(Activity.PLAYER_1),
            0,
            -1,
            true
        );

        if self.RoundEndTimer:IsPastSimMS(self.RoundEndDelay) then
            self:TransitionState("ROUND_RESET");
            self:ClearRoundActors();
            self:TransitionState("PREPARE_ROUND");
            self:SpawnRound();
        end

        self:TracePostSpawnBoundary("UPDATE_ACTIVITY_EXIT")
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

    local spectatorScreen = self:ScreenOfPlayer(Activity.PLAYER_1);
    FrameMan:ClearScreenText(spectatorScreen);
    self:DrawSpectatorHUD(
        self.HUDLogic.BuildBattleHUD(
            self.RoundNumber,
            elapsedRoundText,
            pressureElapsedSeconds,
            pressureThresholdSeconds,
            team1FactionName,
            team1Alive,
            self.Team1Score,
            team2FactionName,
            team2Alive,
            self.Team2Score
        )
    );


    if not self.BattleStarted then
        self:TracePostSpawnBoundary("BEFORE_ROUND_RESULT_EVALUATION")
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
            self:TracePostSpawnBoundary("BATTLE_STARTED", {
                team1Alive = team1Alive,
                team2Alive = team2Alive,
                detail = "COMBAT_ACTIVE"
            }, true)
        end

        self:TracePostSpawnBoundary("UPDATE_ACTIVITY_EXIT")
        return;
    end

    -- Navigation and anti-idle pressure run only after the
    -- round has definitively entered BATTLE.
    -- V7 BRAINHUNT BASELINE:
    -- periodic GOTO retargeting disabled for this experiment.
    -- Native BRAINHUNT owns normal movement/combat.

    self:TracePostSpawnBoundary("BEFORE_DISTRIBUTED_TARGET_UPDATE")
    self:UpdateDistributedMovingTargets(
        team1Actors,
        team2Actors
    );
    self:TracePostSpawnBoundary("AFTER_DISTRIBUTED_TARGET_UPDATE")

    self:TracePostSpawnBoundary("BEFORE_COMBAT_PRESSURE_UPDATE")
    self:UpdateCombatPressure(
        team1Actors,
        team2Actors,
        team1Alive,
        team2Alive
    );
    self:TracePostSpawnBoundary("AFTER_COMBAT_PRESSURE_UPDATE")
    if self.RoundTimer:IsPastSimMS(self.MaxRoundDurationMS) then
        self:ResolveWatchdog(team1Alive, team2Alive);
        return;
    end


    self:TracePostSpawnBoundary("BEFORE_ROUND_RESULT_EVALUATION")
    if team1Alive <= 0 and team2Alive > 0 then
        self:FinishRound(self.Team2);

    elseif team2Alive <= 0 and team1Alive > 0 then
        self:FinishRound(self.Team1);

    elseif team1Alive <= 0 and team2Alive <= 0 then
        self:FinishRound(Activity.NOTEAM);
    end
    self:TracePostSpawnBoundary("AFTER_ROUND_RESULT_EVALUATION")
    self:TracePostSpawnBoundary("UPDATE_ACTIVITY_EXIT")
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
    local previousMode = self.CameraMode;
    self.CameraMode = "CAMERA_SOLDIER";
    if not self:IsCameraAnchorValid(self.CameraFollowActor) then
        self.CameraFollowActor = self:SelectSoldierAnchor(team1Actors, team2Actors);
    end
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraEngagementPosition = nil;
    self.CameraEngagementEnemy = nil;
    self.CameraFocusScore = 0;
    self.CameraModeTimer:Reset();
    self.CameraEvaluationTimer:Reset();
    if previousMode == "CAMERA_EVENT" then
        self:EmitCameraTrace("CAMERA_EVENT_RETURN", {
            traceID = self.CameraEventTraceID,
            shooter = self.CameraLastShot and self.CameraLastShot.shooterID or nil
        });
        self.CameraEventTargetIssued = false;
        self.CameraEventTraceID = nil;
    end
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


function SpectatorArena:EmitCameraTrace(event, fields)
    if not self.CameraEventTraceEnabled or not self.Telemetry then
        return;
    end

    fields = fields or {};
    if fields.traceID == nil then
        fields.traceID = self.CameraEventTraceID
            or (self.CameraLastShot and self.CameraLastShot.traceID)
            or nil;
    end
    fields.round = self.RoundNumber;
    fields.simMS = self.RoundTimer and self.RoundTimer.ElapsedSimTimeMS or 0;
    self.Telemetry.Emit(event, fields);
end


function SpectatorArena:TrackCameraFire()
    if not self:IsCameraAnchorValid(self.CameraFollowActor) then
        return;
    end

    local actorID = self.CameraFollowActor.UniqueID;
    local equippedItem = self.CameraFollowActor.EquippedItem;
    if not equippedItem or not IsHDFirearm(equippedItem) then
        local foregroundArm = self.CameraFollowActor.FGArm;
        local heldDevice = foregroundArm and foregroundArm.HeldDevice;
        if heldDevice and IsHDFirearm(heldDevice) then
            equippedItem = heldDevice;
        else
            equippedItem = self.CameraFollowActor.EquippedBGItem;
        end
    end
    if not equippedItem or not IsHDFirearm(equippedItem) then
        local backgroundArm = self.CameraFollowActor.BGArm;
        local heldDevice = backgroundArm and backgroundArm.HeldDevice;
        if heldDevice and IsHDFirearm(heldDevice) then
            equippedItem = heldDevice;
        end
    end
    local controller = self.CameraFollowActor:GetController();
    local controllerFiring = controller
        and controller:IsState(Controller.WEAPON_FIRE)
        or false;
    local previousControllerFiring = self.CameraControllerFireByActor[actorID];
    local controllerFireStarted = controllerFiring and previousControllerFiring ~= true;
    self.CameraControllerFireByActor[actorID] = controllerFiring;

    if not equippedItem or not IsHDFirearm(equippedItem) then
        if not controllerFireStarted then
            return;
        end

        self.CameraTraceSequence = self.CameraTraceSequence + 1;
        self.CameraLastShot = {
            traceID = self.CameraTraceSequence,
            shooterID = actorID,
            shooterTeam = self.CameraFollowActor.Team,
            originX = self.CameraFollowActor.Pos.X,
            originY = self.CameraFollowActor.Pos.Y,
            directionX = Vector(1, 0):RadRotate(self.CameraFollowActor:GetAimAngle(true)).X,
            directionY = Vector(1, 0):RadRotate(self.CameraFollowActor:GetAimAngle(true)).Y
        };
        print("SpectatorArena: CAMERA_FIRE_CONTROLLER shooter=" .. tostring(actorID));
        self:EmitCameraTrace("CAMERA_FIRE_OBSERVED", {
            shooter = actorID,
            source = "CONTROLLER",
            originX = self.CameraLastShot.originX,
            originY = self.CameraLastShot.originY
        });
        self.CameraRecentFireTimer:Reset();
        return;
    end

    local firearm = ToHDFirearm(equippedItem);
    local roundsFired = firearm.RoundsFired or 0;
    local previousRoundsFired = self.CameraRoundsFiredByActor[actorID];
    local roundsAdvanced = previousRoundsFired ~= nil
        and roundsFired > previousRoundsFired;
    self.CameraRoundsFiredByActor[actorID] = roundsFired;

    if not firearm.FiredFrame and not roundsAdvanced then
        return;
    end

    local aimDirection = Vector(1, 0):RadRotate(self.CameraFollowActor:GetAimAngle(true));
    self.CameraTraceSequence = self.CameraTraceSequence + 1;
    self.CameraLastShot = {
        traceID = self.CameraTraceSequence,
        shooterID = actorID,
        shooterTeam = self.CameraFollowActor.Team,
        originX = firearm.MuzzlePos.X,
        originY = firearm.MuzzlePos.Y,
        directionX = aimDirection.X,
        directionY = aimDirection.Y
    };
    print("SpectatorArena: CAMERA_FIRE shooter=" .. tostring(actorID));
    self:EmitCameraTrace("CAMERA_FIRE_OBSERVED", {
        shooter = actorID,
        source = "NATIVE",
        originX = self.CameraLastShot.originX,
        originY = self.CameraLastShot.originY
    });
    self.CameraRecentFireTimer:Reset();
end


function SpectatorArena:FindEngagementTarget(team1Actors, team2Actors)
    if not self.CameraLastShot then
        return nil;
    end

    local enemies = self.CameraLastShot.shooterTeam == self.Team1 and team2Actors or team1Actors;
    local candidates = {};
    local shotOrigin = Vector(
        self.CameraLastShot.originX,
        self.CameraLastShot.originY
    );

    for _, actor in ipairs(enemies) do
        if self:IsCameraAnchorValid(actor) and not actor:IsDead() then
            local offset = SceneMan:ShortestDistance(
                shotOrigin,
                actor.Pos,
                SceneMan.SceneWrapsX
            );
            table.insert(candidates, {
                id = actor.UniqueID,
                team = actor.Team,
                x = shotOrigin.X + offset.X,
                y = shotOrigin.Y + offset.Y,
                actor = actor
            });
        end
    end

    local target = self.CameraEventLogic.SelectEngagementTarget(
        self.CameraLastShot,
        candidates,
        self.CameraEngagementMinimumAimDot,
        self.CameraEngagementMinimumDistance,
        self.CameraEngagementMaximumRange
    );

    return target and target.actor or nil;
end


function SpectatorArena:EnterEngagementMode(enemy)
    if not self:IsCameraAnchorValid(self.CameraFollowActor)
        or not self:IsCameraAnchorValid(enemy)
        or not self.CameraLastShot then
        return;
    end

    local shooterPosition = self.CameraFollowActor.Pos;
    local distance = SceneMan:ShortestDistance(
        shooterPosition,
        enemy.Pos,
        SceneMan.SceneWrapsX
    );
    local frame = self.CameraEventLogic.CalculateEngagementFrame(
        { x = shooterPosition.X, y = shooterPosition.Y },
        {
            x = shooterPosition.X + distance.X,
            y = shooterPosition.Y + distance.Y
        },
        self.CameraEngagementEnemyBias
    );

    self.CameraMode = "CAMERA_ENGAGEMENT";
    self.CameraEngagementPosition = Vector(frame.x, frame.y);
    self.CameraEngagementEnemy = enemy;
    self.CameraModeTimer:Reset();
    self.CameraEngagementCooldownTimer:Reset();
    self.CameraEngagementCooldownReady = false;
    print("SpectatorArena: CAMERA_ENGAGEMENT");
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
            local observedDying = currentActor
                and self.CameraEventLogic.HasObservedDying(
                    tracked.status,
                    currentActor.Status,
                    Actor.DYING
                )
                or false;

            if tracked.team ~= self.CameraLastShot.shooterTeam
                and not currentActor
                and tracked.status ~= Actor.DYING
            then
                self:EmitCameraTrace("CAMERA_EVENT_REMOVAL_UNCONFIRMED", {
                    shooter = self.CameraLastShot.shooterID,
                    victim = uniqueID,
                    victimTeam = tracked.team,
                    trackedStatus = tracked.status,
                    trackedHealth = tracked.health,
                    trackedWounds = tracked.wounds,
                    shotAgeMS = self.CameraRecentFireTimer.ElapsedSimTimeMS
                });
            end

            if tracked.team ~= self.CameraLastShot.shooterTeam and observedDying then
                local eventPosition = currentActor.Pos;
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
                    deathObserved = true,
                    lifecycle = "DYING",
                    traceID = self.CameraLastShot.traceID
                });
                self:EmitCameraTrace("CAMERA_EVENT_DYING_OBSERVED", {
                    traceID = self.CameraLastShot.traceID,
                    shooter = self.CameraLastShot.shooterID,
                    victim = uniqueID,
                    victimTeam = tracked.team,
                    victimX = eventPosition.X,
                    victimY = eventPosition.Y,
                    health = currentActor.Health,
                    prevHealth = currentActor.PrevHealth,
                    shotAgeMS = self.CameraRecentFireTimer.ElapsedSimTimeMS
                });
            end
        end
    end

    self.CameraTrackedActors = {};
    for _, actor in ipairs(team1Actors) do
        self.CameraTrackedActors[actor.UniqueID] = {
            team = actor.Team,
            position = Vector(actor.Pos.X, actor.Pos.Y),
            status = actor.Status,
            health = actor.Health,
            prevHealth = actor.PrevHealth,
            wounds = actor.WoundCount
        };
    end
    for _, actor in ipairs(team2Actors) do
        self.CameraTrackedActors[actor.UniqueID] = {
            team = actor.Team,
            position = Vector(actor.Pos.X, actor.Pos.Y),
            status = actor.Status,
            health = actor.Health,
            prevHealth = actor.PrevHealth,
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
        traceID = self.CameraLastShot.traceID,
        ageMS = self.CameraRecentFireTimer.ElapsedSimTimeMS,
        shooterTeam = self.CameraLastShot.shooterTeam,
        originX = self.CameraLastShot.originX,
        originY = self.CameraLastShot.originY,
        directionX = self.CameraLastShot.directionX,
        directionY = self.CameraLastShot.directionY
    };

    local selected, rejectionReason = self.CameraEventLogic.SelectEventCandidate(
        shot,
        disappearedActors,
        self.CameraHandledVictims,
        self.CameraRecentFireWindowMS,
        self.CameraEventMinimumAimDot,
        self.CameraEventMinimumDistance,
        self.CameraEventMaximumRange
    );

    if #disappearedActors > 0 then
        self:EmitCameraTrace(
            selected and "CAMERA_EVENT_ATTRIBUTION_ACCEPTED"
                or "CAMERA_EVENT_ATTRIBUTION_REJECTED",
            {
                traceID = shot.traceID,
                shooter = self.CameraLastShot.shooterID,
                candidateCount = #disappearedActors,
                shotAgeMS = shot.ageMS,
                cooldownReady = self.CameraEventCooldownReady,
                selectedVictim = selected and selected.id or nil,
                reason = selected and nil or (rejectionReason or "NO_CANDIDATE")
            }
        );
    end

    return selected;
end


function SpectatorArena:EnterEventMode(event)
    self.CameraMode = "CAMERA_EVENT";
    self.CameraEventTraceID = event.traceID
        or (self.CameraLastShot and self.CameraLastShot.traceID)
        or nil;
    self.CameraEventPosition = event.position;
    self.CameraFocusPosition = event.position;
    self.CameraHandledVictims[event.id] = true;
    self.CameraEventTargetIssued = false;
    self.CameraModeTimer:Reset();
    self.CameraEventCooldownTimer:Reset();
    self.CameraEventCooldownReady = false;
    print("SpectatorArena: CAMERA_EVENT");
    self:EmitCameraTrace("CAMERA_EVENT_REQUEST", {
        traceID = self.CameraEventTraceID,
        shooter = self.CameraLastShot and self.CameraLastShot.shooterID or nil,
        victim = event.id,
        victimTeam = event.team,
        victimX = event.position.X,
        victimY = event.position.Y,
        holdMS = self.CameraEventHoldMS
    });
end


function SpectatorArena:ResetCameraDirector()
    self.CameraMode = "CAMERA_CENTER";
    self.CameraFollowActor = nil;
    self.CameraPOIActor = nil;
    self.CameraPOIEnemy = nil;
    self.CameraEventPosition = nil;
    self.CameraEventTraceID = nil;
    self.CameraEngagementPosition = nil;
    self.CameraEngagementEnemy = nil;
    self.CameraEventTargetIssued = false;
    self.CameraLastShot = nil;
    self.CameraRoundsFiredByActor = {};
    self.CameraControllerFireByActor = {};
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
    self.CameraEngagementCooldownTimer:Reset();
    self.CameraPOICooldownReady = true;
    self.CameraEventCooldownReady = true;
    self.CameraEngagementCooldownReady = true;
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

    if not self.CameraEngagementCooldownReady
        and self.CameraEngagementCooldownTimer:IsPastSimMS(self.CameraEngagementCooldownMS) then
        self.CameraEngagementCooldownReady = true;
    end

    if self.CameraEventLogic.HasLastSurvivorPriority(#team1Actors, #team2Actors) then
        self.CameraMode = "CAMERA_SOLDIER";
        self.CameraFollowActor = self.CameraEventLogic.SelectLastSurvivor(team1Actors, team2Actors);
        self.CameraPOIActor = nil;
        self.CameraPOIEnemy = nil;
        self.CameraEventPosition = nil;
        self.CameraEngagementPosition = nil;
        self.CameraEngagementEnemy = nil;
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
    elseif self.CameraMode ~= "CAMERA_EVENT"
        and self.CameraEngagementCooldownReady
        and self.CameraRecentFireTimer.ElapsedSimTimeMS <= self.CameraRecentFireWindowMS then
        local engagementEnemy = self:FindEngagementTarget(team1Actors, team2Actors);
        if engagementEnemy then
            self:EnterEngagementMode(engagementEnemy);
        end
    end

    if self.CameraMode == "CAMERA_EVENT" then
        if not self.CameraEventPosition
            or self.CameraModeTimer:IsPastSimMS(self.CameraEventHoldMS) then
            self:EmitCameraTrace("CAMERA_EVENT_HOLD_COMPLETE", {
                traceID = self.CameraEventTraceID,
                shooter = self.CameraLastShot and self.CameraLastShot.shooterID or nil,
                holdElapsedMS = self.CameraModeTimer.ElapsedSimTimeMS
            });
            self.CameraEventPosition = nil;
            self:ReturnToSoldierFollow(team1Actors, team2Actors);
        else
            if not self.CameraEventTargetIssued then
                self.CameraEventTargetIssued = true;
                self:EmitCameraTrace("CAMERA_EVENT_TARGET_ISSUED", {
                    traceID = self.CameraEventTraceID,
                    shooter = self.CameraLastShot and self.CameraLastShot.shooterID or nil,
                    targetX = self.CameraEventPosition.X,
                    targetY = self.CameraEventPosition.Y
                });
            end
            self:SetObservationTarget(self.CameraEventPosition, Activity.PLAYER_1);
            return;
        end
    end

    if self.CameraMode == "CAMERA_ENGAGEMENT" then
        local engagementValid = self.CameraEngagementPosition
            and self:IsCameraAnchorValid(self.CameraEngagementEnemy)
            and not self.CameraEngagementEnemy:IsDead();

        if not engagementValid
            or self.CameraModeTimer:IsPastSimMS(self.CameraEngagementHoldMS) then
            self.CameraEngagementPosition = nil;
            self.CameraEngagementEnemy = nil;
            self:ReturnToSoldierFollow(team1Actors, team2Actors);
        else
            self:SetObservationTarget(self.CameraEngagementPosition, Activity.PLAYER_1);
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
