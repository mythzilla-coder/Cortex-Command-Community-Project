package.path = "Data/Base.rte/?.lua;" .. package.path

local Controller = require("Activities/SpectatorAIController")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if value ~= true then
        error(message or "expected true")
    end
end

local function assertFalse(value, message)
    if value ~= false then
        error(message or "expected false")
    end
end

local controller = Controller.Create({
    mode = "OFF",
    positionHistoryLimit = 2,
    contactMemoryTTLMS = 3000,
    taskHysteresisMS = 2000,
    reservationTTLMS = 2000,
    progressStallMS = 1000,
    maxRecoveryStage = 3
})
assertEqual(controller.Mode, "OFF", "controller defaults to OFF")

controller:BeginRound(7, 1234)
controller:RegisterActor(101, 1, 1)
controller:RegisterActor(202, 2, 1)
controller:ReleaseActor(101, 500)

local actor = controller.ActorState[101]
assertEqual(actor.Released, true, "release marks actor released")
assertEqual(actor.ReleaseTimeMS, 500, "release time is recorded")
assertEqual(controller.ActorState[202].Released, false, "unreleased actor remains gated")

controller:RecordPosition(101, 1000, 10, 20, 100, 20, false, false)
controller:RecordPosition(101, 1500, 11, 20, 100, 20, false, false)
controller:RecordPosition(101, 2000, 12, 20, 100, 20, false, false)
assertEqual(#controller.ActorState[101].PositionSamples, 2, "position history is bounded")
assertEqual(controller.ActorState[101].PositionSamples[1].timestampMS, 1500, "oldest sample is evicted")

controller:RecordContact(1, 202, 2100, 200, 300, 1.0, "DIRECT")
controller:RecordContact(1, 202, 2500, 999, 999, 0.5, "MEMORY")
assertEqual(controller.ContactMemory[1][202].x, 200, "memory observation does not rewrite frozen position")
assertEqual(controller.ContactMemory[1][202].Confidence, 0.5, "memory confidence can decay explicitly")
assertEqual(controller:GetContact(1, 202, 3000).x, 200, "live contact returns frozen position")
assertEqual(controller:GetContact(1, 202, 6000), nil, "expired contact is not returned")
assertFalse(controller:RecordContact(1, 404, 2600, 400, 400, 1.0, "WORLD_TRUTH"),
    "world-truth coordinates cannot enter team contact memory")

controller:RecordEngagement(101, 1000, "FIRE", 2500)
assertTrue(controller:IsHardEngaged(101, 2000), "engagement lock remains active until expiry")
assertFalse(controller:IsHardEngaged(101, 2501), "engagement lock expires after its deadline")

local snapshot = controller:Snapshot()
assertEqual(snapshot.RoundID, 7, "snapshot identifies round")
assertEqual(snapshot.RegisteredActors, 2, "snapshot counts actors")
assertEqual(snapshot.ReleasedActors, 1, "snapshot counts released actors")
assertEqual(snapshot.EngagementObservations, 1, "snapshot counts engagement observations")

controller:AssignTask(101, "PRESSURE", 1000)
assertEqual(controller.ActorState[101].Task, "PRESSURE", "initial task is assigned")
assertFalse(controller:AssignTask(101, "MANEUVER", 1500), "task hysteresis rejects rapid churn")
assertTrue(controller:AssignTask(101, "MANEUVER", 3001), "task hysteresis permits a mature switch")

controller:RegisterActor(303, 1, 2)
assertTrue(controller:ReserveTarget(101, 202, 4000, 5000, 1), "first target reservation succeeds")
assertFalse(controller:CanReserveTarget(303, 202, 4500, 1), "reservation limit prevents a dogpile")
assertFalse(controller:ReserveTarget(303, 202, 4500, 5000, 1), "blocked reservation is not recorded")
assertTrue(controller:CanReserveTarget(303, 202, 7001, 1), "stale reservation expires")
assertTrue(controller:ReserveTarget(303, 202, 7001, 5000, 1), "replacement reservation succeeds after expiry")

controller:RecordProgress(101, 8000, 10)
assertEqual(controller:GetRecoveryStage(101), 0, "fresh progress has no recovery stage")
controller:RecordProgress(101, 9501, 10)
assertEqual(controller:GetRecoveryStage(101), 1, "first stall escalates one recovery stage")
controller:RecordProgress(101, 11002, 10)
assertEqual(controller:GetRecoveryStage(101), 2, "continued stall escalates only one stage at a time")
assertEqual(controller:GetRecoveryStage(101), 2, "recovery stage remains bounded between observations")

controller:RecordShadowObservation(101, 12000, true, false, 90, 100)
controller:RecordShadowObservation(101, 12500, false, true, 80, 90)
assertEqual(controller.Metrics.ShadowObservations, 2, "shadow observations are aggregated")
assertEqual(controller.Metrics.LOSChecks, 2, "LOS checks are aggregated")
assertEqual(controller.Metrics.LOSPositive, 1, "positive LOS checks are aggregated")
assertEqual(controller.Metrics.FireEvents, 1, "fire events are latched")
assertEqual(controller.Metrics.DamageEvents, 1, "damage events are latched")
assertTrue(controller:FiredRecently(101, 13000, 1000), "recent fire latch remains active")
assertFalse(controller:FiredRecently(101, 13501, 1000), "recent fire latch expires")

local closeWeapon = Controller.ClassifyWeapon({ effectiveRange = 100, projectileCount = 8, spread = 0.4 })
assertEqual(closeWeapon.Class, "CLOSE", "scatter weapon is classified for close engagement")
local longWeapon = Controller.ClassifyWeapon({ effectiveRange = 500, projectileCount = 1, spread = 0.05 })
assertEqual(longWeapon.Class, "LONG", "accurate weapon is classified for distance")
assertEqual(Controller.ClassifyWeapon({}).Confidence, 0, "invalid weapon profile has no confidence")

local closeCovered = Controller.ScoreDestination({
    weaponClass = "CLOSE", distance = 80, hasLOS = true, cover = 1.0, threat = 0.2
})
local closeOpen = Controller.ScoreDestination({
    weaponClass = "CLOSE", distance = 80, hasLOS = true, cover = 0.0, threat = 0.2
})
assertTrue(closeCovered > closeOpen, "close-range weapons prefer covered close positions")

local longLOS = Controller.ScoreDestination({
    weaponClass = "LONG", distance = 500, hasLOS = true, cover = 0.5, threat = 0.2
})
local longBlocked = Controller.ScoreDestination({
    weaponClass = "LONG", distance = 500, hasLOS = false, cover = 0.5, threat = 0.2
})
assertTrue(longLOS > longBlocked, "long-range weapons prefer line of sight")

local selected = Controller.SelectDistinctDestination({
    { id = "marginal", score = 11 },
    { id = "strong", score = 15 }
}, { id = "current", score = 12 }, 2)
assertEqual(selected.id, "strong", "destination selection accepts meaningful improvement")
assertEqual(Controller.SelectDistinctDestination({ { id = "marginal", score = 13 } }, { id = "current", score = 12 }, 2).id,
    "current", "marginal destination improvement is rejected")

controller:BeginRound(8, 5678)
assertEqual(controller.ActorState[101], nil, "new round clears actor IDs")
assertEqual(controller.ContactMemory[1], nil, "new round clears contact memory")
assertEqual(controller.RoundGeneration, 8, "new round increments generation")

print("spectator_ai_controller_test: PASS")
