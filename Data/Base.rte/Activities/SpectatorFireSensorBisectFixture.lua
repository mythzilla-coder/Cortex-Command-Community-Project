SpectatorFireSensorBisectFixture = {}

-- Change only this harness constant between native runs.  Do not ship this
-- activity as gameplay behavior; it exists to isolate the firearm boundary.
local VARIANT = "B1_ACTOR_ONLY"

local VARIANT_ORDER = {
    B1_ACTOR_ONLY = 1,
    B2_ACTOR_INSERTED = 2,
    B3_SHOOTER_TARGET = 3,
    B4_DETACHED_FIREARM = 4,
    B5A_PRE_INSERTION = 5,
    B5B_POST_INSERTION = 5,
    B6_EQUIPPED_STABLE = 6,
    B7_CONTROLLED_FIRE = 7
}

local function itemName(item)
    return item and item.PresetName or "NONE"
end

function SpectatorFireSensorBisectFixture:Valid(actor)
    return actor ~= nil and MovableMan:IsActor(actor)
end

function SpectatorFireSensorBisectFixture:Checkpoint(stage, result, extra, snapshot)
    local weapon = self.Shooter and self.Shooter.EquippedItem
    local fields = {
        variant = VARIANT,
        stage = stage,
        updateCount = self.UpdateCount,
        simTimeMS = self.Timer.ElapsedSimTimeMS,
        shooterValid = self:Valid(self.Shooter),
        targetValid = self:Valid(self.Target),
        weaponCreated = self.Weapon ~= nil,
        weaponAttached = self.Weapon ~= nil and self.Shooter ~= nil and weapon == self.Weapon,
        foregroundPreset = itemName(weapon),
        lastPhase = stage,
        result = result or "PENDING"
    }
    if extra then
        for key, value in pairs(extra) do
            fields[key] = value
        end
    end
    self.LastPhase = stage
    self.LastResult = fields.result
    self.Telemetry.Emit("FIXTURE_BISECT", fields)
    if snapshot ~= false then
        self.Telemetry.Snapshot()
    end
end

function SpectatorFireSensorBisectFixture:StartActivity()
    self.Telemetry = require("Activities/SpectatorTelemetry")
    self.Telemetry.ConfigureRuntime("SPECTATOR_FIRE_BISECT_" .. VARIANT .. "_LOG.txt")
    self.Timer = Timer()
    self.UpdateCount = 0
    self.LastPhase = "STARTED"
    self.LastResult = "PENDING"
    local level = VARIANT_ORDER[VARIANT]
    if not level then
        self:Checkpoint("CONFIG_ERROR", "ERROR", { reason = "unknown_variant" })
        self.Completed = true
        return
    end
    self:Checkpoint("STARTED", "PENDING")

    self.Shooter = CreateAHuman("Brain Robot", "Base.rte")
    self:Checkpoint("SHOOTER_CREATED", self.Shooter and "PENDING" or "ERROR", {
        actorCreated = self.Shooter ~= nil
    })
    if level >= 3 then
        self.Target = CreateAHuman("Brain Robot", "Base.rte")
        self:Checkpoint("TARGET_CREATED", self.Target and "PENDING" or "ERROR", {
            actorCreated = self.Target ~= nil
        })
    end
    if level >= 4 then
        self.Weapon = CreateHDFirearm("SMG", "Base.rte")
        self:Checkpoint("WEAPON_CREATED", self.Weapon and "PENDING" or "ERROR", {
            weaponPreset = itemName(self.Weapon),
            weaponModule = self.Weapon and self.Weapon.ModuleID or -1
        })
    end
    if level >= 2 and self.Shooter then
        self.Shooter.Team = Activity.TEAM_1
        self.Shooter.Pos = SceneMan:MovePointToGround(Vector(1200, 0), 0, 3)
    end
    if level >= 3 and self.Target then
        self.Target.Team = Activity.TEAM_2
        self.Target.Pos = SceneMan:MovePointToGround(Vector(1450, 0), 0, 3)
    end
    local preInsertionHandoff = VARIANT == "B5A_PRE_INSERTION" or VARIANT == "B6_EQUIPPED_STABLE"
    local function handoff()
        self:Checkpoint(VARIANT .. "_BEFORE_ADD_INVENTORY", "PENDING")
        self.Shooter:AddInventoryItem(self.Weapon)
        self:Checkpoint(VARIANT .. "_AFTER_ADD_INVENTORY", "PENDING", {
            inventorySize = self.Shooter.InventorySize
        })
    end
    if preInsertionHandoff and self.Shooter and self.Weapon then
        handoff()
    end
    if level >= 2 and self.Shooter then
        self:Checkpoint(VARIANT .. "_BEFORE_ADD_ACTOR", "PENDING")
        MovableMan:AddActor(self.Shooter)
        self:Checkpoint(VARIANT .. "_AFTER_ADD_ACTOR", "PENDING", {
            shooterMOID = self.Shooter.MOID,
            shooterUniqueID = self.Shooter.UniqueID,
            shooterX = self.Shooter.Pos.X,
            shooterY = self.Shooter.Pos.Y
        })
    end
    if level >= 3 and self.Target then
        MovableMan:AddActor(self.Target)
        self:Checkpoint("TARGET_INSERTED", "PENDING", {
            targetMOID = self.Target.MOID,
            targetUniqueID = self.Target.UniqueID
        })
    end
    if level >= 5 and not preInsertionHandoff and self.Shooter and self.Weapon then
        handoff()
    end
    self:Checkpoint("SETUP_COMPLETE", "PENDING")
end

function SpectatorFireSensorBisectFixture:UpdateActivity()
    if self.Completed then
        return
    end
    self.UpdateCount = self.UpdateCount + 1
    if self.UpdateCount == 1 or self.UpdateCount == 2 or self.UpdateCount == 10 or self.UpdateCount == 60 then
        self:Checkpoint("UPDATE_" .. self.UpdateCount, "PENDING", nil, self.UpdateCount ~= 10)
    end
    if self.UpdateCount == 60 then
        local level = VARIANT_ORDER[VARIANT]
        if level < 7 then
            self:Checkpoint("PASS", "PASS")
            self.Completed = true
        end
    elseif VARIANT == "B7_CONTROLLED_FIRE" and self.UpdateCount == 61 then
        self:Checkpoint("FIRE_REQUESTED", "PENDING")
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, true)
    elseif VARIANT == "B7_CONTROLLED_FIRE" and self.UpdateCount == 62 then
        local weapon = self.Shooter and self.Shooter.EquippedItem
        self:Checkpoint("FIRE_OBSERVED", "PASS", {
            firedFrame = weapon and IsHDFirearm(weapon) and ToHDFirearm(weapon).FiredFrame or false,
            roundsFired = weapon and IsHDFirearm(weapon) and ToHDFirearm(weapon).RoundsFired or 0,
            activated = weapon and weapon:IsActivated() or false
        })
        self.Shooter:GetController():SetState(Controller.WEAPON_FIRE, false)
        self.Completed = true
    end
end
