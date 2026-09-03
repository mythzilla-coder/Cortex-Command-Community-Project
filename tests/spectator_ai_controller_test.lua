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

assertTrue(Controller.IsVisibleRayHit(42, 42, 42, -1), "direct target ray hit is visible")
assertTrue(Controller.IsVisibleRayHit(99, 42, 99, -1), "target child ray hit is visible")
assertFalse(Controller.IsVisibleRayHit(-1, 42, 42, -1), "terrain ray hit is blocked")
assertFalse(Controller.IsVisibleRayHit(77, 42, 42, -1), "intervening actor ray hit is blocked")
assertEqual(Controller.ClassifyRayHit(42, 42, 42, -1), "TARGET", "direct target hit is classified")
assertEqual(Controller.ClassifyRayHit(99, 42, 99, -1), "TARGET_ROOT", "target root hit is classified")
assertEqual(Controller.ClassifyRayHit(-1, 42, 42, -1), "NO_MOID", "no-MOID hit is classified")
assertEqual(Controller.ClassifyRayHit(77, 42, 42, -1), "BLOCKED", "intervening actor hit is classified")
assertEqual(Controller.CalculateCPUTimeMS(1.25, 1.5), 250, "CPU time converts to milliseconds")

local sightTargets = Controller.BuildSightProbeTargets(
    { X = 100, Y = 200 },
    { X = 100, Y = 180 }
)
assertEqual(#sightTargets, 2, "body and eye sight targets are both probed")
assertEqual(sightTargets[1].kind, "BODY", "body is the first native-aligned sight probe")
assertEqual(sightTargets[2].kind, "EYE", "eye is the fallback native-aligned sight probe")
assertEqual(#Controller.BuildSightProbeTargets({ X = 1, Y = 2 }, { X = 1, Y = 2 }), 1,
    "identical body and eye targets are not double-probed")

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

local nearestVisible, nearestVisibleDistance, visibleCount =
    Controller.SelectVisibleOpponent({
        { UniqueID = 202, distanceSquared = 100 },
        { UniqueID = 303, distanceSquared = 400 },
    }, {
        [202] = false,
        [303] = true
    })
assertEqual(nearestVisible.UniqueID, 303, "blocked nearest opponent is skipped")
assertEqual(nearestVisibleDistance, 400, "nearest visible distance is selected")
assertEqual(visibleCount, 1, "visible opponent count is reported")

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

controller:RecordShadowObservation(101, 12000, true, false, 90, 100, 202)
controller:RecordShadowObservation(101, 12500, false, true, 80, 90, nil)
assertEqual(controller.Metrics.ShadowObservations, 2, "shadow observations are aggregated")
assertEqual(controller.Metrics.LOSChecks, 2, "LOS checks are aggregated")
assertEqual(controller.Metrics.LOSPositive, 1, "positive LOS checks are aggregated")
assertEqual(controller.Metrics.FireEvents, 1, "fire events are latched")
assertEqual(controller.Metrics.DamageEvents, 1, "damage events are latched")
assertEqual(controller.Metrics.ContactAcquisitions, 1, "contact acquisition is latched")
assertEqual(controller.Metrics.ContactLosses, 1, "contact loss is latched")
assertTrue(controller:FiredRecently(101, 13000, 1000), "recent fire latch remains active")
assertFalse(controller:FiredRecently(101, 13501, 1000), "recent fire latch expires")

local fireEventsBeforeSignal = controller.Metrics.FireEvents
local damageEventsBeforeSignal = controller.Metrics.DamageEvents
controller:RecordCombatSignals(101, 14000, true, 70, 80)
assertEqual(controller.Metrics.FireEvents, fireEventsBeforeSignal + 1, "high-frequency fire signal is latched")
assertEqual(controller.Metrics.DamageEvents, damageEventsBeforeSignal + 1, "high-frequency damage signal is latched")

local fireEventsBeforeSensor = controller.Metrics.FireEvents
controller:RecordFireSensorSample(101, 14500, 77, 101, true, 2, 3)
controller:RecordFireSensorSample(101, 14517, 77, 101, false, 0, 0)
local fireSensorState = controller:GetFireSensorState(101)
assertEqual(fireSensorState.Team, 1, "fire sensor state retains the actor team")
assertEqual(fireSensorState.FirearmMOID, 77, "fire sensor state retains the equipped firearm MOID")
assertEqual(fireSensorState.FirearmRootMOID, 101, "fire sensor state retains the firearm root MOID")
assertEqual(fireSensorState.SampleCount, 2, "fire sensor state counts consecutive samples")
assertEqual(fireSensorState.FirstSampleTimeMS, 14500, "fire sensor state records the first sample timestamp")
assertEqual(fireSensorState.LastSampleTimeMS, 14517, "fire sensor state records the latest sample timestamp")
assertEqual(fireSensorState.FiredFrameTransitions, 1, "fire sensor state records a fired-frame rising transition")
assertEqual(fireSensorState.RoundsFiredSamples, 1, "fire sensor state records positive rounds-fired samples")
assertEqual(fireSensorState.FireEventCount, fireEventsBeforeSensor + 1, "fire sensor samples latch one durable fire event")
assertEqual(fireSensorState.FireFrameCount, 1, "fire sensor state counts fired frames")
assertEqual(fireSensorState.RoundsDischargedObserved, 2, "fire sensor state counts observed discharged rounds")

local fireSensorSnapshot = controller:Snapshot()
assertEqual(fireSensorSnapshot.FireSensorSamples, 2, "fire sensor samples are aggregated")
assertEqual(fireSensorSnapshot.FirearmEquippedSamples, 2, "equipped firearms are aggregated")
assertEqual(fireSensorSnapshot.FiredFrameSamples, 1, "positive fired-frame samples are aggregated")
assertEqual(fireSensorSnapshot.RoundsFiredSamples, 1, "positive rounds-fired samples are aggregated")
assertEqual(fireSensorSnapshot.FireFrameCount, 1, "fired frames are aggregated")
assertEqual(fireSensorSnapshot.RoundsDischargedObserved, 2, "discharged rounds are aggregated")
assertEqual(fireSensorSnapshot.AlarmEventsObserved, 3, "alarm events are aggregated once per timestamp")

controller:RecordFireSensorContext(101, "FG", "HDFirearm", "HeldDevice", 3, 1)
fireSensorState = controller:GetFireSensorState(101)
assertEqual(fireSensorState.FirearmSlot, "FG", "fire sensor state records the hand holding the firearm")
assertEqual(fireSensorState.EquippedItemClass, "HDFirearm", "fire sensor state records the foreground item class")
assertEqual(fireSensorState.EquippedBGItemClass, "HeldDevice", "fire sensor state records the background item class")
assertEqual(fireSensorState.InventorySize, 3, "fire sensor state records the inventory size")
assertEqual(fireSensorState.InventoryFirearmCount, 1, "fire sensor state records inventory firearms")

controller:RecordShadowBatchMetrics({
    visibleOpponents = 3,
    visibleOpponentChecks = 8,
    losProbeRays = 11,
    actorSkips = 1,
    contactAcquisitions = 2,
    contactLosses = 1,
    elapsedMS = 4.5
})
local metricsSnapshot = controller:Snapshot()
assertEqual(metricsSnapshot.VisibleOpponents, 3, "visible opponents are aggregated")
assertEqual(metricsSnapshot.VisibleOpponentChecks, 8, "visibility checks are aggregated")
assertEqual(metricsSnapshot.LOSProbeRays, 11, "native-aligned LOS probe rays are aggregated")
assertEqual(metricsSnapshot.ActorSkips, 1, "actor skips are aggregated")
assertEqual(metricsSnapshot.ContactAcquisitions, 3, "contact acquisitions are aggregated")
assertEqual(metricsSnapshot.ContactLosses, 2, "contact losses are aggregated")
assertEqual(metricsSnapshot.ShadowObservationTimeMS, 4.5, "shadow timing is aggregated")

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
