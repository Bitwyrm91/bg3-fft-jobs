-- Peddler (Fell Seal job): traps (Server/Peddler.lua ends the turn and applies the effect with the owner's DC, or
-- takes half the current HP), Item Potency on BG3's own potions and Alchemist's Fire, Patented Usage's grants.
local S = {}

local GOB = "66666666-6666-4666-8666-666666666666"
local TRAP = "88888888-8888-4888-8888-888888888888"

local function enemy(w, fields)
    local f = { name = "Goblin", level = 3, player = false, party = false, maxHp = 40, hp = 40 }
    for k, v in pairs(fields or {}) do
        f[k] = v
    end
    return w.newChar(GOB, f)
end

local function applied(w, target, status, source)
    w.fire("StatusApplied", "S_" .. target, status, source or "", 0)
end

local function calls(w, name, guid)
    local out = {}
    for _, c in ipairs(w.osiCalls) do
        if c[1] == name and (guid == nil or string.find(c[2], guid, 1, true)) then
            out[#out + 1] = c
        end
    end
    return out
end

function S.a_trap_ends_the_turn_and_applies_its_effect_with_the_owners_dc(w, T)
    local svc = T.boot(w)
    enemy(w)
    svc.State:Get(T.TAV).BestStat = "Wisdom"
    w.owners = { [TRAP] = T.TAV }
    w.fire("TurnStarted", "S_" .. GOB)
    applied(w, GOB, "FFTJ_TRAP_SPRUNG_LACERATING", "Trap_" .. TRAP)
    local st = calls(w, "ApplyStatus", GOB)
    T.eq(st[#st][3], "FFTJ_TRAP_LACERATE_Wis", "the save status of Tav's highest ability")
    T.eq(#calls(w, "EndTurn", GOB), 1, "its turn ends")
end

function S.a_trap_without_a_known_owner_uses_the_last_one_who_laid_it(w, T)
    local svc = T.boot(w)
    enemy(w)
    svc.State:Get(T.SHART).BestStat = "Charisma"
    T.cast(w, T.SHART, "Target_FFTJ_AlluringTrap")
    applied(w, GOB, "FFTJ_TRAP_SPRUNG_ALLURING", "Trap_" .. TRAP)
    local st = calls(w, "ApplyStatus", GOB)
    T.eq(st[#st][3], "FFTJ_TRAP_ALLURE_Cha")
    T.eq(#calls(w, "EndTurn", GOB), 0, "not its turn: nothing to end")
end

function S.painful_trap_takes_half_the_current_hp(w, T)
    T.boot(w)
    local gob = enemy(w, { hp = 31 })
    w.owners = { [TRAP] = T.TAV }
    w.fire("TurnStarted", "S_" .. GOB)
    applied(w, GOB, "FFTJ_TRAP_SPRUNG_PAINFUL", "Trap_" .. TRAP)
    T.eq(gob.hp, 16, "31 - floor(31 / 2)")
    local dmg = calls(w, "ApplyDamage", GOB)
    T.eq(dmg[1][4], "Piercing")
    T.truthy(string.find(dmg[1][5], T.TAV, 1, true), "Tav dealt it")
    T.eq(#calls(w, "EndTurn", GOB), 1)
end

function S.item_potency_heals_a_second_time_with_bg3_potions(w, T)
    local svc = T.boot(w)
    applied(w, T.SHART, "POTION_OF_HEALING_GREATER", "S_Player_" .. T.TAV)
    T.falsy(w.chars[T.SHART].statuses.FFTJ_POTENT_HEALING_GREATER, "only with Item Potency")
    svc.State:Get(T.TAV).Granted.Passives.FFTJ_ItemPotency = true
    applied(w, T.SHART, "POTION_OF_HEALING_GREATER", "S_Player_" .. T.TAV)
    T.truthy(w.chars[T.SHART].statuses.FFTJ_POTENT_HEALING_GREATER, "thrown or given by Tav: heals twice")
end

function S.item_potency_makes_alchemists_fire_burn_twice_as_long(w, T)
    local svc = T.boot(w)
    enemy(w)
    applied(w, GOB, "BURNING", "S_Player_" .. T.TAV)
    T.eq(#calls(w, "ApplyStatus", GOB), 0, "no throw with Item Potency")
    svc.State:Get(T.TAV).Granted.Passives.FFTJ_ItemPotency = true
    T.cast(w, T.TAV, "Projectile_AlchemistFire")
    applied(w, GOB, "BURNING", "S_Player_" .. T.TAV)
    applied(w, GOB, "BURNING", "S_Player_" .. T.TAV) -- the event our own re-apply fires
    local st = calls(w, "ApplyStatus", GOB)
    T.eq(#st, 1, "once per target")
    T.eq(st[1][3], "BURNING")
    T.eq(st[1][4], 36, "6 turns instead of 3")
end

function S.patented_usage_grants_area_forms_of_learned_chemist_items(w, T)
    local Rules = Ext.Require("Server/Rules.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Peddler")
    Rules.EnsureJob(char, "Peddler").Learned.PatentedUsage = true
    Rules.EnsureJob(char, "Chemist").Learned.Potion = true
    Rules.EnsureJob(char, "Chemist").Learned.Remedy = true
    local d = Rules.DesiredGrants(Data, char)
    T.truthy(d.Spells.Shout_FFTJ_PatentedUsage, "the container")
    T.truthy(d.Spells.Target_FFTJ_Potion_Patented)
    T.truthy(d.Spells.Target_FFTJ_Remedy_Patented)
    T.falsy(d.Spells.Target_FFTJ_HiPotion_Patented, "Hi-Potion not learned")
    T.falsy(d.Spells.Target_FFTJ_Potion, "the Chemist's own Potion needs Items as a skill set")
    char.Primary = "Squire"
    d = Rules.DesiredGrants(Data, char)
    T.falsy(d.Spells.Target_FFTJ_Potion_Patented, "Peddle not in use: no Patented Usage")
end

function S.peddler_job_data(w, T)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local job = Data.Jobs.Peddler
    T.truthy(job and job.Implemented)
    T.eq(job.Group, "FellSeal")
    T.eq(job.StartLearned[1], "LaceratingTrap")
    local total = 0
    for _, aid in ipairs(Data.AbilitiesByJob.Peddler) do
        total = total + Data.Abilities[aid].Cost
    end
    T.eq(#Data.AbilitiesByJob.Peddler, 10)
    T.eq(total, 4935, "Fell Seal AP x 2.5 (Critical: Quicken 562.5 -> 560)")
end

return S
