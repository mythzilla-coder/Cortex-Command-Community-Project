local CameraEventLogic = {}

function CameraEventLogic.HasLastSurvivorPriority(team1Count, team2Count)
    return team1Count == 1 or team2Count == 1
end

function CameraEventLogic.SelectLastSurvivor(team1Actors, team2Actors)
    if #team1Actors == 1 then
        return team1Actors[1]
    end
    if #team2Actors == 1 then
        return team2Actors[1]
    end
    return nil
end

function CameraEventLogic.HasObservedDeath(previouslyDead, currentlyPresent, currentlyDead)
    return (currentlyPresent and not previouslyDead and currentlyDead)
        or (not currentlyPresent and previouslyDead)
end

function CameraEventLogic.SelectEventCandidate(shot, disappearedActors, handledVictims, recentFireWindowMS, minimumAimDot, minimumRange, maximumRange)
    if not shot or shot.ageMS < 0 or shot.ageMS > recentFireWindowMS then
        return nil
    end

    local directionLength = math.sqrt((shot.directionX * shot.directionX) + (shot.directionY * shot.directionY))
    if directionLength <= 0 then
        return nil
    end

    local plausible = nil
    local plausibleCount = 0

    for _, actor in ipairs(disappearedActors) do
        if actor.team ~= shot.shooterTeam and actor.deathObserved and not handledVictims[actor.id] then
            local offsetX = actor.x - shot.originX
            local offsetY = actor.y - shot.originY
            local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

            if distance >= minimumRange and distance <= maximumRange then
                local aimDot = ((offsetX * shot.directionX) + (offsetY * shot.directionY)) / (distance * directionLength)
                if aimDot >= minimumAimDot then
                    plausible = actor
                    plausibleCount = plausibleCount + 1
                end
            end
        end
    end

    if plausibleCount == 1 then
        return plausible
    end

    return nil
end

function CameraEventLogic.SelectEngagementTarget(shot, actors, minimumAimDot, minimumRange, maximumRange)
    if not shot then
        return nil
    end

    local directionLength = math.sqrt((shot.directionX * shot.directionX) + (shot.directionY * shot.directionY))
    if directionLength <= 0 then
        return nil
    end

    local selected = nil
    local selectedDistance = math.huge

    for _, actor in ipairs(actors) do
        if actor.team ~= shot.shooterTeam then
            local offsetX = actor.x - shot.originX
            local offsetY = actor.y - shot.originY
            local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

            if distance >= minimumRange and distance <= maximumRange then
                local aimDot = ((offsetX * shot.directionX) + (offsetY * shot.directionY)) / (distance * directionLength)
                if aimDot >= minimumAimDot and distance < selectedDistance then
                    selected = actor
                    selectedDistance = distance
                end
            end
        end
    end

    return selected
end

function CameraEventLogic.CalculateEngagementFrame(shooter, enemy, enemyBias)
    local bias = math.max(0, math.min(1, enemyBias or 0.5))
    local deltaX = enemy.x - shooter.x
    local deltaY = enemy.y - shooter.y

    return {
        x = shooter.x + (deltaX * bias),
        y = shooter.y + (deltaY * bias)
    }
end

return CameraEventLogic
