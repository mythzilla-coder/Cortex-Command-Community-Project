package.path = "Data/Base.rte/?.lua;" .. package.path

local Controller = require("Activities/SpectatorAIController")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local controller = Controller.Create({ mode = "OFF", positionHistoryLimit = 2 })
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

local snapshot = controller:Snapshot()
assertEqual(snapshot.RoundID, 7, "snapshot identifies round")
assertEqual(snapshot.RegisteredActors, 2, "snapshot counts actors")
assertEqual(snapshot.ReleasedActors, 1, "snapshot counts released actors")

controller:BeginRound(8, 5678)
assertEqual(controller.ActorState[101], nil, "new round clears actor IDs")
assertEqual(controller.ContactMemory[1], nil, "new round clears contact memory")
assertEqual(controller.RoundGeneration, 8, "new round increments generation")

print("spectator_ai_controller_test: PASS")
