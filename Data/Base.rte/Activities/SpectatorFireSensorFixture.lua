SpectatorFireSensorFixture = {}

local function emit(fields)
    local parts = { "FIXTURE_FIRE_SENSOR" }
    for key, value in pairs(fields) do
        parts[#parts + 1] = key .. "=" .. tostring(value)
    end
    table.sort(parts)
    print(table.concat(parts, " "))
end

local function itemName(item)
    return item and item.PresetName or "NONE"
end

function SpectatorFireSensorFixture:Checkpoint(stage, fields)
    fields = fields or {}
    fields.stage = stage
    self.Telemetry.Emit("FIXTURE_PHASE", fields)
    self.Telemetry.Snapshot()
end

function SpectatorFireSensorFixture:Sample(stage)
    local weapon = self.Shooter and self.Shooter.EquippedItem
    local targetHealth = self.Target and self.Target.Health or -1
    emit({
        stage = stage,
        shooter = self.Shooter and self.Shooter.UniqueID or -1,
        shooterValid = self.Shooter and MovableMan:IsActor(self.Shooter),
        inventory = self.Shooter and self.Shooter.InventorySize or -1,
        foreground = itemName(weapon),
        firearm = weapon and IsHDFirearm(weapon),
        firedFrame = weapon and IsHDFirearm(weapon) and ToHDFirearm(weapon).FiredFrame or false,
        roundsFired = weapon and IsHDFirearm(weapon) and ToHDFirearm(weapon).RoundsFired or 0,
        activated = weapon and weapon:IsActivated() or false,
        targetHealth = targetHealth,
        targetDelta = self.InitialTargetHealth and self.InitialTargetHealth - targetHealth or 0
    })
end

function SpectatorFireSensorFixture:StartActivity()
    self.Telemetry = require("Activities/SpectatorTelemetry")
    self.Telemetry.ConfigureRuntime("SPECTATOR_FIRE_SENSOR_FIXTURE_LOG.txt")
    self.Telemetry.Emit("FIXTURE_CREATE_ENTERED", { activity = "SpectatorFireSensorFixture" })
    self.Telemetry.Snapshot()
    self.Timer = Timer()
    self.Fired = false
    self.Completed = false
    self:Checkpoint("SHOOTER_CREATE_REQUESTED")
    self.Shooter = CreateAHuman("Brain Robot", "Base.rte")
    self:Checkpoint("SHOOTER_CREATED", { success = self.Shooter ~= nil })
    self:Checkpoint("TARGET_CREATE_REQUESTED")
    self.Target = CreateAHuman("Brain Robot", "Base.rte")
    self:Checkpoint("TARGET_CREATED", { success = self.Target ~= nil })
    self:Checkpoint("WEAPON_CREATE_REQUESTED")
    self.Weapon = CreateHDFirearm("SMG", "Base.rte")
    self:Checkpoint("WEAPON_CREATED", { success = self.Weapon ~= nil })
    emit({ stage = "CREATED", shooter = self.Shooter ~= nil, target = self.Target ~= nil, weapon = self.Weapon ~= nil,
        weaponPreset = self.Weapon and self.Weapon.PresetName or "NONE", weaponModule = self.Weapon and self.Weapon.ModuleID or -1 })
    if not self.Shooter or not self.Target or not self.Weapon then return end
    self:Checkpoint("ACTORS_INITIALIZING")
    self.Shooter.Team = Activity.TEAM_1
    self.Target.Team = Activity.TEAM_2
    self.Shooter.Pos = SceneMan:MovePointToGround(Vector(1200, 0), 0, 3)
    self.Target.Pos = SceneMan:MovePointToGround(Vector(1450, 0), 0, 3)
    self:Checkpoint("POSITIONS_ASSIGNED")
    self.Shooter:AddInventoryItem(self.Weapon)
    self:Checkpoint("WEAPON_ADDED", { inventory = self.Shooter.InventorySize })
    self:Sample("AFTER_ADD")
    MovableMan:AddActor(self.Shooter)
    MovableMan:AddActor(self.Target)
    self:Checkpoint("ACTORS_INSERTED", { shooterValid = MovableMan:IsActor(self.Shooter), targetValid = MovableMan:IsActor(self.Target) })
    self.InitialTargetHealth = self.Target.Health
    self:Sample("AFTER_INSERT")
end

function SpectatorFireSensorFixture:UpdateActivity()
    if self.Completed or not self.Shooter or not MovableMan:IsActor(self.Shooter) then return end
    if not self.UpdateEntered then
        self.UpdateEntered = true
        self:Checkpoint("UPDATE_ENTERED", { elapsedSimMS = self.Timer.ElapsedSimTimeMS })
    end
    if self.Timer:IsPastSimMS(500) and not self.Fired then
        self:Sample("BEFORE_FIRE")
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, true)
        self.Fired = true
    elseif self.Fired and self.Timer:IsPastSimMS(850) then
        self:Sample("DURING_FIRE")
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, false)
    elseif self.Fired and self.Timer:IsPastSimMS(1200) then
        self:Sample("AFTER_FIRE")
        emit({ stage = "COMPLETE", reason = "bounded_fixture_finished" })
        self.Telemetry.Snapshot()
        self.Completed = true
    end
end
