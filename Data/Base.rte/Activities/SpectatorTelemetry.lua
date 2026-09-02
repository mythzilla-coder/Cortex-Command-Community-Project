local Telemetry = {}
local runtimeLogPath

local fieldOrder = {
    "round", "state", "team1", "team2", "team1Alive", "team2Alive",
    "winner", "durationMS", "team1Score", "team2Score", "reason"
}

local function scalar(value)
    local text = tostring(value)
    return string.gsub(text, "[^%w%._%-]", "_")
end

function Telemetry.ConfigureRuntime(path)
    runtimeLogPath = path
end

function Telemetry.Snapshot(path)
    local snapshotPath = path or runtimeLogPath
    if not snapshotPath or not ConsoleMan or not ConsoleMan.SaveAllText then
        return false
    end

    ConsoleMan:SaveAllText(snapshotPath)
    return true
end

function Telemetry.Encode(event, fields)
    local parts = { "SPECTATOR_EVENT", "event=" .. scalar(event) }
    local used = {}
    for _, key in ipairs(fieldOrder) do
        if fields and fields[key] ~= nil then
            parts[#parts + 1] = key .. "=" .. scalar(fields[key])
            used[key] = true
        end
    end
    if fields then
        local extras = {}
        for key in pairs(fields) do
            if not used[key] then extras[#extras + 1] = key end
        end
        table.sort(extras)
        for _, key in ipairs(extras) do
            parts[#parts + 1] = key .. "=" .. scalar(fields[key])
        end
    end
    return table.concat(parts, " ")
end

function Telemetry.Emit(event, fields, sink)
    local line = Telemetry.Encode(event, fields)
    if sink then
        sink(line)
    else
        print(line)
    end
    return line
end

return Telemetry
