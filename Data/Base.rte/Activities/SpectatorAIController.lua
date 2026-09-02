local SpectatorAIController = {}

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
            EngagementObservations = 0
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
        EngagementObservations = 0
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
        EngagementObservations = self.Metrics.EngagementObservations
    }
end

return SpectatorAIController
