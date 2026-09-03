SpectatorSimProgressFixture = {}

function SpectatorSimProgressFixture:Checkpoint(stage)
    self.Telemetry.Emit("SIM_PROGRESS", {
        activityState = self.ActivityState,
        elapsedSimMS = self.Timer.ElapsedSimTimeMS,
        stage = stage,
        updateCount = self.UpdateCount
    })
    self.Telemetry.Snapshot()
end

function SpectatorSimProgressFixture:StartActivity()
    self.Telemetry = require("Activities/SpectatorTelemetry")
    self.Telemetry.ConfigureRuntime("SPECTATOR_SIM_PROGRESS_LOG.txt")
    self.Timer = Timer()
    self.UpdateCount = 0
    self:Checkpoint("START")
end

function SpectatorSimProgressFixture:UpdateActivity()
    self.UpdateCount = self.UpdateCount + 1
    if self.UpdateCount == 1 or self.UpdateCount == 2 or self.UpdateCount == 10 then
        self:Checkpoint("UPDATE_" .. self.UpdateCount)
    end
end
