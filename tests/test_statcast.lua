-- NWP 18: job skills hit and set their save DCs with the character's highest ability (tools/statcast.py,
-- Rules.StatCastGrants); chosen when the mod first meets the character and again at level-up only.
local S = {}

local GOB = "66666666-6666-4666-8666-666666666666"
local SCORES = { Strength = 10, Dexterity = 14, Constitution = 12, Intelligence = 8, Wisdom = 17, Charisma = 10 }

local function scores(w, guid, s)
    w.chars[guid].abilities = s
end

-- Party with Tav's scores set before the mod first sees him.
local function boot(w, T, opts)
    T.party(w)
    scores(w, T.TAV, SCORES)
    opts = opts or {}
    opts.noParty = true
    return T.boot(w, opts)
end

local function called(w, name, guid, id)
    for _, c in ipairs(w.osiCalls) do
        if c[1] == name and c[2] == guid and c[3] == id then
            return true
        end
    end
    return false
end

local function read(Mocks, file)
    local f = assert(io.open(Mocks.Root .. "/Mod/Public/FFTJobs/Stats/Generated/Data/" .. file, "rb"))
    local s = f:read("a")
    f:close()
    return (s:gsub("\r", "")) .. "\n" -- so the last entry ends with a blank line too
end

local function entry(text, name)
    return text:match('new entry "' .. name:gsub("%p", "%%%0") .. '"\n(.-)\n\n') or ""
end

function S.best_stat_takes_the_highest_and_never_swaps_equal_modifiers(w, T)
    local Rules = Ext.Require("Server/Rules.lua")
    local function sc(str, dex)
        return { Strength = str, Dexterity = dex, Constitution = 10, Intelligence = 10, Wisdom = 10, Charisma = 10 }
    end
    T.eq(Rules.BestStat(SCORES, nil), "Wisdom")
    T.eq(Rules.BestStat(sc(16, 17), "Strength"), "Strength", "16 and 17 are both +3: no swap")
    T.eq(Rules.BestStat(sc(16, 18), "Strength"), "Dexterity", "+4 beats +3")
    T.eq(Rules.BestStat(sc(14, 14), nil), "Strength", "a tie with nothing chosen yet: the first in order")
    T.eq(Rules.BestStat(nil, "Wisdom"), "Wisdom", "unreadable scores keep the current one")
    T.eq(Rules.BestStat(nil, nil), nil)
end

function S.learned_skills_come_through_the_highest_ability_passive(w, T)
    local svc = boot(w, T)
    T.eq(svc.State:Get(T.TAV).BestStat, "Wisdom", "read when the mod first meets Tav")
    T.eq(svc.State:Get(T.TAV).Primary, "Squire")
    svc:AddManualJP(T.TAV, 100, "Squire")
    T.truthy(svc:Learn(T.TAV, "Rush"))
    local c = w.chars[T.TAV]
    T.truthy(c.passives.FFTJ_Cast_Wis_Target_FFTJ_Rush, "Rush is unlocked with Wisdom")
    T.falsy(c.passives.FFTJ_Cast_Str_Target_FFTJ_Rush)
    T.falsy(called(w, "AddSpell", T.TAV, "Target_FFTJ_Rush"), "not added plainly")
    T.truthy(c.spells.Shout_FFTJ_JobBoard, "the Job Board is no job skill: added plainly")
end

function S.the_highest_ability_changes_only_at_level_up(w, T)
    local svc = boot(w, T)
    svc:AddManualJP(T.TAV, 100, "Squire")
    svc:Learn(T.TAV, "Rush")
    -- a belt makes Strength the highest: nothing changes before a level-up
    scores(w, T.TAV, { Strength = 21, Dexterity = 14, Constitution = 12, Intelligence = 8, Wisdom = 17, Charisma = 10 })
    svc:ReconcileAll(true)
    T.eq(svc.State:Get(T.TAV).BestStat, "Wisdom", "gear does not count before a level-up")
    w.fire("LeveledUp", "S_Player_" .. T.TAV)
    T.eq(svc.State:Get(T.TAV).BestStat, "Wisdom", "checked a moment after the level-up")
    w.runTimers()
    local c = w.chars[T.TAV]
    T.eq(svc.State:Get(T.TAV).BestStat, "Strength")
    T.truthy(c.passives.FFTJ_Cast_Str_Target_FFTJ_Rush)
    T.falsy(c.passives.FFTJ_Cast_Wis_Target_FFTJ_Rush, "the old one is removed")
    T.contains(w.notifications, "Tav's job skills now use Strength, the highest ability.")
end

function S.flasks_keep_intelligence_when_the_switch_is_off(w, T)
    local svc = boot(w, T, { extra = { Rules = { HighestStatCasting = false } } })
    T.truthy(svc:SetPrimary(T.TAV, "Chemist"))
    svc:AddManualJP(T.TAV, 600, "Chemist")
    T.truthy(svc:Learn(T.TAV, "ChemicalMixup"))
    T.truthy(svc:Learn(T.TAV, "Potion"))
    local c = w.chars[T.TAV]
    T.truthy(c.passives.FFTJ_Cast_Int_Projectile_FFTJ_ChemicalMixup, "the flask keeps Intelligence")
    T.truthy(c.passives.FFTJ_Cast_Int_Projectile_FFTJ_ChemicalMixup_Slot, "and so does its spell-slot version")
    T.truthy(c.spells.Target_FFTJ_Potion_Slot, "other skills are added plainly")
    T.falsy(c.passives.FFTJ_Cast_Wis_Target_FFTJ_Potion_Slot)
end

function S.flasks_follow_the_highest_ability_when_on(w, T)
    local svc = boot(w, T)
    svc:SetPrimary(T.TAV, "Chemist")
    svc:AddManualJP(T.TAV, 600, "Chemist")
    svc:Learn(T.TAV, "ChemicalMixup")
    local c = w.chars[T.TAV]
    T.truthy(c.passives.FFTJ_Cast_Wis_Projectile_FFTJ_ChemicalMixup)
    T.truthy(c.passives.FFTJ_Cast_Wis_Projectile_FFTJ_ChemicalMixup_Slot)
    T.falsy(c.passives.FFTJ_Cast_Int_Projectile_FFTJ_ChemicalMixup)
end

function S.unreadable_scores_fall_back_and_move_later(w, T)
    local svc = T.boot(w) -- no ability scores on the mock characters
    svc:AddManualJP(T.TAV, 100, "Squire")
    svc:Learn(T.TAV, "Rush")
    local c = w.chars[T.TAV]
    T.eq(svc.State:Get(T.TAV).BestStat, nil)
    T.truthy(c.spells.Target_FFTJ_Rush, "added plainly while the scores are unknown")
    scores(w, T.TAV, SCORES)
    T.contains(w.console("fft_beststat", "Tav"), "Tav: job skills cast with Wisdom")
    T.falsy(c.spells.Target_FFTJ_Rush, "the plain spell goes")
    T.truthy(c.passives.FFTJ_Cast_Wis_Target_FFTJ_Rush, "the Wisdom one comes")
end

function S.fulminate_blast_uses_the_throwers_highest_ability(w, T)
    boot(w, T)
    local gob = w.newChar(GOB, { name = "Goblin", level = 3, player = false, party = false, maxHp = 40, hp = 40 })
    w.fire("StatusApplied", "S_" .. GOB, "FFTJ_FULMINATE", "S_Player_" .. T.TAV, 0)
    T.truthy(gob.statuses.FFTJ_FULMINATE_BLAST_Wis, "Constitution save against Tav's Wisdom DC")
    T.eq(gob.statuses.FFTJ_FULMINATE_BLAST, nil)
    w.fire("StatusApplied", "S_" .. GOB, "FFTJ_FULMINATE_3", "S_Player_" .. T.TAV, 0)
    T.truthy(gob.statuses.FFTJ_FULMINATE_BLAST_3_Wis, "the level 3 blast too")
end

function S.every_job_spell_has_six_cast_passives(w, T, Mocks)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local text = read(Mocks, "Passive_FFTJ_Cast.txt")
    local n = 0
    for spell in pairs(Data.StatCast.Spells) do
        n = n + 1
        for stat, short in pairs(Data.StatCast.Short) do
            T.contains(entry(text, "FFTJ_Cast_" .. short .. "_" .. spell), "," .. stat .. ')"', spell .. " " .. stat)
        end
    end
    T.truthy(n > 500, "job spells and their Echo twins: " .. n)
    T.contains(entry(text, "FFTJ_Cast_Wis_Projectile_FFTJ_ChemicalMixup"), "UnlockSpell(Projectile_FFTJ_ChemicalMixup,,,,Wisdom)")
    T.contains(entry(text, "FFTJ_Cast_Wis_Projectile_FFTJ_ChemicalMixup_Slot"),
        "UnlockSpell(Projectile_FFTJ_ChemicalMixup_Slot,AddChildren,d136c5d9-0ff0-43da-acce-a74a07f8d6bf,,Wisdom)",
        "spell-slot skills bring their upcast levels")
    T.eq(Data.StatCast.Spells.Shout_FFTJ_JobBoard, nil, "the Job Board is no job skill")
    T.eq(Data.StatCast.Default.Projectile_FFTJ_ChemicalMixup, "Intelligence")
    T.falsy(read(Mocks, "Spell_FFTJ.txt"):find("ManeuverSaveDC", 1, true), "maneuver DCs follow the casting ability")
    T.contains(entry(read(Mocks, "Status_FFTJ_Cast.txt"), "FFTJ_FULMINATE_BLAST_Wis"), "CalculateSpellDC(Ability.Wisdom, context.Source)")
end

function S.flask_spell_slot_versions_start_at_level_1_with_an_icon(w, T, Mocks)
    local text = read(Mocks, "Spell_FFTJ_Upcast.txt")
    for _, root in ipairs({ "Projectile_FFTJ_ChemicalMixup", "Projectile_FFTJ_CausticFlask" }) do
        local slot = entry(text, root .. "_Slot")
        T.contains(slot, 'data "Level" "1"', root)
        T.contains(slot, "SpellSlotsGroup:1:1:1", root)
        T.contains(slot, 'data "Icon" "', root .. " has its own icon line")
        T.contains(entry(text, root .. "_Slot_2"), 'data "Icon" "', root .. " level 2")
    end
end

return S
