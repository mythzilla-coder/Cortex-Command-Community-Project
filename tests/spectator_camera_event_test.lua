package.path = "Data/Base.rte/?.lua;" .. package.path

local CameraEventLogic = require("Activities/SpectatorCameraEventLogic")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function candidate(id, x, y, team, deathObserved)
    return { id = id, x = x, y = y, team = team, deathObserved = deathObserved ~= false }
end

local recentShot = {
    ageMS = 250,
    shooterTeam = 1,
    originX = 100,
    originY = 100,
    directionX = 1,
    directionY = 0
}

local selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(21, 300, 110, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected and selected.id, 21, "one recent forward enemy death should be attributed")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(21, 300, 110, 2), candidate(22, 340, 90, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "ambiguous deaths should not be attributed")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(21, 20, 100, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "death behind the shooter should not be attributed")

selected = CameraEventLogic.SelectEventCandidate(
    { ageMS = 700, shooterTeam = 1, originX = 100, originY = 100, directionX = 1, directionY = 0 },
    { candidate(21, 300, 100, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "stale shots should not be attributed")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(21, 300, 100, 2) },
    { [21] = true },
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "handled victim should not trigger twice")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(23, 180, 100, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "nearby deaths already visible with the shooter should not trigger a cut")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(24, 300, 100, 2, false) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "an unexplained disappearance without an observed death should not be attributed")

selected = CameraEventLogic.SelectEventCandidate(
    recentShot,
    { candidate(25, 300, 300, 2) },
    {},
    500,
    0.85,
    180,
    1200
)
assertEqual(selected, nil, "a death outside the narrow aim cone should not be attributed")

assertEqual(CameraEventLogic.HasLastSurvivorPriority(1, 4), true, "one team-1 survivor should suppress event cuts")
assertEqual(CameraEventLogic.HasLastSurvivorPriority(3, 1), true, "one team-2 survivor should suppress event cuts")
assertEqual(CameraEventLogic.HasLastSurvivorPriority(3, 4), false, "ordinary battles should allow event evaluation")
assertEqual(CameraEventLogic.SelectLastSurvivor({ 11 }, { 21, 22 }), 11, "team-1 last survivor should become the anchor")
assertEqual(CameraEventLogic.SelectLastSurvivor({ 11, 12 }, { 21 }), 21, "team-2 last survivor should become the anchor")
assertEqual(CameraEventLogic.SelectLastSurvivor({ 11 }, { 21 }), 11, "one-versus-one should deterministically prefer team 1")
assertEqual(CameraEventLogic.HasObservedDeath(false, true, true), true, "live-to-dead transition is strong death evidence")
assertEqual(CameraEventLogic.HasObservedDeath(true, false, false), true, "removal after observed death preserves death evidence")
assertEqual(CameraEventLogic.HasObservedDeath(false, false, false), false, "unexplained removal is not death evidence")
assertEqual(CameraEventLogic.HasObservedDeath(false, true, false), false, "a living actor is not a death event")

local engagementShot = {
    shooterTeam = 1,
    originX = 100,
    originY = 100,
    directionX = 1,
    directionY = 0
}

local engagementTarget = CameraEventLogic.SelectEngagementTarget(
    engagementShot,
    {
        { id = 21, team = 2, x = 900, y = 120 },
        { id = 22, team = 2, x = -300, y = 100 },
        { id = 23, team = 1, x = 700, y = 100 }
    },
    0.8,
    300,
    1200
)
assertEqual(engagementTarget.id, 21, "engagement framing selects the enemy in the firing direction")

engagementTarget = CameraEventLogic.SelectEngagementTarget(
    engagementShot,
    {
        { id = 24, team = 2, x = 180, y = 250 }
    },
    0.8,
    300,
    1200
)
assertEqual(engagementTarget, nil, "engagement framing ignores near targets")

local frame = CameraEventLogic.CalculateEngagementFrame(
    { x = 100, y = 100 },
    { x = 900, y = 300 },
    0.55
)
assertEqual(frame.x, 540, "engagement frame biases the camera toward the enemy")
assertEqual(frame.y, 210, "engagement frame preserves the line between actors")

print("spectator_camera_event_test: PASS")
