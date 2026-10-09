-- The job system's rules as pure functions on plain tables: no game calls, so they are unit-tested directly.
--   data = Shared/GeneratedData.lua, cfg = effective config, char = one character's saved state.
local Util = Ext.Require("Shared/Util.lua")

local Rules = {}

Rules.Slots = { "Reaction", "Support", "Movement" }
local GRANT_KINDS = { "Spells", "Passives", "Statuses" }

function Rules.NewStats()
    return { Actions = 0, Combats = 0, XP = 0, JP = {} }
end

function Rules.EnsureJob(char, jobId)
    char.Jobs = char.Jobs or {}
    local js = char.Jobs[jobId]
    if not js then
        js = { Earned = 0, Unspent = 0, Frac = 0, Learned = {} }
        char.Jobs[jobId] = js
    end
    js.Learned = js.Learned or {}
    return js
end

function Rules.NewChar(data, cfg, startJob)
    local char = {
        Primary = startJob,
        Unlocked = {},
        Jobs = {},
        Granted = { Spells = {}, Passives = {}, Statuses = {} },
        Stats = Rules.NewStats(),
        SinceRest = Rules.NewStats(),
    }
    for _, jobId in ipairs(cfg.Rules.StartingUnlocked) do
        if data.Jobs[jobId] and data.Jobs[jobId].Implemented then
            char.Unlocked[jobId] = true
        end
    end
    char.Unlocked[startJob] = true
    Rules.EnsureJob(char, startJob)
    return char
end

-- Fills in fields missing from older saves; returns the same table.
function Rules.Normalize(char)
    char.Unlocked = char.Unlocked or {}
    char.Jobs = char.Jobs or {}
    for _, js in pairs(char.Jobs) do
        js.Earned = js.Earned or 0
        js.Unspent = js.Unspent or 0
        js.Frac = js.Frac or 0
        js.Learned = js.Learned or {}
    end
    char.Granted = char.Granted or {}
    for _, kind in ipairs(GRANT_KINDS) do
        char.Granted[kind] = char.Granted[kind] or {}
    end
    char.Stats = char.Stats or Rules.NewStats()
    char.SinceRest = char.SinceRest or Rules.NewStats()
    for _, s in ipairs({ char.Stats, char.SinceRest }) do
        s.Actions = s.Actions or 0
        s.Combats = s.Combats or 0
        s.XP = s.XP or 0
        s.JP = s.JP or {}
    end
    return char
end

---------------------------------------------------------------- levels and unlocks

function Rules.JobLevel(earned, thresholds)
    local level = 1
    for _, t in ipairs(thresholds) do
        if (earned or 0) >= t then
            level = level + 1
        else
            break
        end
    end
    return level
end

-- Total JP needed for the next job level, or nil at the top level.
function Rules.NextThreshold(earned, thresholds)
    for _, t in ipairs(thresholds) do
        if (earned or 0) < t then
            return t
        end
    end
    return nil
end

function Rules.GetJobLevel(cfg, char, jobId)
    local js = char.Jobs and char.Jobs[jobId]
    return Rules.JobLevel(js and js.Earned or 0, cfg.JobLevels.Thresholds)
end

function Rules.IsUnlocked(char, jobId)
    return char.Unlocked ~= nil and char.Unlocked[jobId] == true
end

-- Returns met (bool) and the list of requirements still missing ({Job, Level, Have}).
function Rules.RequirementsMet(data, cfg, char, jobId)
    local job = data.Jobs[jobId]
    local missing = {}
    if not job then
        return false, missing
    end
    for _, req in ipairs(job.Unlock) do
        local have = Rules.GetJobLevel(cfg, char, req.Job)
        if have < req.Level then
            missing[#missing + 1] = { Job = req.Job, Level = req.Level, Have = have }
        end
    end
    return #missing == 0, missing
end

function Rules.RequirementText(data, jobId)
    local job = data.Jobs[jobId]
    if not job or #job.Unlock == 0 then
        return "Starting job"
    end
    local parts = {}
    for _, req in ipairs(job.Unlock) do
        local rj = data.Jobs[req.Job]
        parts[#parts + 1] = string.format("%s Lv%d", rj and rj.Name or req.Job, req.Level)
    end
    return table.concat(parts, ", ")
end

-- Unlocks every implemented job whose requirements are met; returns the newly unlocked job ids.
function Rules.CheckUnlocks(data, cfg, char)
    local unlocked = {}
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Implemented and not Rules.IsUnlocked(char, jobId) and Rules.RequirementsMet(data, cfg, char, jobId) then
            char.Unlocked[jobId] = true
            Rules.EnsureJob(char, jobId)
            unlocked[#unlocked + 1] = jobId
        end
    end
    return unlocked
end

function Rules.UnlockAll(data, char)
    for _, jobId in ipairs(data.JobOrder) do
        if data.Jobs[jobId].Implemented then
            char.Unlocked[jobId] = true
            Rules.EnsureJob(char, jobId)
        end
    end
end

---------------------------------------------------------------- JP

-- Adds amount (may be fractional) to a job. Fractions are kept in js.Frac so nothing is lost to rounding.
-- Returns {Job, Added (whole JP), LevelBefore, LevelAfter, Unlocked = {job ids}}.
function Rules.AddJP(data, cfg, char, jobId, amount)
    local result = { Job = jobId, Added = 0, LevelBefore = 1, LevelAfter = 1, Unlocked = {} }
    local job = data.Jobs[jobId]
    if not job or not job.Implemented then
        return result
    end
    local js = Rules.EnsureJob(char, jobId)
    local thresholds = cfg.JobLevels.Thresholds
    result.LevelBefore = Rules.JobLevel(js.Earned, thresholds)
    result.LevelAfter = result.LevelBefore
    if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
        return result
    end
    local total = (js.Frac or 0) + amount
    local whole = math.floor(total)
    js.Frac = math.floor((total - whole) * 1000000 + 0.5) / 1000000
    js.Earned = js.Earned + whole
    js.Unspent = js.Unspent + whole
    result.Added = whole
    result.LevelAfter = Rules.JobLevel(js.Earned, thresholds)
    if result.LevelAfter > result.LevelBefore then
        result.Unlocked = Rules.CheckUnlocks(data, cfg, char)
    end
    return result
end

function Rules.ActionFormula(jp, jobLevel, charLevel)
    local a = jp.Action
    local value = a.Base + a.PerJobLevel * jobLevel
    if a.CharLevelDivisor and a.CharLevelDivisor > 0 then
        value = value + math.floor((charLevel or 1) / a.CharLevelDivisor)
    end
    return value
end

function Rules.BoostFactor(jp, source, hasBoost)
    if hasBoost and jp.Boost[source] then
        return jp.Boost.Multiplier
    end
    return 1
end

-- Own JP for one counted cast, and the spillover each ally in the same fight receives.
function Rules.ActionJP(jp, jobLevel, charLevel, weight, hasBoost)
    local f = Rules.ActionFormula(jp, jobLevel, charLevel)
    local g = jp.GlobalMultiplier
    local own = f * (1 + jp.Action.EnhancedBonus) * jp.Action.Multiplier * weight
        * Rules.BoostFactor(jp, "Action", hasBoost) * g
    local spill = f * jp.Action.Multiplier * weight * jp.Spillover.Share * g
    return own, spill
end

function Rules.VictoryJP(jp, charLevel, hasBoost)
    return (jp.Victory.Base + jp.Victory.PerCharLevel * (charLevel or 1))
        * Rules.BoostFactor(jp, "Victory", hasBoost) * jp.GlobalMultiplier
end

function Rules.XPJP(jp, xp, hasBoost)
    return (xp or 0) * jp.XPShare * Rules.BoostFactor(jp, "XP", hasBoost) * jp.GlobalMultiplier
end

function Rules.RestJP(jp, hasBoost)
    return jp.LongRest * Rules.BoostFactor(jp, "LongRest", hasBoost) * jp.GlobalMultiplier
end

-- avgOwn already includes the global multiplier, so it is not applied again.
function Rules.CampJP(jp, avgOwn)
    return (avgOwn or 0) * jp.Camp.Share
end

---------------------------------------------------------------- abilities and slots

function Rules.IsLearned(char, abilityId)
    for _, js in pairs(char.Jobs or {}) do
        if js.Learned and js.Learned[abilityId] then
            return true
        end
    end
    return false
end

function Rules.IsMastered(data, char, jobId)
    local list = data.AbilitiesByJob[jobId]
    if not list or #list == 0 then
        return false
    end
    for _, aid in ipairs(list) do
        if not Rules.IsLearned(char, aid) then
            return false
        end
    end
    return true
end

function Rules.LearnedCount(data, char, jobId)
    local n = 0
    for _, aid in ipairs(data.AbilitiesByJob[jobId] or {}) do
        if Rules.IsLearned(char, aid) then
            n = n + 1
        end
    end
    return n
end

function Rules.CanLearn(data, char, abilityId)
    local ab = data.Abilities[abilityId]
    if not ab then
        return false, "Unknown ability " .. tostring(abilityId)
    end
    local job = data.Jobs[ab.Job]
    if not Rules.IsUnlocked(char, ab.Job) then
        return false, string.format("%s is still locked (%s)", job.Name, Rules.RequirementText(data, ab.Job))
    end
    if Rules.IsLearned(char, abilityId) then
        return false, ab.Name .. " is already learned"
    end
    local js = char.Jobs[ab.Job]
    local have = js and js.Unspent or 0
    if have < ab.Cost then
        return false, string.format("%s needs %s JP in %s (you have %s)", ab.Name, Util.Num(ab.Cost), job.Name, Util.Num(have))
    end
    return true
end

-- Returns ok, error, {Mastered = bool}.
function Rules.Learn(data, char, abilityId)
    local ok, err = Rules.CanLearn(data, char, abilityId)
    if not ok then
        return false, err
    end
    local ab = data.Abilities[abilityId]
    local js = Rules.EnsureJob(char, ab.Job)
    js.Unspent = js.Unspent - ab.Cost
    js.Learned[abilityId] = true
    return true, nil, { Mastered = Rules.IsMastered(data, char, ab.Job) }
end

function Rules.SetPrimary(data, char, jobId)
    local job = data.Jobs[jobId]
    if not job or not job.Implemented then
        return false, "Unknown job " .. tostring(jobId)
    end
    if not Rules.IsUnlocked(char, jobId) then
        return false, string.format("%s is still locked (%s)", job.Name, Rules.RequirementText(data, jobId))
    end
    char.Primary = jobId
    Rules.EnsureJob(char, jobId)
    if char.Secondary == jobId then
        char.Secondary = nil
    end
    return true
end

-- jobId nil clears the secondary skill set.
function Rules.SetSecondary(data, char, jobId)
    if jobId == nil then
        char.Secondary = nil
        return true
    end
    local job = data.Jobs[jobId]
    if not job or not job.Implemented then
        return false, "Unknown job " .. tostring(jobId)
    end
    if not Rules.IsUnlocked(char, jobId) then
        return false, string.format("%s is still locked (%s)", job.Name, Rules.RequirementText(data, jobId))
    end
    if char.Primary == jobId then
        return false, job.Name .. " is already the primary job"
    end
    char.Secondary = jobId
    return true
end

-- Puts a learned reaction/support/movement ability in its slot. Returns ok, error, slot.
function Rules.Equip(data, char, abilityId)
    local ab = data.Abilities[abilityId]
    if not ab then
        return false, "Unknown ability " .. tostring(abilityId)
    end
    if ab.Type == "Action" then
        return false, ab.Name .. " is an action ability: it is used through the primary or secondary skill set"
    end
    if not Rules.IsLearned(char, abilityId) then
        return false, ab.Name .. " is not learned yet"
    end
    char[ab.Type] = abilityId
    return true, nil, ab.Type
end

function Rules.SlotName(slot)
    local n = Util.Normalize(slot)
    for _, s in ipairs(Rules.Slots) do
        if Util.Normalize(s) == n then
            return s
        end
    end
    return nil
end

function Rules.Unequip(char, slot)
    local s = Rules.SlotName(slot)
    if not s then
        return false, "Unknown slot " .. tostring(slot) .. " (reaction, support or movement)"
    end
    char[s] = nil
    return true, nil, s
end

function Rules.EquippedEffect(data, char, effect)
    for _, slot in ipairs(Rules.Slots) do
        local ab = char[slot] and data.Abilities[char[slot]]
        if ab and ab.Effect == effect and Rules.IsLearned(char, ab.Id) then
            return true
        end
    end
    return false
end

function Rules.HasJPBoost(data, char)
    return Rules.EquippedEffect(data, char, "JPBoost")
end

local function condMatches(data, char, cond)
    if cond.PrimaryJob and char.Primary == cond.PrimaryJob then
        return true
    end
    if cond.EquippedEffect and Rules.EquippedEffect(data, char, cond.EquippedEffect) then
        return true
    end
    if cond.Equipped then
        for _, slot in ipairs(Rules.Slots) do
            if char[slot] == cond.Equipped then
                return true
            end
        end
    end
    return false
end

-- The grants of an ability for this character: the first variant whose condition holds, else the default.
function Rules.GrantsFor(data, char, ab)
    for _, v in ipairs(ab.Variants or {}) do
        for _, cond in ipairs(v.When.AnyOf or {}) do
            if condMatches(data, char, cond) then
                return v.Grants
            end
        end
    end
    return ab.Grants
end

-- Everything the mod should currently grant: {Spells = set, Passives = set, Statuses = set}.
function Rules.DesiredGrants(data, char)
    local desired = { Spells = {}, Passives = {}, Statuses = {} }
    local function add(grants)
        for _, kind in ipairs(GRANT_KINDS) do
            for _, id in ipairs(grants and grants[kind] or {}) do
                desired[kind][id] = true
            end
        end
    end
    if data.JobBoardSpell then
        desired.Spells[data.JobBoardSpell] = true
    end
    local primary = data.Jobs[char.Primary]
    if primary then
        add(primary.Innate)
    end
    local function addLearnedActions(jobId)
        for _, aid in ipairs(data.AbilitiesByJob[jobId] or {}) do
            local ab = data.Abilities[aid]
            if ab.Type == "Action" and Rules.IsLearned(char, aid) then
                add(Rules.GrantsFor(data, char, ab))
            end
        end
    end
    addLearnedActions(char.Primary)
    if char.Secondary and char.Secondary ~= char.Primary then
        addLearnedActions(char.Secondary)
    end
    for _, slot in ipairs(Rules.Slots) do
        local ab = char[slot] and data.Abilities[char[slot]]
        if ab and ab.Type == slot and Rules.IsLearned(char, ab.Id) then
            add(Rules.GrantsFor(data, char, ab))
        end
    end
    return desired
end

---------------------------------------------------------------- lookups from user input

function Rules.FindJob(data, text)
    local n = Util.Normalize(text)
    if n == "" then
        return nil
    end
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Implemented and (Util.Normalize(jobId) == n or Util.Normalize(job.Name) == n) then
            return jobId
        end
    end
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Implemented and string.find(Util.Normalize(job.Name), n, 1, true) == 1 then
            return jobId
        end
    end
    return nil
end

function Rules.FindAbility(data, text)
    local n = Util.Normalize(text)
    if n == "" then
        return nil
    end
    for _, aid in ipairs(data.AbilityOrder) do
        local ab = data.Abilities[aid]
        if Util.Normalize(aid) == n or Util.Normalize(ab.Name) == n then
            return aid
        end
    end
    return nil
end

return Rules
