-- The job system's rules as pure functions on plain tables: no game calls, so they are unit-tested directly.
--   data = Shared/GeneratedData.lua, cfg = effective config, char = one character's saved state.
local Util = Ext.Require("Shared/Util.lua")

local Rules = {}

-- Fell Seal slots (user's choice, 2026-10-12): one reaction slot and two free passive slots that take any support or
-- movement ability. The slot name is the field of the character table that holds the equipped ability id.
Rules.Slots = { "Reaction", "Passive1", "Passive2" }
Rules.SlotTypes = {
    Reaction = { Reaction = true },
    Passive1 = { Support = true, Movement = true },
    Passive2 = { Support = true, Movement = true },
}
Rules.SlotLabels = { Reaction = "reaction", Passive1 = "passive 1", Passive2 = "passive 2" }
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
        Badges = {},
        Jobs = {},
        Kills = 0,
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
    char.Badges = char.Badges or {}
    char.Jobs = char.Jobs or {}
    char.Kills = char.Kills or 0
    -- saves from 1.0.0.5 and older: FFT's support and movement slots become the two passive slots
    for _, old in ipairs({ "Support", "Movement" }) do
        local id = char[old]
        char[old] = nil
        if id ~= nil and char.Passive1 == nil then
            char.Passive1 = id
        elseif id ~= nil and char.Passive2 == nil then
            char.Passive2 = id
        end
    end
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

-- Badges belong to the party (Rules.AddBadge); Rules.SyncParty copies them into every character.
function Rules.HasBadge(char, badgeId)
    return char.Badges ~= nil and char.Badges[badgeId] == true
end

function Rules.BadgeName(data, badgeId)
    local badge = data.Badges and data.Badges[badgeId]
    return badge and badge.Name or tostring(badgeId)
end

-- Returns met (bool) and the list of requirements still missing ({Job, Level, Have}, {Job, Mastered}, {Kills, Have}
-- or {Badge}). Mastered: every ability of the job learned (War of the Lions' Dark Knight); Kills: enemies the
-- character has defeated (Service:CountKill).
function Rules.RequirementsMet(data, cfg, char, jobId)
    local job = data.Jobs[jobId]
    local missing = {}
    if not job then
        return false, missing
    end
    for _, req in ipairs(job.Unlock) do
        if req.Badge then
            if not Rules.HasBadge(char, req.Badge) then
                missing[#missing + 1] = { Badge = req.Badge }
            end
        elseif req.Kills then
            local have = char.Kills or 0
            if have < req.Kills then
                missing[#missing + 1] = { Kills = req.Kills, Have = have }
            end
        elseif req.Mastered then
            if not Rules.IsMastered(data, char, req.Job, cfg) then
                missing[#missing + 1] = { Job = req.Job, Mastered = true }
            end
        else
            local have = Rules.GetJobLevel(cfg, char, req.Job)
            if have < req.Level then
                missing[#missing + 1] = { Job = req.Job, Level = req.Level, Have = have }
            end
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
        if req.Badge then
            parts[#parts + 1] = Rules.BadgeName(data, req.Badge)
        elseif req.Kills then
            parts[#parts + 1] = string.format("%d enemies defeated", req.Kills)
        else
            local rj = data.Jobs[req.Job]
            parts[#parts + 1] = req.Mastered and string.format("%s mastered", rj and rj.Name or req.Job)
                or string.format("%s Lv%d", rj and rj.Name or req.Job, req.Level)
        end
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

-- The party's shared state. chars = {guid = char}; party = the saved Meta table with the badges the party found
-- (Badges: found once, they serve everyone) and every job some member has unlocked (PartyUnlocked). A job in
-- PartyUnlocked shows as unlocked by the party on everyone's Job Board, but each character still needs its own job
-- levels to learn from it or take it (the user's rule, 2026-10-12). Copies the badges into every character and
-- returns the job ids the party had not unlocked before, sorted.
function Rules.SyncParty(data, chars, party)
    party.Badges = party.Badges or {}
    party.PartyUnlocked = party.PartyUnlocked or {}
    local known = {}
    for _, guid in ipairs(Util.SortedKeys(chars)) do
        local char = chars[guid]
        char.Badges = char.Badges or {}
        for badgeId, on in pairs(party.Badges) do
            if on == true then
                char.Badges[badgeId] = true
            end
        end
        for jobId, on in pairs(char.Unlocked or {}) do
            if on == true and data.Jobs[jobId] and data.Jobs[jobId].Implemented and not party.PartyUnlocked[jobId] then
                party.PartyUnlocked[jobId] = true
                known[#known + 1] = jobId
            end
        end
    end
    table.sort(known)
    return known
end

function Rules.IsPartyUnlocked(party, jobId)
    return party ~= nil and party.PartyUnlocked ~= nil and party.PartyUnlocked[jobId] == true
end

-- What a character still needs for a job, with its own levels: "Squire Lv2 (has Lv1), Holy Knight Badge".
function Rules.MissingText(data, cfg, char, jobId)
    local _, missing = Rules.RequirementsMet(data, cfg, char, jobId)
    local parts = {}
    for _, m in ipairs(missing) do
        if m.Badge then
            parts[#parts + 1] = Rules.BadgeName(data, m.Badge)
        elseif m.Kills then
            parts[#parts + 1] = string.format("%d enemies defeated (has %d)", m.Kills, m.Have)
        elseif m.Mastered then
            local rj = data.Jobs[m.Job]
            parts[#parts + 1] = string.format("%s mastered", rj and rj.Name or m.Job)
        else
            local rj = data.Jobs[m.Job]
            parts[#parts + 1] = string.format("%s Lv%d (has Lv%d)", rj and rj.Name or m.Job, m.Level, m.Have)
        end
    end
    return table.concat(parts, ", ")
end

-- The party found a badge (Fell Seal: a crest that opens a special job, alongside job levels). It serves every
-- character (the user's choice); each one whose job levels are already there unlocks the job now. Returns ok,
-- error, {Already = bool, Unlocked = {{Guid, Job}}}.
function Rules.AddBadge(data, cfg, chars, party, badgeId)
    if not (data.Badges and data.Badges[badgeId]) then
        return false, "Unknown badge " .. tostring(badgeId)
    end
    party.Badges = party.Badges or {}
    local info = { Already = party.Badges[badgeId] == true, Unlocked = {} }
    party.Badges[badgeId] = true
    Rules.SyncParty(data, chars, party)
    for _, guid in ipairs(Util.SortedKeys(chars)) do
        for _, jobId in ipairs(Rules.CheckUnlocks(data, cfg, chars[guid])) do
            info.Unlocked[#info.Unlocked + 1] = { Guid = guid, Job = jobId }
        end
    end
    Rules.SyncParty(data, chars, party)
    return true, nil, info
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

-- Shared learning (Fell Seal's vicarious learning): part of each JP gain a character makes in a job also goes into
-- the character's other jobs that the party used in combat (FightJobs), or into all of them (AllJobs), locked ones
-- included. JP source (as counted in telemetry) -> its key in JP.Shared.Sources. Spill, Manual and Shared itself
-- never share.
Rules.SharedSourceKey = { Action = "Action", Victory = "Victory", XP = "XP", Rest = "LongRest", Camp = "Camp" }
Rules.SharedScopes = { "FightJobs", "AllJobs" }

-- JP each target job gets from a gain of amount (already multiplied) from source; 0 when that source does not share.
function Rules.SharedJP(jp, amount, source)
    local sh = jp.Shared
    local key = Rules.SharedSourceKey[source]
    if not key or not sh.Sources[key] or sh.Share <= 0 or type(amount) ~= "number" or amount ~= amount
        or amount <= 0 or amount == math.huge then
        return 0
    end
    return amount * sh.Share
end

-- The jobs that get shared JP from a gain in fromJob, in job order: every other implemented job (AllJobs), or only
-- those in fightJobs, the set of primary jobs of the fight's participants (FightJobs).
function Rules.SharedTargets(data, cfg, char, fromJob, fightJobs)
    local sh = cfg.JP.Shared
    local out = {}
    for _, jobId in ipairs(data.JobOrder) do
        if data.Jobs[jobId].Implemented and jobId ~= fromJob
            and (sh.Scope == "AllJobs" or (fightJobs ~= nil and fightJobs[jobId] == true))
            and (not sh.RequireUnlocked or Rules.IsUnlocked(char, jobId)) then
            out[#out + 1] = jobId
        end
    end
    return out
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

-- Every ability learned. A job without abilities to learn (the Mime) is mastered at the top job level instead,
-- which needs cfg (job level thresholds).
function Rules.IsMastered(data, char, jobId, cfg)
    local list = data.AbilitiesByJob[jobId]
    if not list then
        return false
    end
    if #list == 0 then
        return cfg ~= nil and Rules.GetJobLevel(cfg, char, jobId) > #cfg.JobLevels.Thresholds
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

-- The slot that holds an ability, or nil.
function Rules.SlotOf(char, abilityId)
    for _, s in ipairs(Rules.Slots) do
        if char[s] == abilityId then
            return s
        end
    end
    return nil
end

-- Slot from user input: "reaction", "passive 1" / "1" / "p1", "passive 2" / "2" / "p2" (or a slot name).
local SLOT_ALIASES = { ["1"] = "Passive1", p1 = "Passive1", slot1 = "Passive1",
    ["2"] = "Passive2", p2 = "Passive2", slot2 = "Passive2" }

function Rules.SlotName(slot)
    local n = Util.Normalize(slot)
    for _, s in ipairs(Rules.Slots) do
        if Util.Normalize(s) == n then
            return s
        end
    end
    return SLOT_ALIASES[n]
end

-- Puts a learned reaction/support/movement ability in a slot that takes its type: slot (optional) names one,
-- otherwise the first empty one. The reaction slot is replaced; with both passive slots full a slot must be named.
-- An ability moves rather than sitting in two slots. Returns ok, error, slot.
function Rules.Equip(data, char, abilityId, slot)
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
    if slot ~= nil then
        local s = Rules.SlotName(slot)
        if not s then
            return false, "Unknown slot " .. tostring(slot) .. " (reaction, 1 or 2)"
        end
        if not Rules.SlotTypes[s][ab.Type] then
            return false, string.format("%s is a %s ability: it does not go in the %s slot", ab.Name,
                string.lower(ab.Type), Rules.SlotLabels[s])
        end
        slot = s
    else
        for _, s in ipairs(Rules.Slots) do
            if Rules.SlotTypes[s][ab.Type] and (char[s] == nil or char[s] == abilityId) then
                slot = s
                break
            end
        end
        if not slot and ab.Type == "Reaction" then
            slot = "Reaction"
        elseif not slot then
            return false, "Both passive slots are full: unequip one first or name the slot to replace (1 or 2)"
        end
    end
    local current = Rules.SlotOf(char, abilityId)
    if current and current ~= slot then
        char[current] = nil
    end
    char[slot] = abilityId
    return true, nil, slot
end

function Rules.Unequip(char, slot)
    local s = Rules.SlotName(slot)
    if not s then
        return false, "Unknown slot " .. tostring(slot) .. " (reaction, 1 or 2)"
    end
    char[s] = nil
    return true, nil, s
end

-- The ability types of the main job that work without a slot (Rules.MainJobAlwaysOn), as a set.
local function alwaysOnTypes(cfg)
    local set = {}
    for _, t in ipairs(cfg and cfg.Rules and cfg.Rules.MainJobAlwaysOn or {}) do
        set[t] = true
    end
    return set
end

-- Fell Seal rule: a learned reaction/support/movement ability of the main job works without a slot when its type
-- is in Rules.MainJobAlwaysOn.
function Rules.IsAlwaysOn(data, cfg, char, abilityId)
    local ab = data.Abilities[abilityId]
    return ab ~= nil and ab.Type ~= "Action" and ab.Job == char.Primary and alwaysOnTypes(cfg)[ab.Type] == true
        and Rules.IsLearned(char, abilityId)
end

-- The reaction/support/movement abilities in effect, as a list of ids: the slots, then the main job's always-on
-- ones (cfg nil: the slots only).
function Rules.ActivePassives(data, char, cfg)
    local out, seen = {}, {}
    for _, slot in ipairs(Rules.Slots) do
        local ab = char[slot] and data.Abilities[char[slot]]
        if ab and Rules.SlotTypes[slot][ab.Type] and Rules.IsLearned(char, ab.Id) and not seen[ab.Id] then
            out[#out + 1] = ab.Id
            seen[ab.Id] = true
        end
    end
    for _, aid in ipairs(data.AbilitiesByJob[char.Primary] or {}) do
        if not seen[aid] and Rules.IsAlwaysOn(data, cfg, char, aid) then
            out[#out + 1] = aid
            seen[aid] = true
        end
    end
    return out
end

local function activeEffect(data, active, effect)
    for _, aid in ipairs(active) do
        if data.Abilities[aid].Effect == effect then
            return true
        end
    end
    return false
end

-- An engine-handled effect (JP Boost, Throw Items) is on: equipped, or always on through the main job.
function Rules.EquippedEffect(data, char, effect, cfg)
    return activeEffect(data, Rules.ActivePassives(data, char, cfg), effect)
end

function Rules.HasJPBoost(data, char, cfg)
    return Rules.EquippedEffect(data, char, "JPBoost", cfg)
end

local function condMatches(data, char, cond, active)
    if cond.PrimaryJob and char.Primary == cond.PrimaryJob then
        return true
    end
    -- another ability learned, e.g. a better Jump tier: FFT applies only the highest one
    if cond.Learned and Rules.IsLearned(char, cond.Learned) then
        return true
    end
    if cond.EquippedEffect and activeEffect(data, active, cond.EquippedEffect) then
        return true
    end
    if cond.Equipped then
        for _, aid in ipairs(active) do
            if aid == cond.Equipped then
                return true
            end
        end
    end
    return false
end

-- The grants of an ability for this character: the first variant whose condition holds, else the default.
-- active (optional) = Rules.ActivePassives(data, char, cfg), passed in when already computed.
function Rules.GrantsFor(data, char, ab, cfg, active)
    active = active or Rules.ActivePassives(data, char, cfg)
    for _, v in ipairs(ab.Variants or {}) do
        for _, cond in ipairs(v.When.AnyOf or {}) do
            if condMatches(data, char, cond, active) then
                return v.Grants
            end
        end
    end
    return ab.Grants
end

-- Mastery perks are on (Rules.MasteryPerks) and this job's perk is earned.
function Rules.HasMasteryPerk(data, cfg, char, jobId)
    local job = data.Jobs[jobId]
    return cfg ~= nil and cfg.Rules.MasteryPerks == true and job ~= nil and job.Implemented and job.Mastery ~= nil
        and Rules.IsMastered(data, char, jobId, cfg)
end

-- Everything the mod should currently grant: {Spells = set, Passives = set, Statuses = set}. cfg (optional) adds
-- the Fell Seal rules (main job's always-on abilities, mastery perks) and the testing tools while Test.Tools is on.
function Rules.DesiredGrants(data, char, cfg)
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
    if data.TrainingSpell and cfg and cfg.Test and cfg.Test.Tools then
        desired.Spells[data.TrainingSpell] = true
    end
    local primary = data.Jobs[char.Primary]
    if primary then
        add(primary.Innate)
    end
    -- the Mime's echo for this turn (Service: set at its turn start, cleared after use or at turn end)
    if char.Echo and char.Primary == "Mime" and primary and primary.Implemented then
        desired.Spells[char.Echo] = true
    end
    local active = Rules.ActivePassives(data, char, cfg)
    local function addLearnedActions(jobId)
        for _, aid in ipairs(data.AbilitiesByJob[jobId] or {}) do
            local ab = data.Abilities[aid]
            if ab.Type == "Action" and Rules.IsLearned(char, aid) then
                add(Rules.GrantsFor(data, char, ab, cfg, active))
            end
        end
    end
    addLearnedActions(char.Primary)
    if char.Secondary and char.Secondary ~= char.Primary then
        addLearnedActions(char.Secondary)
    end
    for _, aid in ipairs(active) do
        add(Rules.GrantsFor(data, char, data.Abilities[aid], cfg, active))
    end
    for _, jobId in ipairs(data.JobOrder) do
        if Rules.HasMasteryPerk(data, cfg, char, jobId) then
            add(data.Jobs[jobId].Mastery.Grants)
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

function Rules.FindBadge(data, text)
    local n = Util.Normalize(text)
    if n == "" then
        return nil
    end
    for _, id in ipairs(data.BadgeOrder or {}) do
        if Util.Normalize(id) == n or Util.Normalize(data.Badges[id].Name) == n then
            return id
        end
    end
    return nil
end

return Rules
