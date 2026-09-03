SpectatorFireSensorDifferential = {}

local function emit(stage, fields)
    fields = fields or {}
    fields.stage = stage
    local parts = { "FIXTURE_F3" }
    for key, value in pairs(fields) do
        parts[#parts + 1] = key .. "=" .. tostring(value)
    end
    table.sort(parts)
    print(table.concat(parts, " "))
end

local function itemName(item)
    return item and item.PresetName or "NONE"
end

function SpectatorFireSensorDifferential:Persist(stage, fields, snapshot)
    fields = fields or {}
    fields.variant = "F3_DURABLE_FIRE_LATCH"
    fields.simTimeMS = self.Timer.ElapsedSimTimeMS
    fields.updateCount = self.UpdateCount
    emit(stage, fields)
    self.Telemetry.Emit("FIXTURE_F3", fields)
    if snapshot then
        self.Telemetry.Snapshot()
    end
end

function SpectatorFireSensorDifferential:StartActivity()
    self.Telemetry = require("Activities/SpectatorTelemetry")
    self.Telemetry.ConfigureRuntime("SPECTATOR_FIRE_F3_LOG.txt")
    self.Timer = Timer()
    self.UpdateCount = 0
    self:Persist("STARTED", {}, true)

    self.Shooter = CreateAHuman("Brain Robot", "Base.rte")
    self.Target = CreateAHuman("Brain Robot", "Base.rte")
    self.Weapon = CreateHDFirearm("SMG", "Base.rte")
    self:Persist("SETUP", {
        actorCreated = self.Shooter ~= nil and self.Target ~= nil,
        firearmCreated = self.Weapon ~= nil,
        firearmPreset = itemName(self.Weapon),
        firearmModule = self.Weapon and self.Weapon.ModuleID or -1
    }, true)
    if not self.Shooter or not self.Target or not self.Weapon then
        self:Persist("COMPLETE", { result = "FAIL", reason = "setup" }, true)
        self.Completed = true
        return
    end

    self.Shooter.Team = Activity.TEAM_1
    self.Target.Team = Activity.TEAM_2
    self.Shooter.Pos = SceneMan:MovePointToGround(Vector(1200, 0), 0, 3)
    self.Target.Pos = SceneMan:MovePointToGround(Vector(1450, 0), 0, 3)
    self.Shooter:AddInventoryItem(self.Weapon)
    self:Persist("INVENTORY_HANDOFF", {
        inventorySize = self.Shooter.InventorySize,
        foregroundPreset = itemName(self.Shooter.EquippedItem),
        weaponValid = self.Shooter.EquippedItem ~= nil
            and IsHDFirearm(self.Shooter.EquippedItem)
    }, true)

    MovableMan:AddActor(self.Shooter)
    MovableMan:AddActor(self.Target)
    self:Persist("ACTORS_INSERTED", {
        shooterValid = MovableMan:IsActor(self.Shooter),
        targetValid = MovableMan:IsActor(self.Target),
        foregroundPreset = itemName(self.Shooter.EquippedItem)
    }, true)

    self.AIController = require("Activities/SpectatorAIController").Create({
        mode = "SHADOW"
    })
    self.AIController:BeginRound(1, 1)
    self.AIController:RegisterActor(self.Shooter.UniqueID, self.Shooter.Team, 1)

    local firearm = ToHDFirearm(self.Shooter.EquippedItem)
    self.AmmoBefore = firearm.RoundInMagCount
    self.LastAmmo = self.AmmoBefore
    self.ShotCount = 0
    self.FalseFireIncrements = 0
    self.ReleaseUpdate = nil
    self:Persist("BEFORE_ACTIVATION", {
        ammo = self.AmmoBefore,
        roundsFired = firearm.RoundsFired,
        firedFrame = firearm.FiredFrame,
        fireEventCount = 0,
        weaponValid = true,
        isActivated = self.Shooter.EquippedItem:IsActivated()
    }, true)
    self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, true)
    self:Persist("ACTIVATION_REQUESTED", {}, true)
end

function SpectatorFireSensorDifferential:UpdateActivity()
    if self.Completed then
        return
    end

    self.UpdateCount = self.UpdateCount + 1
    if not self.ReleaseUpdate then
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, true)
    end

    local weapon = self.Shooter and self.Shooter.EquippedItem
    local firearm = weapon and IsHDFirearm(weapon) and ToHDFirearm(weapon) or nil
    local firedFrame = firearm and firearm.FiredFrame == true or false
    local roundsFired = firearm and firearm.RoundsFired or 0
    local ammo = firearm and firearm.RoundInMagCount or -1
    self.AIController:RecordFireSensorSample(
        self.Shooter.UniqueID,
        self.Timer.ElapsedSimTimeMS,
        firearm and firearm.ID or nil,
        firearm and firearm.RootID or nil,
        firedFrame,
        roundsFired,
        nil
    )
    local fireState = self.AIController:GetFireSensorState(self.Shooter.UniqueID)
    local fireEventCount = fireState and fireState.FireEventCount or 0
    if fireEventCount ~= self.ShotCount and not firedFrame then
        self.FalseFireIncrements = self.FalseFireIncrements + 1
    end

    local state = {
        foregroundPreset = itemName(weapon),
        weaponValid = weapon ~= nil,
        ammo = ammo,
        roundsFired = roundsFired,
        firedFrame = firedFrame,
        fireEventCount = fireEventCount,
        fireFrameCount = fireState and fireState.FireFrameCount or 0,
        roundsDischargedObserved = fireState and fireState.RoundsDischargedObserved or 0,
        lastFireTimeMS = fireState and fireState.LastFireTimeMS or nil,
        firedRecently = self.AIController:FiredRecently(
            self.Shooter.UniqueID,
            self.Timer.ElapsedSimTimeMS,
            1000
        )
    }
    self:Persist("SAMPLE_" .. self.UpdateCount, state, false)

    if ammo < self.LastAmmo then
        self.ShotCount = self.ShotCount + 1
        self:Persist("SHOT_" .. self.ShotCount, {
            ammoBefore = self.LastAmmo,
            ammoAfter = ammo,
            firedFrame = firedFrame,
            roundsFired = roundsFired,
            fireEventCount = fireEventCount,
            fireFrameCount = state.fireFrameCount,
            lastFireTimeMS = state.lastFireTimeMS
        }, true)
        if self.ShotCount >= 10 then
            self.ReleaseUpdate = self.UpdateCount
            self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, false)
        end
    end
    self.LastAmmo = ammo

    if self.ReleaseUpdate and self.UpdateCount >= self.ReleaseUpdate + 70 then
        local expired = not self.AIController:FiredRecently(
            self.Shooter.UniqueID,
            self.Timer.ElapsedSimTimeMS,
            1000
        )
        local pass = self.ShotCount == 10
            and state.fireFrameCount == 10
            and state.roundsDischargedObserved == 10
            and fireEventCount == 10
            and self.FalseFireIncrements == 0
            and state.lastFireTimeMS ~= nil
            and expired
        self:Persist("COMPLETE", {
            result = pass and "PASS" or "FAIL",
            confirmedShots = self.ShotCount,
            fireFrameCount = state.fireFrameCount,
            roundsDischargedObserved = state.roundsDischargedObserved,
            fireEventCount = fireEventCount,
            lastFireTimeMS = state.lastFireTimeMS,
            firedRecentlyAfterExpiry = not expired,
            falseFireIncrements = self.FalseFireIncrements
        }, true)
        self.Completed = true
    elseif self.UpdateCount >= 180 then
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, false)
        self:Persist("COMPLETE", {
            result = "FAIL",
            reason = "timeout",
            confirmedShots = self.ShotCount
        }, true)
        self.Completed = true
    end
end
