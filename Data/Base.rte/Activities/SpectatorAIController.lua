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
        RoundGeneration = 0,
        RoundID = nil,
        RoundSeed = nil,
        ActorState = {},
        ContactMemory = {},
        Metrics = {
            PositionSamples = 0,
            ContactObservations = 0
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
    self.Metrics = {
        PositionSamples = 0,
        ContactObservations = 0
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
        ContactObservations = self.Metrics.ContactObservations
    }
end

return SpectatorAIController
