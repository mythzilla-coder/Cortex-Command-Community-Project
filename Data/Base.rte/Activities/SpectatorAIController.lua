local SpectatorAIController = {}

function SpectatorAIController.ClassifyWeapon(profile)
    if type(profile) ~= "table" or type(profile.effectiveRange) ~= "number" or profile.effectiveRange <= 0 then
        return { Class = "UNKNOWN", Confidence = 0 }
    end

    local projectileCount = profile.projectileCount or 1
    local spread = profile.spread or 0
    if profile.effectiveRange < 200 or projectileCount >= 4 or spread > 0.25 then
        return { Class = "CLOSE", Confidence = 1 }
    end
    if profile.effectiveRange >= 350 and projectileCount <= 2 and spread <= 0.2 then
        return { Class = "LONG", Confidence = 1 }
    end
    return { Class = "MID", Confidence = 0.75 }
end

function SpectatorAIController.ScoreDestination(context)
    if type(context) ~= "table" or type(context.distance) ~= "number" then
        return -math.huge
    end

    local cover = math.max(0, math.min(1, context.cover or 0))
    local threat = math.max(0, context.threat or 0)
    local lineOfSight = context.hasLOS and 1 or 0
    local distance = context.distance
    local score

    if context.weaponClass == "CLOSE" then
        score = math.max(0, 1 - math.abs(distance - 100) / 250) + cover * 3 + lineOfSight - threat
    elseif context.weaponClass == "LONG" then
        score = math.max(0, 1 - math.abs(distance - 500) / 600) + lineOfSight * 4 + cover - threat
    else
        score = math.max(0, 1 - math.abs(distance - 250) / 400) + cover * 2 + lineOfSight * 2 - threat
    end

    return score
end

function SpectatorAIController.SelectDistinctDestination(candidates, current, minimumImprovement)
    local best = current
    local bestScore = current and current.score or -math.huge
    for _, candidate in ipairs(candidates or {}) do
        if candidate.score > bestScore then
            best = candidate
            bestScore = candidate.score
        end
    end

    if not best or not current or best == current or bestScore <= (current.score + (minimumImprovement or 0)) then
        return current
    end
    return best
end

function SpectatorAIController.SelectVisibleOpponent(opponents, visibilityByID)
    local nearestOpponent = nil
    local nearestDistanceSquared = nil
    local visibleOpponentCount = 0

    for _, opponent in ipairs(opponents or {}) do
        if visibilityByID and visibilityByID[opponent.UniqueID] == true then
            visibleOpponentCount = visibleOpponentCount + 1
            if nearestDistanceSquared == nil
                or opponent.distanceSquared < nearestDistanceSquared then
                nearestOpponent = opponent
                nearestDistanceSquared = opponent.distanceSquared
            end
        end
    end

    return nearestOpponent, nearestDistanceSquared, visibleOpponentCount
end

local function copySample(timestampMS, x, y, waypointX, waypointY, hardEngaged, pathPending)
    return {
        timestampMS = timestampMS,
        x = x,
        y = y,
        waypointX = waypointX,
        waypointY = waypointY,
        hardEngaged = hardEngaged == true,
        pathPending = pathPending == true
    }
end

function SpectatorAIController.Create(config)
    config = config or {}

    local controller = {
        Mode = config.mode or "OFF",
        PositionHistoryLimit = config.positionHistoryLimit or 4,
        ContactMemoryTTLMS = config.contactMemoryTTLMS or 3000,
        TaskHysteresisMS = config.taskHysteresisMS or 2000,
        ReservationTTLMS = config.reservationTTLMS or 2000,
        ProgressStallMS = config.progressStallMS or 1000,
        MaxRecoveryStage = config.maxRecoveryStage or 3,
        RoundGeneration = 0,
        RoundID = nil,
        RoundSeed = nil,
        ActorState = {},
        ContactMemory = {},
        Reservations = {},
        Metrics = {
            PositionSamples = 0,
            ContactObservations = 0,
            EngagementObservations = 0,
            ShadowObservations = 0,
            LOSChecks = 0,
            LOSPositive = 0,
            FireEvents = 0,
            DamageEvents = 0
        }
    }

    return setmetatable(controller, { __index = SpectatorAIController })
end

function SpectatorAIController:BeginRound(roundID, seed)
    self.RoundGeneration = roundID
    self.RoundID = roundID
    self.RoundSeed = seed
    self.ActorState = {}
    self.ContactMemory = {}
    self.Reservations = {}
    self.Metrics = {
        PositionSamples = 0,
        ContactObservations = 0,
        EngagementObservations = 0,
        ShadowObservations = 0,
        LOSChecks = 0,
        LOSPositive = 0,
        FireEvents = 0,
        DamageEvents = 0
    }
end

function SpectatorAIController:RegisterActor(actorID, team, spawnIndex)
    self.ActorState[actorID] = {
        UniqueID = actorID,
        Team = team,
        SpawnIndex = spawnIndex,
        Released = false,
        ReleaseTimeMS = nil,
        PositionSamples = {}
    }
end

function SpectatorAIController:ReleaseActor(actorID, timestampMS)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    actor.Released = true
    actor.ReleaseTimeMS = timestampMS
    return true
end

function SpectatorAIController:RecordPosition(actorID, timestampMS, x, y, waypointX, waypointY, hardEngaged, pathPending)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    local samples = actor.PositionSamples
    samples[#samples + 1] = copySample(
        timestampMS,
        x,
        y,
        waypointX,
        waypointY,
        hardEngaged,
        pathPending
    )
    while #samples > self.PositionHistoryLimit do
        table.remove(samples, 1)
    end

    self.Metrics.PositionSamples = self.Metrics.PositionSamples + 1
    return true
end

function SpectatorAIController:RecordContact(team, enemyID, timestampMS, x, y, confidence, source)
    if source == "WORLD_TRUTH" then
        return false
    end

    self.ContactMemory[team] = self.ContactMemory[team] or {}
    local contact = self.ContactMemory[team][enemyID]

    if not contact then
        contact = {
            EnemyUniqueID = enemyID,
            LastKnownPosition = { x = x, y = y },
            x = x,
            y = y,
            LastSeenTimeMS = timestampMS,
            Confidence = confidence,
            Source = source
        }
        self.ContactMemory[team][enemyID] = contact
    else
        contact.LastSeenTimeMS = timestampMS
        contact.Confidence = confidence
        contact.Source = source
        if source == "DIRECT" or source == "SHARED_DIRECT" then
            contact.LastKnownPosition = { x = x, y = y }
            contact.x = x
            contact.y = y
        end
    end

    self.Metrics.ContactObservations = self.Metrics.ContactObservations + 1
    return true
end

function SpectatorAIController:RecordFireEvent(actorID, timestampMS)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    actor.LastFireTimeMS = timestampMS
    actor.FireEventCount = (actor.FireEventCount or 0) + 1
    self.Metrics.FireEvents = self.Metrics.FireEvents + 1
    return true
end

function SpectatorAIController:FiredRecently(actorID, timestampMS, windowMS)
    local actor = self.ActorState[actorID]
    return actor ~= nil
        and actor.LastFireTimeMS ~= nil
        and timestampMS - actor.LastFireTimeMS <= (windowMS or 1000)
end

function SpectatorAIController:RecordDamage(actorID, timestampMS, amount)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    actor.LastDamageTimeMS = timestampMS
    actor.DamageEventCount = (actor.DamageEventCount or 0) + 1
    actor.LastDamageAmount = amount
    self.Metrics.DamageEvents = self.Metrics.DamageEvents + 1
    return true
end

function SpectatorAIController:RecordShadowObservation(actorID, timestampMS, hasLOS, firing, health, previousHealth)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    self.Metrics.ShadowObservations = self.Metrics.ShadowObservations + 1
    self.Metrics.LOSChecks = self.Metrics.LOSChecks + 1
    if hasLOS then
        self.Metrics.LOSPositive = self.Metrics.LOSPositive + 1
    end

    if firing then
        self:RecordFireEvent(actorID, timestampMS)
    end

    if type(health) == "number" then
        if actor.LastObservedHealth ~= nil and health < actor.LastObservedHealth then
            self:RecordDamage(actorID, timestampMS, actor.LastObservedHealth - health)
        end
        actor.LastObservedHealth = health
    elseif type(previousHealth) == "number" and actor.LastObservedHealth == nil then
        actor.LastObservedHealth = previousHealth
    end

    return true
end

function SpectatorAIController:GetContact(team, enemyID, timestampMS)
    local contacts = self.ContactMemory[team]
    local contact = contacts and contacts[enemyID]
    if not contact then
        return nil
    end

    if timestampMS - contact.LastSeenTimeMS > self.ContactMemoryTTLMS then
        return nil
    end

    return contact
end

function SpectatorAIController:RecordEngagement(actorID, timestampMS, signal, untilMS)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    actor.HardEngagedUntilMS = untilMS
    actor.LastEngagementTimeMS = timestampMS
    actor.LastEngagementSignal = signal
    self.Metrics.EngagementObservations = self.Metrics.EngagementObservations + 1
    return true
end

function SpectatorAIController:IsHardEngaged(actorID, timestampMS)
    local actor = self.ActorState[actorID]
    return actor ~= nil and actor.HardEngagedUntilMS ~= nil and timestampMS <= actor.HardEngagedUntilMS
end

function SpectatorAIController:AssignTask(actorID, task, timestampMS)
    local actor = self.ActorState[actorID]
    if not actor or not task then
        return false
    end

    if actor.Task == task then
        return true
    end

    if actor.Task ~= nil and timestampMS - actor.TaskAssignedTimeMS < self.TaskHysteresisMS then
        return false
    end

    actor.Task = task
    actor.TaskAssignedTimeMS = timestampMS
    return true
end

local function pruneReservations(reservations, timestampMS)
    local active = {}
    for _, reservation in ipairs(reservations or {}) do
        if reservation.ExpiresAtMS >= timestampMS then
            active[#active + 1] = reservation
        end
    end
    return active
end

function SpectatorAIController:CanReserveTarget(actorID, targetID, timestampMS, limit)
    if not self.ActorState[actorID] or not targetID then
        return false
    end

    local active = pruneReservations(self.Reservations[targetID], timestampMS)
    self.Reservations[targetID] = active
    limit = limit or 1
    for _, reservation in ipairs(active) do
        if reservation.ActorUniqueID == actorID then
            return true
        end
    end
    return #active < limit
end

function SpectatorAIController:ReserveTarget(actorID, targetID, timestampMS, expiresAtMS, limit)
    if not self:CanReserveTarget(actorID, targetID, timestampMS, limit) then
        return false
    end

    local active = self.Reservations[targetID]
    active[#active + 1] = {
        ActorUniqueID = actorID,
        TargetUniqueID = targetID,
        ReservedAtMS = timestampMS,
        ExpiresAtMS = expiresAtMS or (timestampMS + self.ReservationTTLMS)
    }
    return true
end

function SpectatorAIController:RecordProgress(actorID, timestampMS, progress)
    local actor = self.ActorState[actorID]
    if not actor then
        return false
    end

    if actor.LastProgressValue == nil or progress > actor.LastProgressValue then
        actor.RecoveryStage = 0
    elseif timestampMS - actor.LastProgressTimeMS >= self.ProgressStallMS then
        actor.RecoveryStage = math.min((actor.RecoveryStage or 0) + 1, self.MaxRecoveryStage)
    end

    actor.LastProgressValue = progress
    actor.LastProgressTimeMS = timestampMS
    return true
end

function SpectatorAIController:GetRecoveryStage(actorID)
    local actor = self.ActorState[actorID]
    return actor and (actor.RecoveryStage or 0) or 0
end

function SpectatorAIController:Snapshot()
    local registeredActors = 0
    local releasedActors = 0
    for _, actor in pairs(self.ActorState) do
        registeredActors = registeredActors + 1
        if actor.Released then
            releasedActors = releasedActors + 1
        end
    end

    return {
        RoundID = self.RoundID,
        RoundGeneration = self.RoundGeneration,
        RoundSeed = self.RoundSeed,
        Mode = self.Mode,
        RegisteredActors = registeredActors,
        ReleasedActors = releasedActors,
        PositionSamples = self.Metrics.PositionSamples,
        ContactObservations = self.Metrics.ContactObservations,
        EngagementObservations = self.Metrics.EngagementObservations,
        ShadowObservations = self.Metrics.ShadowObservations,
        LOSChecks = self.Metrics.LOSChecks,
        LOSPositive = self.Metrics.LOSPositive,
        FireEvents = self.Metrics.FireEvents,
        DamageEvents = self.Metrics.DamageEvents
    }
end

return SpectatorAIController
