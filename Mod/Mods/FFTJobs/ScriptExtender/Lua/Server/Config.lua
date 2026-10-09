-- JP config: defaults (GeneratedData) <- preset <- overrides from config.json in the Script Extender folder.
local Util = Ext.Require("Shared/Util.lua")

local Config = {}
Config.__index = Config

Config.Path = "FFTJobs/config.json"
Config.ReferencePath = "FFTJobs/config.reference.json"

-- io = {Load(path) -> text|nil, Save(path, text) -> bool}, json = {Parse(text), Stringify(value, pretty)}
function Config.New(data, io, json, log)
    local self = setmetatable({}, Config)
    self.Data = data
    self.IO = io
    self.Json = json
    self.Log = log
    self.Preset = data.DefaultPreset
    self.Overrides = {}
    self.Values = nil
    self:Recompute()
    return self
end

function Config:Effective()
    return self.Values
end

function Config:Get(path)
    return Util.GetPath(self.Values, path)
end

-- Values whose type differs from the default, or negative/NaN numbers, fall back to the default.
local function sanitize(value, default, path, warnings)
    if value == nil then
        return Util.DeepCopy(default)
    end
    if type(value) ~= type(default) then
        warnings[#warnings + 1] = string.format("%s: expected %s, got %s; using the default", path, type(default), type(value))
        return Util.DeepCopy(default)
    end
    if type(default) == "number" then
        if value ~= value or value < 0 or value == math.huge then
            warnings[#warnings + 1] = path .. ": must be a number >= 0; using the default"
            return default
        end
        return value
    end
    if type(default) ~= "table" then
        return value
    end
    if Util.IsArray(default) or next(default) == nil then
        local elemType = default[1] and type(default[1])
        for i, x in ipairs(value) do
            if elemType and type(x) ~= elemType then
                warnings[#warnings + 1] = string.format("%s[%d]: expected %s; using the default list", path, i, elemType)
                return Util.DeepCopy(default)
            end
        end
        return value
    end
    local out = {}
    for k, x in pairs(value) do
        out[k] = x -- keeps map entries that have no default, e.g. Rules.StartingJob.ByClass.Monk
    end
    for k, d in pairs(default) do
        out[k] = sanitize(value[k], d, path .. "." .. k, warnings)
    end
    return out
end

function Config:Recompute()
    local data = self.Data
    local preset = data.Presets[self.Preset]
    if not preset then
        self.Preset = data.DefaultPreset
        preset = data.Presets[self.Preset]
    end
    local merged = Util.DeepMerge(Util.DeepMerge(data.ConfigDefaults, preset.Values), self.Overrides)
    local warnings = {}
    local values = sanitize(merged, data.ConfigDefaults, "config", warnings)
    local th = values.JobLevels.Thresholds
    local okTh = #th == #data.ConfigDefaults.JobLevels.Thresholds
    for i = 2, #th do
        if th[i] <= th[i - 1] then
            okTh = false
        end
    end
    if not okTh then
        warnings[#warnings + 1] = "JobLevels.Thresholds must be 7 increasing numbers; using the default"
        values.JobLevels.Thresholds = Util.DeepCopy(data.ConfigDefaults.JobLevels.Thresholds)
    end
    self.Values = values
    for _, w in ipairs(warnings) do
        if self.Log then
            self.Log.Warn("config " .. w)
        end
    end
    return warnings
end

-- Reads config.json; writes it with defaults when it does not exist. Returns ok, message.
function Config:Load()
    local text = self.IO.Load(Config.Path)
    if text == nil or text == "" then
        self.Preset = self.Data.DefaultPreset
        self.Overrides = {}
        self:Recompute()
        self:Save()
        return true, "wrote default " .. Config.Path
    end
    local ok, parsed = pcall(self.Json.Parse, text)
    if not ok or type(parsed) ~= "table" then
        self:Recompute()
        return false, Config.Path .. " is not valid JSON; keeping the previous settings"
    end
    local preset = parsed.Preset
    if type(preset) ~= "string" or not self.Data.Presets[preset] then
        if preset ~= nil and self.Log then
            self.Log.Warn("config: unknown preset " .. tostring(preset) .. "; using " .. self.Data.DefaultPreset)
        end
        preset = self.Data.DefaultPreset
    end
    self.Preset = preset
    self.Overrides = type(parsed.Overrides) == "table" and parsed.Overrides or {}
    self:Recompute()
    self:SaveReference()
    return true, "loaded " .. Config.Path .. " (preset " .. self.Preset .. ")"
end

function Config:Save()
    local doc = {
        Preset = self.Preset,
        Overrides = self.Overrides,
        Help = "Preset: one of " .. table.concat(self.Data.PresetOrder, ", ")
            .. ". Overrides: any key from config.reference.json, nested, e.g. {\"JP\": {\"XPShare\": 0.2}}."
            .. " Reload in game with !fft_reload.",
    }
    local ok = self.IO.Save(Config.Path, self.Json.Stringify(doc, true))
    self:SaveReference()
    return ok
end

-- Flat list of every leaf key with its effective value, default and help text.
function Config:Flatten()
    local rows = {}
    local function walk(default, prefix)
        for _, k in ipairs(Util.SortedKeys(default)) do
            local d = default[k]
            local path = prefix == "" and k or (prefix .. "." .. k)
            if type(d) == "table" and not Util.IsArray(d) and next(d) ~= nil and path ~= "Rules.StartingJob.ByClass" then
                walk(d, path)
            else
                rows[#rows + 1] = {
                    Key = path,
                    Value = Util.GetPath(self.Values, path),
                    Default = d,
                    Help = self.Data.ConfigHelp[path],
                }
            end
        end
    end
    walk(self.Data.ConfigDefaults, "")
    return rows
end

function Config:SaveReference()
    local presets = {}
    for _, name in ipairs(self.Data.PresetOrder) do
        presets[name] = { Description = self.Data.Presets[name].Description, Values = self.Data.Presets[name].Values }
    end
    local doc = {
        Note = "Reference only (rewritten on every load): edit config.json instead.",
        Preset = self.Preset,
        Presets = presets,
        Keys = self:Flatten(),
    }
    return self.IO.Save(Config.ReferencePath, self.Json.Stringify(doc, true))
end

-- Case-insensitive match of a dotted path against the default config's keys ("jp.xpshare" -> "JP.XPShare").
function Config:ResolvePath(path)
    local cur = self.Data.ConfigDefaults
    local out = {}
    local parts = Util.SplitPath(path or "")
    if #parts == 0 then
        return nil
    end
    for i, p in ipairs(parts) do
        if type(cur) ~= "table" or Util.IsArray(cur) then
            return nil
        end
        local found
        for k in pairs(cur) do
            if string.lower(k) == string.lower(p) then
                found = k
            end
        end
        if not found then
            if i == #parts and table.concat(out, ".") == "Rules.StartingJob.ByClass" then
                found = p -- new class name in the ByClass map
            else
                return nil
            end
        end
        out[#out + 1] = found
        cur = cur[found]
    end
    return table.concat(out, ".")
end

-- Parses text into the type of the default at path. Returns value or nil, error.
function Config:ParseValue(path, text)
    local default = Util.GetPath(self.Data.ConfigDefaults, path)
    if default == nil and string.find(path, "^Rules%.StartingJob%.ByClass%.") then
        default = ""
    end
    if type(default) == "number" then
        local n = tonumber(text)
        if not n or n < 0 then
            return nil, path .. " needs a number >= 0"
        end
        return n
    elseif type(default) == "boolean" then
        local b = Util.ParseBool(text)
        if b == nil then
            return nil, path .. " needs true or false"
        end
        return b
    elseif type(default) == "string" then
        return Util.Trim(text)
    elseif type(default) == "table" and (Util.IsArray(default) or next(default) == nil) then
        local list = {}
        local elemType = default[1] and type(default[1]) or "string"
        for item in string.gmatch(text or "", "[^,%s]+") do
            if elemType == "number" then
                local n = tonumber(item)
                if not n then
                    return nil, path .. " needs a comma-separated list of numbers"
                end
                list[#list + 1] = n
            else
                list[#list + 1] = item
            end
        end
        return list
    end
    return nil, path .. " is a group of settings; set one of its keys instead"
end

-- Sets an override (saved to config.json). Returns ok, message.
function Config:SetOverride(path, text)
    local resolved = self:ResolvePath(path)
    if not resolved then
        return false, "Unknown setting " .. tostring(path) .. " (see config.reference.json)"
    end
    local value, err = self:ParseValue(resolved, text)
    if value == nil then
        return false, err
    end
    Util.SetPath(self.Overrides, resolved, value)
    local warnings = self:Recompute()
    self:Save()
    local effective = Util.GetPath(self.Values, resolved)
    local shown = type(effective) == "table" and Util.Join(effective) or tostring(effective)
    local msg = resolved .. " = " .. shown
    if #warnings > 0 then
        msg = msg .. " (" .. warnings[1] .. ")"
    end
    return true, msg
end

function Config:ClearOverride(path)
    local resolved = self:ResolvePath(path)
    if not resolved then
        return false, "Unknown setting " .. tostring(path)
    end
    Util.ClearPath(self.Overrides, resolved)
    self:Recompute()
    self:Save()
    return true, resolved .. " back to the preset value " .. tostring(Util.GetPath(self.Values, resolved))
end

function Config:SetPreset(name)
    for _, p in ipairs(self.Data.PresetOrder) do
        if string.lower(p) == string.lower(name or "") then
            self.Preset = p
            self:Recompute()
            self:Save()
            local msg = "preset " .. p .. ": " .. (self.Data.Presets[p].Description or "")
            if next(self.Overrides) ~= nil then
                msg = msg .. " (your overrides in config.json still apply on top)"
            end
            return true, msg
        end
    end
    return false, "Unknown preset " .. tostring(name) .. " (" .. table.concat(self.Data.PresetOrder, ", ") .. ")"
end

return Config
