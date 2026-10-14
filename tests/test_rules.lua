-- Pure rules: levels, unlocks, JP formulas, learning, slots, grants.
local S = {}

local function setup()
    local Rules = Ext.Require("Server/Rules.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    return Rules, Data
end

function S.job_level_thresholds(w, T)
    local Rules = setup()
    local th = { 200, 400, 700, 1100, 1600, 2200, 3000 }
    T.eq(Rules.JobLevel(0, th), 1)
    T.eq(Rules.JobLevel(199, th), 1)
    T.eq(Rules.JobLevel(200, th), 2)
    T.eq(Rules.JobLevel(699, th), 3)
    T.eq(Rules.JobLevel(700, th), 4)
    T.eq(Rules.JobLevel(2999, th), 7)
    T.eq(Rules.JobLevel(3000, th), 8)
    T.eq(Rules.JobLevel(99999, th), 8)
    T.eq(Rules.NextThreshold(250, th), 400)
    T.eq(Rules.NextThreshold(3000, th), nil)
end

function S.new_char_has_starting_jobs(w, T)
    local Rules, Data = setup()
    local char = Rules.NewChar(Data, T.cfg(), "Chemist")
    T.eq(char.Primary, "Chemist")
    T.truthy(Rules.IsUnlocked(char, "Squire"))
    T.truthy(Rules.IsUnlocked(char, "Chemist"))
    T.falsy(Rules.IsUnlocked(char, "Knight"))
    T.eq(char.Jobs.Chemist.Earned, 0)
end

function S.add_jp_keeps_fractions(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local r = Rules.AddJP(Data, cfg, char, "Squire", 2.5)
    T.eq(r.Added, 2)
    r = Rules.AddJP(Data, cfg, char, "Squire", 2.5)
    T.eq(r.Added, 3, "the two halves add up")
    T.eq(char.Jobs.Squire.Earned, 5)
    T.eq(char.Jobs.Squire.Unspent, 5)
    T.eq(Rules.AddJP(Data, cfg, char, "Squire", -5).Added, 0, "negative amounts are ignored")
    T.eq(Rules.AddJP(Data, cfg, char, "Squire", 0 / 0).Added, 0, "NaN is ignored")
    -- every TIC job is built now: simulate one that isn't (the data copy belongs to this test's world)
    Data.Jobs.Arithmetician.Implemented = false
    T.eq(Rules.AddJP(Data, cfg, char, "Arithmetician", 50).Added, 0, "unimplemented job")
end

function S.unlock_knight_and_archer_at_squire_2(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local r = Rules.AddJP(Data, cfg, char, "Squire", 199)
    T.eq(#r.Unlocked, 0)
    T.falsy(Rules.IsUnlocked(char, "Knight"))
    r = Rules.AddJP(Data, cfg, char, "Squire", 1)
    T.eq(r.LevelBefore, 1)
    T.eq(r.LevelAfter, 2)
    T.eq(table.concat(r.Unlocked, ","), "Knight,Archer")
    T.truthy(Rules.IsUnlocked(char, "Archer"))
    T.falsy(Rules.IsUnlocked(char, "WhiteMage"))
    r = Rules.AddJP(Data, cfg, char, "Chemist", 200)
    T.eq(table.concat(r.Unlocked, ","), "WhiteMage,BlackMage")
end

function S.custom_thresholds_change_levels(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg({ JobLevels = { Thresholds = { 50, 100, 150, 200, 250, 300, 350 } } })
    local char = Rules.NewChar(Data, cfg, "Squire")
    local r = Rules.AddJP(Data, cfg, char, "Squire", 120)
    T.eq(r.LevelAfter, 3)
    T.contains(r.Unlocked, "Knight")
end

function S.requirements_text_and_missing(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    T.eq(Rules.RequirementText(Data, "Knight"), "Squire Lv2")
    T.eq(Rules.RequirementText(Data, "Squire"), "Starting job")
    local met, missing = Rules.RequirementsMet(Data, cfg, char, "WhiteMage")
    T.falsy(met)
    T.eq(missing[1].Job, "Chemist")
    T.eq(missing[1].Level, 2)
end

function S.jp_formulas(w, T)
    local Rules = setup()
    local jp = T.cfg().JP
    local own, spill = Rules.ActionJP(jp, 1, 3, 1, false)
    T.near(own, 13, 1e-9, "(8 + 2*1 + floor(3/4)) * 1.3")
    T.near(spill, 2.5)
    own = Rules.ActionJP(jp, 1, 3, 1, true)
    T.near(own, 19.5, 1e-9, "JP Boost x1.5")
    own, spill = Rules.ActionJP(jp, 3, 8, 1, false)
    T.near(own, 16 * 1.3)
    T.near(spill, 4)
    own = Rules.ActionJP(jp, 1, 3, 0.5, false)
    T.near(own, 6.5, 1e-9, "bonus action weight")
    T.near(Rules.VictoryJP(jp, 3, false), 26)
    T.near(Rules.VictoryJP(jp, 3, true), 39)
    T.near(Rules.XPJP(jp, 300, false), 30)
    T.near(Rules.XPJP(jp, 300, true), 45)
    T.near(Rules.RestJP(jp, false), 25)
    T.near(Rules.CampJP(jp, 40), 20)
    local g = T.cfg({ JP = { GlobalMultiplier = 2 } }).JP
    own, spill = Rules.ActionJP(g, 1, 3, 1, false)
    T.near(own, 26)
    T.near(spill, 5)
    T.near(Rules.XPJP(g, 300, false), 60)
    T.near(Rules.CampJP(g, 40), 20, 1e-9, "camp share is not multiplied twice")
    local noBoostXP = T.cfg({ JP = { Boost = { XP = false } } }).JP
    T.near(Rules.XPJP(noBoostXP, 300, true), 30, 1e-9, "boost can be limited per source")
    local noChar = T.cfg({ JP = { Action = { CharLevelDivisor = 0 } } }).JP
    T.near(Rules.ActionFormula(noChar, 1, 12), 10)
end

function S.shared_learning_amounts(w, T)
    local Rules = setup()
    local jp = T.cfg({ JP = { Shared = { Share = 0.15 } } }).JP
    T.near(Rules.SharedJP(jp, 100, "Action"), 15)
    T.near(Rules.SharedJP(jp, 100, "Victory"), 15)
    T.near(Rules.SharedJP(jp, 100, "XP"), 15)
    T.near(Rules.SharedJP(jp, 100, "Rest"), 15, 1e-9, "source Rest is Sources.LongRest")
    T.near(Rules.SharedJP(jp, 100, "Camp"), 15)
    T.eq(Rules.SharedJP(jp, 100, "Spill"), 0, "spillover is not shared")
    T.eq(Rules.SharedJP(jp, 100, "Manual"), 0, "console JP is not shared")
    T.eq(Rules.SharedJP(jp, 100, "Shared"), 0, "shared JP does not share again")
    T.eq(Rules.SharedJP(jp, -5, "Action"), 0)
    T.eq(Rules.SharedJP(jp, 0 / 0, "Action"), 0)
    local noXP = T.cfg({ JP = { Shared = { Share = 0.15, Sources = { XP = false } } } }).JP
    T.eq(Rules.SharedJP(noXP, 100, "XP"), 0, "a source can be left out")
    T.eq(Rules.SharedJP(T.cfg().JP, 100, "Action"), 0, "Share 0 turns it off")
end

function S.shared_learning_targets(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg({ JP = { Shared = { Share = 0.15 } } })
    local char = Rules.NewChar(Data, cfg, "Squire")
    local others = {}
    for _, id in ipairs(Data.JobOrder) do
        if id ~= "Squire" and Data.Jobs[id].Implemented then
            others[#others + 1] = id
        end
    end
    T.eq(table.concat(Rules.SharedTargets(Data, cfg, char, "Squire"), ","), table.concat(others, ","),
        "every other implemented job, locked ones included")
    T.truthy(#others >= 19)
    local fight = T.cfg({ JP = { Shared = { Share = 0.15, Scope = "FightJobs" } } })
    T.eq(table.concat(Rules.SharedTargets(Data, fight, char, "Squire", { Squire = true, Knight = true }), ","), "Knight",
        "FightJobs: only the jobs used in the fight")
    T.eq(#Rules.SharedTargets(Data, fight, char, "Squire", nil), 0, "no fight yet")
    local unlocked = T.cfg({ JP = { Shared = { Share = 0.15, RequireUnlocked = true } } })
    T.eq(table.concat(Rules.SharedTargets(Data, unlocked, char, "Squire"), ","), "Chemist", "only unlocked jobs")
end

function S.learning_costs_and_errors(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local ok, err = Rules.Learn(Data, char, "Focus")
    T.falsy(ok)
    T.contains(err, "needs 300 JP in Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 350)
    local info
    ok, err, info = Rules.Learn(Data, char, "Focus")
    T.truthy(ok, err)
    T.falsy(info.Mastered)
    T.eq(char.Jobs.Squire.Unspent, 50)
    T.eq(char.Jobs.Squire.Earned, 350, "spending does not lower earned JP or the job level")
    ok, err = Rules.Learn(Data, char, "Focus")
    T.falsy(ok)
    T.contains(err, "already learned")
    ok, err = Rules.Learn(Data, char, "RendArmor")
    T.falsy(ok)
    T.contains(err, "needs 400 JP in Knight", "350 Squire JP = job level 2, so Knight is already unlocked")
    ok, err = Rules.Learn(Data, char, "Cure")
    T.falsy(ok)
    T.contains(err, "White Mage is still locked (Chemist Lv2)")
    ok, err = Rules.Learn(Data, char, "Nope")
    T.falsy(ok)
    T.contains(err, "Unknown ability")
end

function S.mastery_after_all_abilities(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 1470)
    local last
    for _, aid in ipairs(Data.AbilitiesByJob.Squire) do
        local ok, err, info = Rules.Learn(Data, char, aid)
        T.truthy(ok, err)
        last = info
    end
    T.truthy(last.Mastered)
    T.truthy(Rules.IsMastered(Data, char, "Squire"))
    T.eq(char.Jobs.Squire.Unspent, 0, "Squire costs exactly 1470 JP to master")
    T.falsy(Rules.IsMastered(Data, char, "Chemist"))
end

function S.primary_and_secondary_rules(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local ok, err = Rules.SetPrimary(Data, char, "Knight")
    T.falsy(ok)
    T.contains(err, "locked")
    T.truthy(Rules.SetSecondary(Data, char, "Chemist"))
    ok, err = Rules.SetSecondary(Data, char, "Squire")
    T.falsy(ok)
    T.contains(err, "primary")
    T.truthy(Rules.SetPrimary(Data, char, "Chemist"))
    T.eq(char.Secondary, nil, "the secondary is cleared when it becomes the primary")
    T.truthy(Rules.SetSecondary(Data, char, nil))
    ok = Rules.SetPrimary(Data, char, "Monk")
    T.falsy(ok, "unimplemented jobs cannot be used")
end

function S.equip_and_unequip(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local ok, err = Rules.Equip(Data, char, "CounterTackle")
    T.falsy(ok)
    T.contains(err, "not learned")
    Rules.AddJP(Data, cfg, char, "Squire", 1000)
    T.truthy(Rules.Learn(Data, char, "CounterTackle"))
    T.truthy(Rules.Learn(Data, char, "JPBoost"))
    T.truthy(Rules.Learn(Data, char, "Movement1"))
    T.truthy(Rules.Learn(Data, char, "Focus"))
    local slot
    ok, err, slot = Rules.Equip(Data, char, "CounterTackle")
    T.truthy(ok, err)
    T.eq(slot, "Reaction")
    T.eq(select(3, Rules.Equip(Data, char, "JPBoost")), "Passive1", "first free passive slot")
    T.eq(select(3, Rules.Equip(Data, char, "Movement1")), "Passive2", "a movement ability takes a passive slot too")
    T.eq(char.Reaction, "CounterTackle")
    T.truthy(Rules.HasJPBoost(Data, char))
    T.truthy(Rules.Learn(Data, char, "EvasiveStance"))
    ok, err = Rules.Equip(Data, char, "EvasiveStance")
    T.falsy(ok, "both passive slots are full")
    T.contains(err, "name the slot to replace")
    T.eq(select(3, Rules.Equip(Data, char, "EvasiveStance", "1")), "Passive1", "replace slot 1")
    T.falsy(Rules.HasJPBoost(Data, char), "JP Boost was replaced")
    T.eq(select(3, Rules.Equip(Data, char, "EvasiveStance", "passive 2")), "Passive2", "moves, never in two slots")
    T.eq(char.Passive1, nil)
    ok, err = Rules.Equip(Data, char, "JPBoost", "reaction")
    T.falsy(ok)
    T.contains(err, "does not go in the reaction slot")
    ok, err = Rules.Equip(Data, char, "Focus")
    T.falsy(ok)
    T.contains(err, "action ability")
    T.truthy(Rules.Unequip(char, "2"))
    T.eq(char.Passive2, nil)
    ok, err = Rules.Unequip(char, "hat")
    T.falsy(ok)
end

function S.old_saves_move_support_and_movement_into_passive_slots(w, T)
    local Rules = setup()
    local char = Rules.Normalize({ Primary = "Squire", Support = "JPBoost", Movement = "Movement1" })
    T.eq(char.Passive1, "JPBoost")
    T.eq(char.Passive2, "Movement1")
    T.eq(char.Support, nil)
    T.eq(char.Movement, nil)
    char = Rules.Normalize({ Primary = "Squire", Movement = "Jump1" })
    T.eq(char.Passive1, "Jump1")
end

-- the spells without the job menus (tools/menu_gen.py; tests/test_menu.lua)
local function skills(d)
    local out = {}
    for id in pairs(d.Spells) do
        if not (id:find("^Shout_FFTJ_ChangeJob") or id:find("^Shout_FFTJ_SecondaryJob") or id:find("^Shout_FFTJ_Learn")) then
            out[id] = true
        end
    end
    return out
end

function S.desired_grants_primary_secondary_slots(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local d = Rules.DesiredGrants(Data, char)
    T.eq(T.keys(skills(d)), "Shout_FFTJ_JobBoard")
    T.eq(T.keys(d.Passives), "FFTJ_Job_Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 2000)
    Rules.AddJP(Data, cfg, char, "Chemist", 2000)
    for _, aid in ipairs({ "Focus", "Rush", "EvasiveStance", "Movement1", "CounterTackle" }) do
        T.truthy(Rules.Learn(Data, char, aid))
    end
    T.truthy(Rules.Learn(Data, char, "Potion"))
    d = Rules.DesiredGrants(Data, char)
    T.eq(T.keys(skills(d)), "Shout_FFTJ_Focus,Shout_FFTJ_JobBoard,Target_FFTJ_Rush", "only primary actions; supports need a slot")
    Rules.SetSecondary(Data, char, "Chemist")
    Rules.Equip(Data, char, "EvasiveStance")
    Rules.Equip(Data, char, "Movement1")
    d = Rules.DesiredGrants(Data, char)
    T.eq(T.keys(skills(d)), "Shout_FFTJ_Defend,Shout_FFTJ_Focus,Shout_FFTJ_JobBoard,Target_FFTJ_Potion,Target_FFTJ_Potion_Slot,Target_FFTJ_Rush")
    T.eq(T.keys(d.Passives), "FFTJ_Job_Squire,FFTJ_Movement1")
    Rules.SetPrimary(Data, char, "Chemist")
    d = Rules.DesiredGrants(Data, char)
    T.eq(T.keys(skills(d)), "Shout_FFTJ_Defend,Shout_FFTJ_JobBoard,Target_FFTJ_Potion_Slot,Target_FFTJ_Potion_Throw",
        "Chemist primary throws items; Squire actions are gone with no secondary")
    T.eq(T.keys(d.Passives), "FFTJ_Job_Chemist,FFTJ_Movement1")
end

function S.throw_items_variant(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    Rules.AddJP(Data, cfg, char, "Chemist", 1000)
    T.truthy(Rules.Learn(Data, char, "Potion"))
    T.truthy(Rules.Learn(Data, char, "ThrowItems"))
    Rules.SetSecondary(Data, char, "Chemist")
    T.truthy(Rules.DesiredGrants(Data, char).Spells.Target_FFTJ_Potion)
    T.truthy(Rules.Equip(Data, char, "ThrowItems"))
    local d = Rules.DesiredGrants(Data, char)
    T.truthy(d.Spells.Target_FFTJ_Potion_Throw)
    T.falsy(d.Spells.Target_FFTJ_Potion)
    T.truthy(d.Passives.FFTJ_ThrowItems)
end

function S.find_job_and_ability_from_text(w, T)
    local Rules, Data = setup()
    T.eq(Rules.FindJob(Data, "white mage"), "WhiteMage")
    T.eq(Rules.FindJob(Data, "WHITEMAGE"), "WhiteMage")
    T.eq(Rules.FindJob(Data, "black"), "BlackMage")
    T.eq(Rules.FindJob(Data, "arithmetician"), "Arithmetician")
    -- every TIC job is built now: simulate one that isn't (the data copy belongs to this test's world)
    Data.Jobs.Arithmetician.Implemented = false
    T.eq(Rules.FindJob(Data, "arithmetician"), nil, "not implemented")
    T.eq(Rules.FindJob(Data, "time mage"), "TimeMage")
    T.eq(Rules.FindJob(Data, "ranger"), "Archer", "the Archer job is named Ranger")
    T.eq(Rules.FindAbility(Data, "Rooting Shot"), "RootingShot")
    T.eq(Rules.FindAbility(Data, "x-potion"), "XPotion")
    T.eq(Rules.FindAbility(Data, "know weakness"), "KnowWeakness")
    T.eq(Rules.FindAbility(Data, "Aim +1"), nil, "the Archer's Aim set is gone")
    T.eq(Rules.FindAbility(Data, ""), nil)
end

function S.normalize_fills_old_saves(w, T)
    local Rules = setup()
    local char = Rules.Normalize({ Primary = "Squire", Jobs = { Squire = { Earned = 10 } } })
    T.eq(char.Jobs.Squire.Unspent, 0)
    T.eq(type(char.Jobs.Squire.Learned), "table")
    T.eq(type(char.Granted.Statuses), "table")
    T.eq(char.Stats.Actions, 0)
    T.eq(type(char.SinceRest.JP), "table")
    T.eq(type(char.Badges), "table")
end

function S.only_the_best_jump_tier_is_granted(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    char.Unlocked.Dragoon = true
    char.Primary = "Dragoon"
    Rules.AddJP(Data, cfg, char, "Dragoon", 9000)
    T.truthy(Rules.Learn(Data, char, "HorizontalJump1"))
    T.truthy(Rules.Learn(Data, char, "VerticalJump2"))
    local d = Rules.DesiredGrants(Data, char, cfg)
    T.truthy(d.Spells.Projectile_FFTJ_Jump1)
    T.truthy(d.Passives.FFTJ_VerticalJump2)
    T.truthy(Rules.Learn(Data, char, "HorizontalJump3"))
    T.truthy(Rules.Learn(Data, char, "VerticalJump5"))
    d = Rules.DesiredGrants(Data, char, cfg)
    T.falsy(d.Spells.Projectile_FFTJ_Jump1, "a better Horizontal Jump replaces it")
    T.truthy(d.Spells.Projectile_FFTJ_Jump3)
    T.falsy(d.Passives.FFTJ_VerticalJump2)
    T.truthy(d.Passives.FFTJ_VerticalJump5, "only the highest Vertical Jump counts, as in FFT")
end

function S.slot_names_from_text(w, T)
    local Rules = setup()
    T.eq(Rules.SlotName("Reaction"), "Reaction")
    T.eq(Rules.SlotName("passive 1"), "Passive1")
    T.eq(Rules.SlotName("2"), "Passive2")
    T.eq(Rules.SlotName("P1"), "Passive1")
    T.eq(Rules.SlotName("support"), nil, "FFT's slot names are gone")
end

---------------------------------------------------------------- Fell Seal rules (phase 2)

function S.main_job_support_and_movement_are_always_on(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 2000)
    for _, aid in ipairs({ "JPBoost", "Movement1", "CounterTackle" }) do
        T.truthy(Rules.Learn(Data, char, aid))
    end
    local d = Rules.DesiredGrants(Data, char, cfg)
    T.eq(T.keys(d.Passives), "FFTJ_JPBoost,FFTJ_Job_Squire,FFTJ_Movement1", "reactions still need their slot")
    T.truthy(Rules.HasJPBoost(Data, char, cfg))
    T.truthy(Rules.IsAlwaysOn(Data, cfg, char, "JPBoost"))
    T.falsy(Rules.IsAlwaysOn(Data, cfg, char, "CounterTackle"))
    T.falsy(Rules.HasJPBoost(Data, char), "without the config: slots only")
    Rules.SetPrimary(Data, char, "Knight")
    T.falsy(Rules.HasJPBoost(Data, char, cfg), "another main job")
    T.eq(T.keys(Rules.DesiredGrants(Data, char, cfg).Passives), "FFTJ_Job_Knight")
    local all = T.cfg({ Rules = { MainJobAlwaysOn = { "Support", "Movement", "Reaction" } } })
    Rules.SetPrimary(Data, char, "Squire")
    T.truthy(Rules.DesiredGrants(Data, char, all).Passives.FFTJ_CounterTackle)
    local off = T.cfg({ Rules = { MainJobAlwaysOn = {} } })
    T.eq(T.keys(Rules.DesiredGrants(Data, char, off).Passives), "FFTJ_Job_Squire")
end

function S.always_on_and_slot_are_not_granted_twice(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 2000)
    T.truthy(Rules.Learn(Data, char, "JPBoost"))
    T.truthy(Rules.Equip(Data, char, "JPBoost"))
    T.eq(#Rules.ActivePassives(Data, char, cfg), 1)
end

function S.mastery_perk_follows_mastery(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    Rules.AddJP(Data, cfg, char, "Squire", 200) -- unlocks Archer
    Rules.AddJP(Data, cfg, char, "Archer", 9000)
    T.truthy(Rules.IsLearned(char, "RootingShot"), "the Ranger starts with Rooting Shot")
    for _, aid in ipairs(Data.AbilitiesByJob.Archer) do
        T.falsy(Rules.DesiredGrants(Data, char, cfg).Passives.FFTJ_Mastery_Archer)
        if not Rules.IsLearned(char, aid) then
            T.truthy(Rules.Learn(Data, char, aid))
        end
    end
    T.truthy(Rules.IsMastered(Data, char, "Archer"))
    T.truthy(Rules.DesiredGrants(Data, char, cfg).Passives.FFTJ_Mastery_Archer, "granted while Squire is the job")
    T.truthy(Rules.HasMasteryPerk(Data, cfg, char, "Archer"))
    T.falsy(Rules.DesiredGrants(Data, char, T.cfg({ Rules = { MasteryPerks = false } })).Passives.FFTJ_Mastery_Archer)
    T.falsy(Rules.DesiredGrants(Data, char).Passives.FFTJ_Mastery_Archer, "without the config: off")
end

function S.retired_abilities_refund_their_jp(w, T)
    local Rules, Data = setup()
    local char = Rules.Normalize({ Primary = "Squire", Reaction = "SpeedSurge", Passive1 = "Concentration",
        Passive2 = "EquipCrossbows", Jobs = { Archer = { Earned = 3000, Unspent = 50,
        Learned = { Aim20 = true, Concentration = true, EquipCrossbows = true, Jump1 = true } } } })
    local out = Rules.MigrateRetired(Data, char)
    T.eq(#out, 1)
    T.eq(out[1].Job, "Archer")
    T.eq(out[1].Refund, 900 + 400 + 200)
    T.eq(table.concat(out[1].Replaced, ","), "Equip Bows")
    T.eq(char.Jobs.Archer.Unspent, 50 + 1500)
    T.eq(char.Jobs.Archer.Earned, 3000)
    T.falsy(char.Jobs.Archer.Learned.Aim20)
    T.truthy(char.Jobs.Archer.Learned.EquipBows)
    T.eq(char.Reaction, nil, "a retired reaction leaves its slot")
    T.eq(char.Passive1, nil)
    T.eq(char.Passive2, "EquipBows", "the replacement takes the slot")
    T.eq(#Rules.MigrateRetired(Data, char), 0, "only once")
    local mime = table.concat(Data.Jobs.Mime.Innate.Passives, ",")
    T.truthy(string.find(mime, "FFTJ_Concentration", 1, true), "the Mime keeps Concentration")
end

-- Data with a made-up special job (not in the data): Test Knight needs the Test Knight Badge and Knight Lv3.
local function badgeData(Data)
    local Util = Ext.Require("Shared/Util.lua")
    local d = Util.DeepCopy(Data)
    d.Jobs.TestKnight = { Id = "TestKnight", Name = "Test Knight", Implemented = true, Order = #d.JobOrder + 1,
        Unlock = { { Badge = "TestKnight" }, { Job = "Knight", Level = 3 } }, Innate = {}, Equip = "" }
    d.JobOrder[#d.JobOrder + 1] = "TestKnight"
    d.AbilitiesByJob.TestKnight = {}
    d.Badges.TestKnight = { Id = "TestKnight", Name = "Test Knight Badge", Description = "test" }
    d.BadgeOrder[#d.BadgeOrder + 1] = "TestKnight"
    return d
end

function S.badge_requirements(w, T)
    local Rules, Data = setup()
    local data = badgeData(Data)
    local cfg = T.cfg()
    T.eq(Rules.RequirementText(data, "TestKnight"), "Test Knight Badge, Knight Lv3")
    local a = Rules.NewChar(data, cfg, "Squire")
    local b = Rules.NewChar(data, cfg, "Squire")
    local chars, party = { A = a, B = b }, {}
    Rules.AddJP(data, cfg, a, "Squire", 200)
    Rules.AddJP(data, cfg, a, "Knight", 400)
    local met, missing = Rules.RequirementsMet(data, cfg, a, "TestKnight")
    T.falsy(met)
    T.eq(missing[1].Badge, "TestKnight")
    T.falsy(Rules.AddBadge(data, cfg, chars, party, "Crown"), "unknown badge")
    local ok, err, info = Rules.AddBadge(data, cfg, chars, party, "TestKnight")
    T.truthy(ok, err)
    T.eq(#info.Unlocked, 1, "only A has the job levels")
    T.eq(info.Unlocked[1].Guid, "A")
    T.eq(info.Unlocked[1].Job, "TestKnight")
    T.truthy(Rules.HasBadge(b, "TestKnight"), "the badge serves the whole party")
    T.falsy(Rules.IsUnlocked(b, "TestKnight"), "B still needs Knight Lv3 itself")
    T.truthy(Rules.IsPartyUnlocked(party, "TestKnight"))
    T.eq(Rules.MissingText(data, cfg, b, "TestKnight"), "Knight Lv3 (has Lv1)")
    T.truthy(select(3, Rules.AddBadge(data, cfg, chars, party, "TestKnight")).Already)
    T.eq(Rules.FindBadge(data, "test knight badge"), "TestKnight")
end

function S.sync_party_shows_unlocks_and_shares_badges(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local a = Rules.NewChar(Data, cfg, "Squire")
    local b = Rules.NewChar(Data, cfg, "Chemist")
    local chars, party = { A = a, B = b }, { Badges = { Crest = true } }
    Rules.AddJP(Data, cfg, a, "Squire", 200)
    T.eq(table.concat(Rules.SyncParty(Data, chars, party), ","), "Archer,Chemist,Knight,Squire", "new to the party")
    T.truthy(Rules.IsPartyUnlocked(party, "Knight"))
    T.falsy(Rules.IsUnlocked(b, "Knight"), "B needs its own Squire Lv2")
    T.eq(Rules.MissingText(Data, cfg, b, "Knight"), "Squire Lv2 (has Lv1)")
    T.falsy(Rules.SetPrimary(Data, b, "Knight"))
    T.truthy(b.Badges.Crest, "badges belong to the party")
    T.eq(#Rules.SyncParty(Data, chars, party), 0, "nothing new the second time")
end

function S.a_job_without_abilities_is_mastered_at_the_top_level(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    T.eq(#Data.AbilitiesByJob.Mime, 0, "the Mime has no abilities to learn")
    T.falsy(Rules.IsMastered(Data, char, "Mime", cfg))
    char.Jobs.Mime = { Earned = 999999, Unspent = 0, Learned = {} }
    T.truthy(Rules.IsMastered(Data, char, "Mime", cfg), "job level 8")
    T.falsy(Rules.IsMastered(Data, char, "Mime"), "needs the level thresholds")
end

function S.mastered_and_kill_requirements(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    T.eq(Rules.RequirementText(Data, "DarkKnight"),
        "Knight mastered, Black Mage mastered, Dragoon Lv8, Samurai Lv8, Ninja Lv8, Geomancer Lv8, 20 enemies defeated")
    local met, missing = Rules.RequirementsMet(Data, cfg, char, "DarkKnight")
    T.falsy(met)
    T.eq(#missing, 7)
    T.truthy(missing[1].Mastered)
    T.eq(missing[7].Kills, 20)
    T.contains({ Rules.MissingText(Data, cfg, char, "DarkKnight") }, "Knight mastered, Black Mage mastered, "
        .. "Dragoon Lv8 (has Lv1), Samurai Lv8 (has Lv1), Ninja Lv8 (has Lv1), Geomancer Lv8 (has Lv1), "
        .. "20 enemies defeated (has 0)")
    char.Kills = 20
    for _, aid in ipairs(Data.AbilitiesByJob.Knight) do
        Rules.EnsureJob(char, "Knight").Learned[aid] = true
    end
    met, missing = Rules.RequirementsMet(Data, cfg, char, "DarkKnight")
    T.eq(#missing, 5, "Knight mastered and 20 kills are done")
    T.eq(missing[1].Job, "BlackMage")
    T.eq(Rules.Normalize({}).Kills, 0, "older saves start at 0 kills")
end

function S.onion_knight_grows_with_job_level_and_rests_its_slots(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    local function first(job, typ)
        for _, aid in ipairs(Data.AbilitiesByJob[job]) do
            if Data.Abilities[aid].Type == typ then
                Rules.EnsureJob(char, job).Learned[aid] = true
                return Data.Abilities[aid]
            end
        end
    end
    local support, action = first("Squire", "Support"), first("Chemist", "Action")
    char.Passive1, char.Secondary = support.Id, "Chemist"
    char.Unlocked.OnionKnight, char.Primary = true, "OnionKnight"
    Rules.EnsureJob(char, "OnionKnight")
    local d = Rules.DesiredGrants(Data, char, cfg)
    T.truthy(d.Passives.FFTJ_Job_OnionKnight)
    T.falsy(d.Passives.FFTJ_OnionKnight_5, "Lv1: nothing yet")
    T.falsy(d.Passives[support.Grants.Passives[1]], "a slotted support rests")
    T.falsy(d.Spells[action.Grants.Spells[1]], "so does the secondary")
    T.eq(#Rules.ActivePassives(Data, char, cfg), 0)
    char.Jobs.OnionKnight.Earned = 1100
    d = Rules.DesiredGrants(Data, char, cfg)
    T.truthy(d.Passives.FFTJ_OnionKnight_5, "Lv5")
    T.falsy(d.Passives.FFTJ_OnionKnight_8)
    char.Jobs.OnionKnight.Earned = 3000
    d = Rules.DesiredGrants(Data, char, cfg)
    T.truthy(d.Passives.FFTJ_OnionKnight_8, "Lv8")
    T.falsy(d.Passives.FFTJ_OnionKnight_5, "only the highest tier")
    T.truthy(Rules.IsMastered(Data, char, "OnionKnight", cfg), "no abilities: mastered at job level 8")
    T.truthy(d.Passives.FFTJ_Mastery_OnionKnight)
    d = Rules.DesiredGrants(Data, char, T.cfg({ Rules = { OnionKnightBlocksSlots = false } }))
    T.truthy(d.Passives[support.Grants.Passives[1]], "switch off: slots work")
    T.truthy(d.Spells[action.Grants.Spells[1]])
    char.Primary = "Squire"
    d = Rules.DesiredGrants(Data, char, cfg)
    T.falsy(d.Passives.FFTJ_OnionKnight_8, "tiers only while it is the main job")
    T.truthy(d.Passives.FFTJ_Mastery_OnionKnight, "the mastery perk stays")
end

-- NWP 21: Brawler's extra die follows the character level; Martial Arts and its bonus strike are Monk innates.
function S.brawler_die_grows_with_character_level(w, T)
    local Rules, Data = setup()
    local cfg = T.cfg()
    local char = Rules.NewChar(Data, cfg, "Squire")
    char.Primary = "Monk"
    local d = Rules.DesiredGrants(Data, char)
    T.truthy(d.Passives.FFTJ_Brawler, "level 1: 1d6")
    T.truthy(d.Passives.FFTJ_MartialArts, "Martial Arts is innate")
    T.truthy(d.Spells.Target_FFTJ_MartialStrike, "the bonus strike is granted")
    char.Level = 5
    d = Rules.DesiredGrants(Data, char)
    T.falsy(d.Passives.FFTJ_Brawler, "replaced at 5")
    T.truthy(d.Passives.FFTJ_Brawler_5, "level 5: 1d8")
    char.Level = 9
    d = Rules.DesiredGrants(Data, char)
    T.truthy(d.Passives.FFTJ_Brawler_9, "level 9: 1d10")
    T.falsy(d.Passives.FFTJ_Brawler_5, "only the highest tier")
end

return S
