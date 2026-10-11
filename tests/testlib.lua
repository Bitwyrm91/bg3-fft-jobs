-- Tiny assertion helpers for the test suites.
local T = {}

local function require_json()
    local root = debug.getinfo(1, "S").source:match("^@(.*)[/\\]testlib%.lua$") or "tests"
    return dofile(root .. "/lib/json.lua")
end

local function show(v)
    if type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg and (msg .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
    end
end

function T.near(actual, expected, eps, msg)
    eps = eps or 1e-9
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        error((msg and (msg .. ": ") or "") .. "expected ~" .. show(expected) .. ", got " .. show(actual), 2)
    end
end

function T.truthy(v, msg)
    if not v then
        error(msg or "expected a true value", 2)
    end
end

function T.falsy(v, msg)
    if v then
        error((msg or "expected a false value") .. ", got " .. show(v), 2)
    end
end

function T.contains(haystack, needle, msg)
    if type(haystack) == "table" then
        for _, v in pairs(haystack) do
            if v == needle then
                return
            end
            if type(v) == "string" and type(needle) == "string" and string.find(v, needle, 1, true) then
                return
            end
        end
        error((msg and (msg .. ": ") or "") .. "no element contains " .. show(needle), 2)
    end
    if not string.find(tostring(haystack), needle, 1, true) then
        error((msg and (msg .. ": ") or "") .. show(haystack) .. " does not contain " .. show(needle), 2)
    end
end

function T.keys(set)
    local out = {}
    for k in pairs(set or {}) do
        out[#out + 1] = k
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- JP numbers the tests rely on, independent of the shipped defaults (which the pacing simulator tunes).
T.PINNED = {
    JP = {
        GlobalMultiplier = 1.0,
        Action = { Base = 8, PerJobLevel = 2, CharLevelDivisor = 4, EnhancedBonus = 0.3, Multiplier = 1.0,
            BonusActionWeight = 0.5, CountOutOfCombat = false, RequireActionCost = true, MaxPerTurn = 0 },
        Spillover = { Share = 0.25, RequireUnlocked = false },
        -- Off here so each suite checks one source at a time; the shared-learning tests switch it on.
        Shared = { Share = 0, Scope = "AllJobs", RequireUnlocked = false,
            Sources = { Action = true, Victory = true, XP = true, LongRest = true, Camp = true } },
        Victory = { Base = 20, PerCharLevel = 2 },
        XPShare = 0.1,
        Camp = { Share = 0.5 },
        LongRest = 25,
        Boost = { Multiplier = 1.5, Action = true, Victory = true, XP = true, LongRest = true },
    },
    JobLevels = { Thresholds = { 200, 400, 700, 1100, 1600, 2200, 3000 } },
}

function T.pinnedConfigJson(json, extra)
    local Util = Ext.Require("Shared/Util.lua")
    local over = Util.DeepMerge(T.PINNED, extra or {})
    return json.encode({ Preset = "Classic", Overrides = over })
end

-- Effective config for pure Rules tests: defaults + T.PINNED (+ extra).
function T.cfg(extra)
    local Util = Ext.Require("Shared/Util.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    return Util.DeepMerge(Util.DeepMerge(Data.ConfigDefaults, T.PINNED), extra or {})
end

-- Standard party: Tav (Fighter, host), Shadowheart (Cleric), Astarion (Rogue), plus a summon.
T.TAV = "11111111-1111-4111-8111-111111111111"
T.SHART = "22222222-2222-4222-8222-222222222222"
T.ASTA = "33333333-3333-4333-8333-333333333333"
T.SUMMON = "44444444-4444-4444-8444-444444444444"

function T.party(world)
    world.newChar(T.TAV, { name = "Tav", level = 3, xp = 1000, class = "Fighter" })
    world.newChar(T.SHART, { name = "Shadowheart", level = 3, xp = 1000, class = "Cleric" })
    world.newChar(T.ASTA, { name = "Astarion", level = 3, xp = 1000, class = "Rogue" })
    world.newChar(T.SUMMON, { name = "Familiar", level = 1, xp = 0, class = "Fighter", summon = true, player = false, party = false })
    world.host = T.TAV
    world.stats["Target_MainHandAttack"] = "ActionPoint:1"
    world.stats["Projectile_MainHandAttack"] = "ActionPoint:1"
    world.stats["Shout_Dash"] = "BonusActionPoint:1"
    world.stats["Interrupt_AttackOfOpportunity"] = "ReactionActionPoint:1"
    world.stats["Projectile_Jump"] = "BonusActionPoint:1;Movement:3"
    world.stats["Shout_Free"] = ""
end

-- Boots the server (and client), loads the session and starts gameplay.
function T.boot(world, opts)
    opts = opts or {}
    if not opts.noParty then
        T.party(world)
    end
    world.files["FFTJobs/config.json"] = opts.config or T.pinnedConfigJson(require_json(), opts.extra)
    local svc = world.bootServer()
    if not opts.noClient then
        world.bootClient()
    end
    world.sessionLoaded()
    world.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    world.tick()
    return svc
end

function T.cast(world, guid, spell)
    world.fire("CastedSpell", "S_Player_" .. guid, spell, "Target", "", 1)
end

function T.startCombat(world, id, guids)
    world.fire("CombatStarted", id)
    for _, g in ipairs(guids) do
        world.chars[g].inCombat = true
        world.fire("EnteredCombat", "S_Player_" .. g, id)
    end
end

function T.endCombat(world, id, guids)
    for _, g in ipairs(guids) do
        world.chars[g].inCombat = false
    end
    world.fire("CombatEnded", id)
    world.tick()
end

function T.job(svc, guid, jobId)
    local char = svc.State:Get(guid)
    return char.Jobs[jobId] or { Earned = 0, Unspent = 0, Learned = {} }
end

return T
