-- Per-fight and per-rest numbers, one JSON object per line, in the Script Extender folder.
local Util = Ext.Require("Shared/Util.lua")

local Telemetry = {}
Telemetry.__index = Telemetry

-- getCfg() returns the effective config; io/json as in Config.
function Telemetry.New(io, json, getCfg, log)
    local self = setmetatable({}, Telemetry)
    self.IO = io
    self.Json = json
    self.GetCfg = getCfg
    self.Log = log
    self.Lines = nil
    return self
end

function Telemetry:LoadLines(path)
    if self.Lines == nil or self.LinesPath ~= path then
        self.Lines = {}
        self.LinesPath = path
        local text = self.IO.Load(path)
        for line in string.gmatch(text or "", "[^\r\n]+") do
            self.Lines[#self.Lines + 1] = line
        end
    end
    return self.Lines
end

function Telemetry:Write(record)
    local cfg = self.GetCfg().Telemetry
    if not cfg.Enabled then
        return false
    end
    local ok, line = pcall(self.Json.Stringify, record, false)
    if not ok or type(line) ~= "string" then
        self.Log.Warn("telemetry: could not encode a record: " .. tostring(line))
        return false
    end
    line = string.gsub(line, "[\r\n]+", " ")
    local lines = self:LoadLines(cfg.File)
    lines[#lines + 1] = line
    local max = math.max(1, math.floor(cfg.MaxLines))
    if #lines > max then
        local keep = {}
        for i = #lines - max + 1, #lines do
            keep[#keep + 1] = lines[i]
        end
        self.Lines = keep
        lines = keep
    end
    return self.IO.Save(cfg.File, table.concat(lines, "\n") .. "\n")
end

-- Totals per character name over the whole file: fights, actions, XP and JP by source.
function Telemetry:Summary()
    local cfg = self.GetCfg().Telemetry
    local lines = self:LoadLines(cfg.File)
    local totals, order, fights, rests = {}, {}, 0, 0
    local function bucket(name)
        if not totals[name] then
            totals[name] = { Fights = 0, Actions = 0, XP = 0, JP = {} }
            order[#order + 1] = name
        end
        return totals[name]
    end
    for _, line in ipairs(lines) do
        local ok, rec = pcall(self.Json.Parse, line)
        if ok and type(rec) == "table" then
            if rec.t == "combat" then
                fights = fights + 1
                for _, c in pairs(rec.chars or {}) do
                    local b = bucket(c.name or "?")
                    b.Fights = b.Fights + 1
                    b.Actions = b.Actions + (c.actions or 0)
                    b.XP = b.XP + (c.xp or 0)
                    for src, v in pairs(c.jp or {}) do
                        b.JP[src] = (b.JP[src] or 0) + v
                    end
                end
                for _, c in pairs(rec.camp or {}) do
                    local b = bucket(c.name or "?")
                    b.JP.Camp = (b.JP.Camp or 0) + (c.jp or 0)
                end
            elseif rec.t == "rest" then
                rests = rests + 1
            end
        end
    end
    local out = { string.format("telemetry %s: %d fights, %d long rests logged", cfg.File, fights, rests) }
    table.sort(order)
    for _, name in ipairs(order) do
        local b = totals[name]
        local parts = {}
        for _, src in ipairs(Util.SortedKeys(b.JP)) do
            parts[#parts + 1] = src .. " " .. Util.Num(b.JP[src])
        end
        out[#out + 1] = string.format("  %s: %d fights, %d actions, %s XP in fights; JP %s", name, b.Fights, b.Actions,
            Util.Num(b.XP), table.concat(parts, ", "))
    end
    return out
end

return Telemetry
