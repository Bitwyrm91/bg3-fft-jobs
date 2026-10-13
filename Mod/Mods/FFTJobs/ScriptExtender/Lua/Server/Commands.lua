-- SE console commands (type them in the Script Extender console, server context): !fft_help
local Util = Ext.Require("Shared/Util.lua")
local Rules = Ext.Require("Server/Rules.lua")
local Bosses = Ext.Require("Server/Bosses.lua")

local Commands = {}

-- Each handler gets (svc, args) and returns a list of output lines.
local H = {}
local HELP = {}

local function def(name, usage, fn)
    H[name] = fn
    HELP[#HELP + 1] = { name, usage }
end

local function who(svc, text)
    local guid, err = svc:ResolveWho(text)
    return guid, err
end

local function result(ok, msg)
    return { (ok and "" or "Not done: ") .. tostring(msg) }
end

-- Grants depend on the config too (Test.Tools), so a config change is applied to every party member at once.
local function regrant(svc)
    if svc.Ready then
        svc:ReconcileAll(false)
    end
end

def("fft_help", "list the commands", function()
    local out = { "FFT job system commands (who = host, a party member's name, or a GUID):" }
    for _, h in ipairs(HELP) do
        out[#out + 1] = string.format("  !%-14s %s", h[1], h[2])
    end
    return out
end)

def("fft_party", "one line per party member", function(svc)
    if not svc.Ready then
        return { "The job system has not loaded yet" }
    end
    local out = {}
    for _, guid in ipairs(svc.State:Guids()) do
        out[#out + 1] = svc:SummaryLine(guid)
    end
    if #out == 0 then
        out[1] = "No party members tracked yet"
    end
    return out
end)

def("fft_status", "[who]  jobs, JP and slots", function(svc, args)
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    return svc:Describe(guid)
end)

def("fft_board", "[who]  open the Job Board window", function(svc, args)
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    return result(svc:OpenBoard(guid))
end)

def("fft_job", "<job> [who]  set the primary job", function(svc, args)
    local jobId = Rules.FindJob(svc.Data, args[1])
    if not jobId then
        return { "Unknown job " .. tostring(args[1]) }
    end
    local guid, err = who(svc, args[2])
    if not guid then
        return { err }
    end
    return result(svc:SetPrimary(guid, jobId))
end)

def("fft_secondary", "<job|none> [who]  set the secondary skill set", function(svc, args)
    local jobId
    if Util.Normalize(args[1]) ~= "none" then
        jobId = Rules.FindJob(svc.Data, args[1])
        if not jobId then
            return { "Unknown job " .. tostring(args[1]) }
        end
    end
    local guid, err = who(svc, args[2])
    if not guid then
        return { err }
    end
    return result(svc:SetSecondary(guid, jobId))
end)

def("fft_learn", "<ability> [who]  learn an ability (write names without spaces: Aim1, XPotion, PhoenixDown)", function(svc, args)
    local aid = Rules.FindAbility(svc.Data, args[1])
    if not aid then
        return { "Unknown ability " .. tostring(args[1]) }
    end
    local guid, err = who(svc, args[2])
    if not guid then
        return { err }
    end
    return result(svc:Learn(guid, aid))
end)

def("fft_equip", "<ability> [1|2] [who]  put a learned ability in its slot (reaction, or passive slot 1/2)", function(svc, args)
    local aid = Rules.FindAbility(svc.Data, args[1])
    if not aid then
        return { "Unknown ability " .. tostring(args[1]) }
    end
    local slot, whoArg = nil, args[2]
    if args[2] == "1" or args[2] == "2" then
        slot, whoArg = args[2], args[3]
    end
    local guid, err = who(svc, whoArg)
    if not guid then
        return { err }
    end
    return result(svc:Equip(guid, aid, slot))
end)

def("fft_unequip", "<reaction|1|2> [who]  clear a slot (1 and 2 are the passive slots)", function(svc, args)
    local guid, err = who(svc, args[2])
    if not guid then
        return { err }
    end
    return result(svc:Unequip(guid, args[1]))
end)

def("fft_addjp", "<amount> [job] [who]  add JP (default: the primary job)", function(svc, args)
    local amount = tonumber(args[1])
    if not amount then
        return { "Usage: !fft_addjp <amount> [job] [who]" }
    end
    local jobId = args[2] and Rules.FindJob(svc.Data, args[2])
    local whoArg = jobId and args[3] or args[2]
    local guid, err = who(svc, whoArg)
    if not guid then
        return { err }
    end
    return result(svc:AddManualJP(guid, amount, jobId))
end)

def("fft_unlockall", "[who]  unlock every implemented job (testing)", function(svc, args)
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    return result(svc:UnlockAll(guid))
end)

def("fft_badge", "<badge|list>  give the party a badge (testing; special jobs need one plus job levels)", function(svc, args)
    local data = svc.Data
    if not args[1] or string.lower(args[1]) == "list" then
        local out = Bosses.Lines(svc)
        if #out == 0 then
            return { "No badges yet: the special jobs that need them come later" }
        end
        table.insert(out, 1, "Badges (bosses drop them; !fft_badge <id> gives one for testing):")
        return out
    end
    local id = Rules.FindBadge(data, table.concat(args, " "))
    if not id then
        return { "Unknown badge " .. table.concat(args, " ") .. " (see !fft_badge list)" }
    end
    return result(svc:AddBadge(id))
end)

def("fft_soul", "<list|add <type> [n]|unlock>  the Soul Codex (testing: add souls, give the Soul Codex)", function(svc, args)
    local Souls = Ext.Require("Server/Souls.lua")
    local sub = args[1] and string.lower(args[1]) or "list"
    if sub == "unlock" then
        return result(svc:AddBadge(Souls.BADGE))
    elseif sub == "add" then
        local count = tonumber(args[#args])
        local last = count and #args - 1 or #args
        local id = Souls.Find(svc.Data, table.concat(args, " ", 2, last))
        if not id then
            return { "Unknown soul type (one of: " .. table.concat(svc.Data.SoulOrder or {}, ", ") .. ")" }
        end
        return result(Souls.Add(svc, id, count or 1))
    end
    local out = Souls.Lines(svc)
    table.insert(out, 1, #out == 0 and "The Soul Codex is empty: Soul Brand a foe; if it dies branded, its soul is yours."
        or "Soul Codex (souls devoured; 3 and 5 make the forms stronger):")
    return out
end)

def("fft_train", "[amount]  every party member gets JP in each unlocked job (testing; default Test.JPPerCast)", function(svc, args)
    local amount
    if args[1] then
        amount = tonumber(args[1])
        if not amount then
            return { "Usage: !fft_train [amount]" }
        end
    end
    return result(svc:TrainParty(nil, amount))
end)

def("fft_preset", "<name>  switch preset (Classic, Fast, Grindy, PureFFT)", function(svc, args)
    return result(svc.Config:SetPreset(args[1]))
end)

def("fft_mult", "<x>  global JP multiplier (saved to config.json)", function(svc, args)
    return result(svc.Config:SetOverride("JP.GlobalMultiplier", args[1]))
end)

def("fft_set", "<key.path> <value>  change any setting, e.g. !fft_set JP.XPShare 0.2", function(svc, args)
    if not args[1] or args[2] == nil then
        return { "Usage: !fft_set <key.path> <value>; keys are listed in config.reference.json" }
    end
    local value = table.concat(args, " ", 2)
    local ok, msg = svc.Config:SetOverride(args[1], value)
    regrant(svc)
    return result(ok, msg)
end)

def("fft_unset", "<key.path>  drop an override (back to the preset value)", function(svc, args)
    local ok, msg = svc.Config:ClearOverride(args[1])
    regrant(svc)
    return result(ok, msg)
end)

def("fft_config", "show the preset and every JP setting", function(svc)
    local out = { "preset " .. svc.Config.Preset .. " (presets: " .. table.concat(svc.Data.PresetOrder, ", ") .. ")" }
    for _, row in ipairs(svc.Config:Flatten()) do
        local value = type(row.Value) == "table" and ("[" .. Util.Join(row.Value) .. "]") or tostring(row.Value)
        if type(row.Value) == "table" and not Util.IsArray(row.Value) and next(row.Value) ~= nil then
            local parts = {}
            for _, k in ipairs(Util.SortedKeys(row.Value)) do
                parts[#parts + 1] = k .. "=" .. tostring(row.Value[k])
            end
            value = "{" .. table.concat(parts, ", ") .. "}"
        end
        out[#out + 1] = "  " .. row.Key .. " = " .. value
    end
    return out
end)

def("fft_reload", "reload config.json", function(svc)
    local ok, msg = svc.Config:Load()
    if svc.Ready then
        local cfg = svc:Cfg()
        for _, guid in ipairs(svc.State:Guids()) do
            if #Rules.CheckUnlocks(svc.Data, cfg, svc.State:Get(guid)) > 0 then
                svc.State:MarkDirty()
            end
        end
    end
    regrant(svc)
    return result(ok, msg)
end)

def("fft_regrant", "[who|all]  re-apply the spells/passives the jobs grant", function(svc, args)
    if not svc.Ready then
        return { "The job system has not loaded yet" }
    end
    if Util.Normalize(args[1]) == "all" then
        svc:ReconcileAll(true)
        return { "Grants re-applied for every party member" }
    end
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    svc:Reconcile(guid, true)
    return { "Grants re-applied for " .. svc.State:Get(guid).Name }
end)

def("fft_grants", "[who]  what the jobs grant now and whether the game has it (debugging)", function(svc, args)
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    return svc:DescribeGrants(guid)
end)

def("fft_reset", "[who]  reset a character's jobs and JP", function(svc, args)
    local guid, err = who(svc, args[1])
    if not guid then
        return { err }
    end
    return result(svc:ResetChar(guid))
end)

def("fft_uninstall", "remove everything the jobs granted and pause the system (run before removing the mod)", function(svc)
    return result(svc:SetDisabled(true))
end)

def("fft_enable", "turn the system back on after !fft_uninstall", function(svc)
    return result(svc:SetDisabled(false))
end)

def("fft_telemetry", "totals from the telemetry log", function(svc)
    return svc.Telemetry:Summary()
end)

Commands.Handlers = H
Commands.Help = HELP

-- Runs a command by name with string arguments; returns the output lines. Used by the console and tests.
function Commands.Run(svc, name, args)
    local fn = H[name]
    if not fn then
        return { "Unknown command " .. tostring(name) .. " (try !fft_help)" }
    end
    local ok, out = xpcall(fn, debug.traceback, svc, args or {})
    if not ok then
        return { "Error: " .. tostring(out) }
    end
    return out
end

function Commands.Register(svc, log)
    for _, h in ipairs(HELP) do
        local name = h[1]
        Ext.RegisterConsoleCommand(name, function(_, ...)
            local args = {}
            for i = 1, select("#", ...) do
                local a = select(i, ...)
                if a ~= nil then
                    args[#args + 1] = tostring(a)
                end
            end
            for _, line in ipairs(Commands.Run(svc, name, args)) do
                log.Info(line)
            end
        end)
    end
end

return Commands
