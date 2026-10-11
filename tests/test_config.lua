-- Config: defaults, presets, overrides, validation, console-style edits, reload.
local S = {}

local function setup(w, Mocks)
    local Config = Ext.Require("Server/Config.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local Log = Ext.Require("Shared/Log.lua")
    local io = {
        Load = function(p)
            return w.files[p]
        end,
        Save = function(p, t)
            w.files[p] = t
            return true
        end,
    }
    local json = {
        Parse = Mocks.Json.decode,
        Stringify = function(v)
            return Mocks.Json.encode(v)
        end,
    }
    return Config.New(Data, io, json, Log), Data, Mocks.Json
end

function S.load_writes_defaults_when_missing(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    local ok, msg = cfg:Load()
    T.truthy(ok)
    T.contains(msg, "wrote default")
    local doc = json.decode(w.files["FFTJobs/config.json"])
    T.eq(doc.Preset, Data.DefaultPreset)
    T.eq(type(doc.Overrides), "table")
    local ref = json.decode(w.files["FFTJobs/config.reference.json"])
    T.truthy(#ref.Keys > 30, "every setting listed in the reference file")
    local found
    for _, row in ipairs(ref.Keys) do
        if row.Key == "JP.XPShare" then
            found = row
        end
    end
    T.truthy(found and found.Help, "keys carry help text")
    T.eq(cfg:Get("JP.XPShare"), Data.ConfigDefaults.JP.XPShare)
end

function S.preset_values_apply(w, T, Mocks)
    local cfg, Data = setup(w, Mocks)
    cfg:Load()
    local ok, msg = cfg:SetPreset("fast")
    T.truthy(ok, msg)
    T.eq(cfg.Preset, "Fast")
    T.eq(cfg:Get("JP.XPShare"), Data.Presets.Fast.Values.JP.XPShare)
    T.eq(cfg:Get("JP.Action.Base"), Data.ConfigDefaults.JP.Action.Base, "keys the preset does not set keep the default")
    ok = cfg:SetPreset("ultra")
    T.falsy(ok)
    T.eq(cfg.Preset, "Fast")
end

function S.overrides_apply_on_top_of_preset(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    w.files["FFTJobs/config.json"] = json.encode({ Preset = "Grindy", Overrides = { JP = { XPShare = 0.5 } } })
    T.truthy(cfg:Load())
    T.eq(cfg.Preset, "Grindy")
    T.eq(cfg:Get("JP.XPShare"), 0.5)
    T.eq(cfg:Get("JP.LongRest"), Data.Presets.Grindy.Values.JP.LongRest)
end

function S.invalid_values_fall_back_to_defaults(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    w.files["FFTJobs/config.json"] = json.encode({
        Preset = "Classic",
        Overrides = {
            JP = { XPShare = "lots", LongRest = -5, Action = { CountOutOfCombat = 3 } },
            JobLevels = { Thresholds = { 300, 200, 100, 1, 2, 3, 4 } },
        },
    })
    cfg:Load()
    T.eq(cfg:Get("JP.XPShare"), Data.ConfigDefaults.JP.XPShare)
    T.eq(cfg:Get("JP.LongRest"), Data.ConfigDefaults.JP.LongRest)
    T.eq(cfg:Get("JP.Action.CountOutOfCombat"), Data.ConfigDefaults.JP.Action.CountOutOfCombat)
    T.eq(cfg:Get("JobLevels.Thresholds")[1], 200)
    local warnings = 0
    for _, line in ipairs(w.prints) do
        if line:find("WARNING: config") then
            warnings = warnings + 1
        end
    end
    T.truthy(warnings >= 4, "each bad value is reported")
end

function S.unknown_preset_in_file_uses_default(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    w.files["FFTJobs/config.json"] = json.encode({ Preset = "Nightmare" })
    cfg:Load()
    T.eq(cfg.Preset, Data.DefaultPreset)
end

function S.invalid_json_keeps_previous_settings(w, T, Mocks)
    local cfg = setup(w, Mocks)
    cfg:Load()
    cfg:SetOverride("JP.XPShare", "0.33")
    w.files["FFTJobs/config.json"] = "{ not json"
    local ok, msg = cfg:Load()
    T.falsy(ok)
    T.contains(msg, "not valid JSON")
    T.eq(cfg:Get("JP.XPShare"), 0.33)
end

function S.set_override_parses_and_saves(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    cfg:Load()
    local ok, msg = cfg:SetOverride("jp.xpshare", "0.2")
    T.truthy(ok, msg)
    T.eq(msg, "JP.XPShare = 0.2")
    T.eq(json.decode(w.files["FFTJobs/config.json"]).Overrides.JP.XPShare, 0.2, "saved to config.json")
    T.truthy(cfg:SetOverride("JP.Action.CountOutOfCombat", "true"))
    T.eq(cfg:Get("JP.Action.CountOutOfCombat"), true)
    T.truthy(cfg:SetOverride("JobLevels.Thresholds", "100,200,300,400,500,600,700"))
    T.eq(cfg:Get("JobLevels.Thresholds")[7], 700)
    T.truthy(cfg:SetOverride("JP.Action.ExcludePrefixes", "Interrupt_, Throw_"))
    T.eq(cfg:Get("JP.Action.ExcludePrefixes")[2], "Throw_")
    T.truthy(cfg:SetOverride("Rules.StartingJob.ByClass.Monk", "Chemist"))
    T.eq(cfg:Get("Rules.StartingJob.ByClass").Monk, "Chemist")
    T.eq(cfg:Get("Rules.StartingJob.ByClass").Wizard, "Chemist", "other map entries kept")
    ok, msg = cfg:SetOverride("JP.Nope", "1")
    T.falsy(ok)
    T.contains(msg, "Unknown setting")
    ok, msg = cfg:SetOverride("JP", "1")
    T.falsy(ok)
    T.contains(msg, "group of settings")
    ok, msg = cfg:SetOverride("JP.XPShare", "-1")
    T.falsy(ok)
    ok, msg = cfg:SetOverride("JP.Action.CountOutOfCombat", "maybe")
    T.falsy(ok)
    T.contains(msg, "true or false")
    ok, msg = cfg:SetOverride("JobLevels.Thresholds", "5,4,3,2,1,0,0")
    T.truthy(ok)
    T.contains(msg, "using the default", "a bad list is reported and replaced")
end

function S.clear_override_returns_to_preset(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    cfg:Load()
    cfg:SetOverride("JP.Victory.Base", "99")
    T.eq(cfg:Get("JP.Victory.Base"), 99)
    T.truthy(cfg:ClearOverride("jp.victory.base"))
    T.eq(cfg:Get("JP.Victory.Base"), Data.ConfigDefaults.JP.Victory.Base)
    T.eq(next(cfg.Overrides), nil, "empty parent tables are pruned")
end

function S.reload_picks_up_file_edits(w, T, Mocks)
    local cfg, Data, json = setup(w, Mocks)
    cfg:Load()
    local doc = json.decode(w.files["FFTJobs/config.json"])
    doc.Preset = "PureFFT"
    doc.Overrides = { JP = { GlobalMultiplier = 3 } }
    w.files["FFTJobs/config.json"] = json.encode(doc)
    T.truthy(cfg:Load())
    T.eq(cfg.Preset, "PureFFT")
    T.eq(cfg:Get("JP.XPShare"), 0)
    T.eq(cfg:Get("JP.Shared.Share"), 0, "PureFFT has no shared learning")
    T.eq(cfg:Get("JP.GlobalMultiplier"), 3)
end

function S.shared_learning_settings_are_validated(w, T, Mocks)
    local cfg, Data = setup(w, Mocks)
    cfg:Load()
    T.eq(cfg:Get("JP.Shared.Share"), Data.ConfigDefaults.JP.Shared.Share)
    T.eq(cfg:Get("JP.Shared.Scope"), "FightJobs", "the default is Fell Seal's rule")
    local ok, msg = cfg:SetOverride("jp.shared.scope", "alljobs")
    T.truthy(ok, msg)
    T.eq(cfg:Get("JP.Shared.Scope"), "AllJobs", "any spelling of a valid scope")
    ok, msg = cfg:SetOverride("JP.Shared.Scope", "everyone")
    T.truthy(ok)
    T.contains(msg, "must be FightJobs or AllJobs")
    T.eq(cfg:Get("JP.Shared.Scope"), "FightJobs")
    T.truthy(cfg:SetOverride("JP.Shared.Sources.XP", "false"))
    T.eq(cfg:Get("JP.Shared.Sources.XP"), false)
    T.eq(cfg:Get("JP.Shared.Sources.Action"), true, "the other sources keep their value")
end

function S.flatten_lists_leaves_only(w, T, Mocks)
    local cfg = setup(w, Mocks)
    cfg:Load()
    local keys = {}
    for _, row in ipairs(cfg:Flatten()) do
        keys[row.Key] = true
    end
    T.truthy(keys["JP.Action.Base"])
    T.truthy(keys["JobLevels.Thresholds"])
    T.truthy(keys["Rules.StartingJob.ByClass"])
    T.falsy(keys["JP.Action"], "groups are not leaves")
end

return S
