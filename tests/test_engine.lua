-- The engine through BootstrapServer.lua with a mock game: events -> JP, grants, rules, telemetry.
-- JP numbers use T.PINNED (Base 8, PerJobLevel 2, CharLevelDivisor 4, +30%, spill 1/4, victory 20+2/lvl,
-- XPShare 0.1, long rest 25, camp 1/2, JP Boost x1.5, bonus action x0.5). The party is level 3, job level 1:
-- one action = (8 + 2 + 0) * 1.3 = 13 JP, spillover 2.5 JP.
local S = {}

local function sum(svc, T, guid, jobId)
    return T.job(svc, guid, jobId).Earned
end

function S.boot_tracks_party_not_summons(w, T)
    local svc = T.boot(w)
    T.eq(table.concat(svc.State:Guids(), ","), table.concat({ T.TAV, T.SHART, T.ASTA }, ","))
    T.eq(svc.State:Get(T.TAV).Primary, "Squire", "Fighter starts as Squire")
    T.eq(svc.State:Get(T.SHART).Primary, "Chemist", "Cleric starts as Chemist")
    T.eq(svc.State:Get(T.SHART).Name, "Shadowheart")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JobBoard, "Job Board spell granted")
    T.truthy(w.chars[T.TAV].passives.FFTJ_Job_Squire, "job marker passive granted")
    T.truthy(w.chars[T.SHART].passives.FFTJ_Job_Chemist)
    T.eq(next(w.chars[T.SUMMON].spells), nil, "summons get nothing")
end

function S.events_before_session_load_are_ignored(w, T)
    T.party(w)
    local svc = w.bootServer()
    w.chars[T.TAV].inCombat = true
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.falsy(svc.State:IsLoaded(), "nothing is loaded or created before SessionLoaded")
    w.sessionLoaded()
    T.eq(#svc.State:Guids(), 0, "party discovery waits for LevelGameplayStarted")
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.eq(#svc.State:Guids(), 3)
end

function S.action_jp_and_spillover(w, T)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Squire"), 26)
    T.eq(sum(svc, T, T.SHART, "Squire"), 5, "1/4 spillover into the caster's job")
    T.eq(sum(svc, T, T.ASTA, "Squire"), 0, "not in the fight: no spillover")
    T.eq(svc.State:Get(T.TAV).Stats.Actions, 2)
end

function S.spillover_can_require_unlocked_job(w, T)
    local svc = T.boot(w, { extra = { JP = { Spillover = { RequireUnlocked = true } } } })
    svc:AddManualJP(T.TAV, 200, "Squire") -- unlocks Knight for Tav only
    svc:SetPrimary(T.TAV, "Knight")
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Knight"), 13)
    T.eq(sum(svc, T, T.SHART, "Knight"), 0, "Shadowheart has not unlocked Knight")
end

function S.action_weights_and_exclusions(w, T)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Shout_Dash")
    T.eq(sum(svc, T, T.TAV, "Squire"), 6, "bonus action: 13 * 0.5 = 6.5")
    T.cast(w, T.TAV, "Projectile_Jump")
    T.cast(w, T.TAV, "Interrupt_AttackOfOpportunity")
    T.cast(w, T.TAV, "Shout_Free")
    T.eq(sum(svc, T, T.TAV, "Squire"), 6, "jump, reactions and free casts earn nothing")
    T.cast(w, T.TAV, "Target_UnknownModSpell")
    T.eq(sum(svc, T, T.TAV, "Squire"), 19, "spells without readable stats count as an action (6.5 + 13)")
end

function S.no_action_jp_out_of_combat_by_default(w, T)
    local svc = T.boot(w)
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Squire"), 0)
end

function S.out_of_combat_jp_can_be_enabled(w, T)
    local svc = T.boot(w, { extra = { JP = { Action = { CountOutOfCombat = true } } } })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Squire"), 13)
end

function S.max_casts_per_turn(w, T)
    local svc = T.boot(w, { extra = { JP = { Action = { MaxPerTurn = 2 } } } })
    T.startCombat(w, "c1", { T.TAV })
    for _ = 1, 3 do
        T.cast(w, T.TAV, "Target_MainHandAttack")
    end
    T.eq(sum(svc, T, T.TAV, "Squire"), 26)
    w.fire("TurnStarted", "S_Player_" .. T.TAV)
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Squire"), 39, "the cap resets every turn")
end

function S.victory_and_camp_share(w, T, Mocks)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.endCombat(w, "c1", { T.TAV, T.SHART })
    T.eq(sum(svc, T, T.TAV, "Squire"), 26 + 26, "victory: 20 + 2 * level 3")
    T.eq(sum(svc, T, T.SHART, "Chemist"), 26)
    -- camp: average own JP of the fighters = ((26 + 26) + 26) / 2 = 39, times 1/2 = 19.5
    T.eq(sum(svc, T, T.ASTA, "Squire"), 19)
    local lines = {}
    for line in w.files["FFTJobs/telemetry.jsonl"]:gmatch("[^\n]+") do
        lines[#lines + 1] = Mocks.Json.decode(line)
    end
    local combat = lines[#lines]
    T.eq(combat.t, "combat")
    T.eq(combat.chars[T.TAV].actions, 2)
    T.eq(combat.chars[T.TAV].jp.Action, 26)
    T.eq(combat.chars[T.TAV].jp.Victory, 26)
    T.eq(combat.chars[T.SHART].jp.Spill, 5)
    T.eq(combat.camp[T.ASTA].jp, 19)
    T.eq(svc.State:Get(T.TAV).Stats.Combats, 1)
end

function S.dead_fighters_get_no_victory(w, T)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    w.chars[T.SHART].dead = true
    T.endCombat(w, "c1", { T.TAV, T.SHART })
    T.eq(sum(svc, T, T.SHART, "Chemist"), 0)
    T.eq(sum(svc, T, T.TAV, "Squire"), 26)
end

function S.fighters_without_entered_combat_still_count(w, T)
    local svc = T.boot(w)
    w.chars[T.TAV].inCombat = true -- e.g. a save loaded in the middle of a fight
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.endCombat(w, "c9", { T.TAV })
    T.eq(sum(svc, T, T.TAV, "Squire"), 13 + 26)
end

function S.xp_share_from_polling(w, T)
    local svc = T.boot(w)
    T.truthy(#w.timers >= 1, "XP poll timer started")
    w.chars[T.TAV].xp = 1500
    w.runTimers()
    T.eq(sum(svc, T, T.TAV, "Squire"), 50, "500 XP * 0.1")
    T.eq(svc.State:Get(T.TAV).LastXP, 1500)
    T.eq(svc.State:Get(T.TAV).Stats.XP, 500)
    T.truthy(#w.timers >= 1, "the poll re-arms itself")
    w.chars[T.TAV].xp = 100 -- respec or another save: rebase, no JP
    w.runTimers()
    T.eq(sum(svc, T, T.TAV, "Squire"), 50)
    T.eq(svc.State:Get(T.TAV).LastXP, 100)
end

function S.first_xp_reading_is_only_a_baseline(w, T)
    T.party(w)
    w.chars[T.TAV].xp = 50000
    local svc = T.boot(w, { noParty = true })
    T.eq(sum(svc, T, T.TAV, "Squire"), 0, "no retroactive JP for XP earned before the mod")
end

function S.long_rest_training_and_record(w, T, Mocks)
    local svc = T.boot(w)
    w.fire("LongRestFinished")
    w.tick()
    T.eq(sum(svc, T, T.TAV, "Squire"), 25)
    T.eq(sum(svc, T, T.SHART, "Chemist"), 25)
    local last
    for line in w.files["FFTJobs/telemetry.jsonl"]:gmatch("[^\n]+") do
        last = Mocks.Json.decode(line)
    end
    T.eq(last.t, "rest")
    T.eq(last.chars[T.TAV].jp.Rest, 25)
    T.eq(svc.State:Get(T.TAV).SinceRest.JP.Rest, nil, "counters restart after the rest")
end

function S.jp_boost_multiplies_own_jp(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 250, "Squire")
    T.truthy(svc:Learn(T.TAV, "JPBoost"))
    T.truthy(svc:Equip(T.TAV, "JPBoost"))
    local before = sum(svc, T, T.TAV, "Squire")
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack") -- job level 2 now: (8 + 4) * 1.3 * 1.5 = 23.4
    T.eq(sum(svc, T, T.TAV, "Squire") - before, 23)
    T.eq(sum(svc, T, T.SHART, "Squire"), 3, "spillover is not boosted: 12 * 0.25")
    T.truthy(w.chars[T.TAV].passives.FFTJ_JPBoost)
end

local SHARED = { JP = { Shared = { Share = 0.15 } } }

function S.shared_learning_feeds_every_other_job(w, T)
    local svc = T.boot(w, { extra = SHARED })
    w.chars[T.TAV].xp = 1500
    w.runTimers()
    T.eq(sum(svc, T, T.TAV, "Squire"), 50, "500 XP * 0.1")
    for _, job in ipairs({ "Chemist", "Knight", "Archer", "WhiteMage", "BlackMage", "Monk", "Thief", "TimeMage", "Mystic",
        "Geomancer", "Dragoon", "Summoner", "Orator", "Samurai", "Ninja", "Bard", "Dancer", "Mime" }) do
        T.eq(sum(svc, T, T.TAV, job), 7, job .. ": 15% of 50 = 7.5, locked jobs included")
    end
    T.eq(svc.State:Get(T.TAV).Stats.JP.Shared, 126, "18 other jobs x 7")
    T.eq(sum(svc, T, T.SHART, "Knight"), 0, "only the earner's own jobs")
end

function S.spillover_and_console_jp_are_not_shared(w, T)
    local svc = T.boot(w, { extra = SHARED })
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Knight"), 1, "15% of 13 = 1.95")
    T.eq(sum(svc, T, T.SHART, "Squire"), 2, "spillover 2.5")
    T.eq(sum(svc, T, T.SHART, "Knight"), 0, "spillover does not share")
    svc:AddManualJP(T.ASTA, 100, "Squire")
    T.eq(sum(svc, T, T.ASTA, "Chemist"), 0, "console JP does not share")
end

function S.shared_learning_goes_into_jobs_used_in_combat(w, T)
    local svc = T.boot(w, { extra = { JP = { Shared = { Share = 0.15, Scope = "FightJobs" } } } })
    w.chars[T.TAV].xp = 1500
    w.runTimers()
    T.eq(sum(svc, T, T.TAV, "Squire"), 50)
    T.eq(sum(svc, T, T.TAV, "Chemist"), 0, "no fight yet: no jobs to share into")
    -- Tav (Squire) and Shadowheart (Chemist) fight; Astarion (Squire) waits in camp.
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.endCombat(w, "c1", { T.TAV, T.SHART })
    T.eq(sum(svc, T, T.TAV, "Chemist"), 7, "15% of 26 action + 26 victory JP = 7.8, into Shadowheart's job")
    T.eq(sum(svc, T, T.SHART, "Squire"), 8, "5 spillover + 15% of 26 victory JP")
    T.eq(sum(svc, T, T.ASTA, "Chemist"), 2, "camp share 19.5: 15% into the fight's other job")
    for _, guid in ipairs({ T.TAV, T.SHART, T.ASTA }) do
        T.eq(sum(svc, T, guid, "Knight"), 0, "nobody used Knight")
    end
    T.eq(table.concat(svc.State:Meta().LastFightJobs, ","), "Chemist,Squire", "saved for gains outside combat")
    w.fire("LongRestFinished")
    w.tick()
    T.eq(sum(svc, T, T.TAV, "Chemist"), 11, "outside combat: the latest fight's jobs (7.8 + 3.75)")
end

function S.shared_jp_counts_toward_unlocks(w, T)
    local svc = T.boot(w, { extra = SHARED })
    w.chars[T.SHART].xp = 1000 + 13400 -- 1340 JP as a Chemist, 15% = 201 in Squire
    w.runTimers()
    T.eq(sum(svc, T, T.SHART, "Squire"), 201)
    T.truthy(svc.State:Get(T.SHART).Unlocked.Knight, "Squire Lv2 from shared JP unlocks Knight")
    T.contains(w.notifications, "Shadowheart unlocked the Knight job!")
end

function S.level_up_and_unlock_notifications(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 200, "Squire")
    T.contains(w.notifications, "Tav: Squire is now job level 2")
    T.contains(w.notifications, "Tav unlocked the Knight job!")
    T.contains(w.notifications, "Tav unlocked the Archer job!")
end

---------------------------------------------------------------- Fell Seal rules (phase 2)

function S.party_sees_unlocks_but_each_needs_own_levels(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 200, "Squire")
    T.truthy(svc.State:Meta().PartyUnlocked.Knight, "the party knows the job")
    T.falsy(svc.State:Get(T.SHART).Unlocked.Knight, "Shadowheart needs her own Squire Lv2")
    local ok, msg = svc:SetPrimary(T.SHART, "Knight")
    T.falsy(ok)
    T.contains(msg, "Knight is still locked")
    svc:AddManualJP(T.SHART, 400, "Knight")
    T.falsy(svc:Learn(T.SHART, "RendArmor"), "no learning from it either (400 JP is enough, the levels are not)")
    svc:AddManualJP(T.SHART, 200, "Squire")
    T.truthy(svc.State:Get(T.SHART).Unlocked.Knight, "her own levels unlock it")
    T.truthy(svc:Learn(T.SHART, "RendSpeed"), "and the Knight JP she collected is usable")
end

function S.companion_joining_later_gets_the_party_badges(w, T)
    local svc = T.boot(w)
    svc.State:Meta().Badges = { Crest = true }
    local gale = "55555555-5555-4555-8555-555555555555"
    w.newChar(gale, { name = "Gale", level = 3, xp = 1000, class = "Wizard" })
    w.fire("CharacterJoinedParty", "S_Player_" .. gale)
    T.truthy(svc.State:Get(gale).Badges.Crest)
end

function S.main_job_support_and_movement_work_without_a_slot(w, T)
    local svc = T.boot(w)
    local tav = w.chars[T.TAV]
    svc:AddManualJP(T.TAV, 1000, "Squire")
    T.truthy(svc:Learn(T.TAV, "JPBoost"))
    T.truthy(svc:Learn(T.TAV, "Movement1"))
    T.truthy(svc:Learn(T.TAV, "CounterTackle"))
    T.truthy(tav.passives.FFTJ_JPBoost, "the main job's support needs no slot")
    T.truthy(tav.passives.FFTJ_Movement1, "nor its movement ability")
    T.falsy(tav.passives.FFTJ_CounterTackle, "reactions still need the reaction slot (default)")
    local char = svc.State:Get(T.TAV)
    T.eq(char.Passive1, nil, "the passive slots stay free")
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(T.job(svc, T.TAV, "Squire").Earned, 1000 + 31, "JP Boost works from the job: (8 + 2 x Lv4) * 1.3 * 1.5")
    T.endCombat(w, "c1", { T.TAV })
    T.truthy(svc:SetPrimary(T.TAV, "Knight"))
    T.falsy(tav.passives.FFTJ_JPBoost, "another job: back to the slots")
    T.truthy(svc:Equip(T.TAV, "JPBoost"))
    T.truthy(tav.passives.FFTJ_JPBoost)
end

function S.main_job_reactions_can_be_always_on_too(w, T)
    local svc = T.boot(w, { extra = { Rules = { MainJobAlwaysOn = { "Support", "Movement", "Reaction" } } } })
    svc:AddManualJP(T.TAV, 300, "Squire")
    T.truthy(svc:Learn(T.TAV, "CounterTackle"))
    T.truthy(w.chars[T.TAV].passives.FFTJ_CounterTackle)
end

function S.mastery_perk_is_granted_and_kept(w, T)
    local svc = T.boot(w)
    local tav = w.chars[T.TAV]
    svc:AddManualJP(T.TAV, 5000, "Squire")
    local last
    for _, aid in ipairs(svc.Data.AbilitiesByJob.Squire) do
        T.falsy(tav.passives.FFTJ_Mastery_Squire, "no perk before the last ability")
        local ok, msg = svc:Learn(T.TAV, aid)
        T.truthy(ok, msg)
        last = msg
    end
    T.contains(last, "Squire mastered! Mastery perk, kept for good: +5 maximum hit points.")
    T.contains(w.notifications, "Tav mastered Squire! +5 maximum hit points.")
    T.truthy(tav.passives.FFTJ_Mastery_Squire)
    T.truthy(svc:SetPrimary(T.TAV, "Archer"))
    T.truthy(tav.passives.FFTJ_Mastery_Squire, "kept after changing jobs")
    T.falsy(w.chars[T.SHART].passives.FFTJ_Mastery_Squire, "per character")
end

function S.mastery_perks_can_be_turned_off(w, T)
    local svc = T.boot(w, { extra = { Rules = { MasteryPerks = false } } })
    svc:AddManualJP(T.TAV, 5000, "Squire")
    for _, aid in ipairs(svc.Data.AbilitiesByJob.Squire) do
        svc:Learn(T.TAV, aid)
    end
    T.falsy(w.chars[T.TAV].passives.FFTJ_Mastery_Squire)
end

-- A made-up special job for the badge tests: Holy Knight, needs the Holy Knight Badge and Knight Lv3.
local function addBadgeJob()
    local Data = Ext.Require("Shared/GeneratedData.lua")
    Data.Jobs.HolyKnight = { Id = "HolyKnight", Name = "Holy Knight", Skillset = "Holy Sword", Implemented = true,
        Order = #Data.JobOrder + 1, Unlock = { { Badge = "HolyKnight" }, { Job = "Knight", Level = 3 } },
        Innate = {}, Equip = "", Description = "test job" }
    Data.JobOrder[#Data.JobOrder + 1] = "HolyKnight"
    Data.AbilitiesByJob.HolyKnight = {}
    Data.Badges.HolyKnight = { Id = "HolyKnight", Name = "Holy Knight Badge", Description = "test badge" }
    Data.BadgeOrder[#Data.BadgeOrder + 1] = "HolyKnight"
end

function S.badge_and_job_levels_unlock_a_special_job(w, T)
    addBadgeJob()
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 200, "Squire")
    svc:AddManualJP(T.TAV, 400, "Knight")
    T.falsy(svc.State:Get(T.TAV).Unlocked.HolyKnight, "Knight Lv3 alone is not enough")
    local ok, msg = svc:AddBadge("HolyKnight")
    T.truthy(ok, msg)
    T.contains(msg, "The party found the Holy Knight Badge. Tav unlocked the Holy Knight job!")
    T.truthy(svc.State:Get(T.SHART).Badges.HolyKnight, "the badge serves everyone")
    T.falsy(svc.State:Get(T.SHART).Unlocked.HolyKnight, "but Shadowheart needs Knight Lv3 herself")
    T.contains(select(2, svc:AddBadge("HolyKnight")), "already has")
    local gale = "55555555-5555-4555-8555-555555555555"
    w.newChar(gale, { name = "Gale", level = 3, xp = 1000, class = "Wizard" })
    w.fire("CharacterJoinedParty", "S_Player_" .. gale)
    T.truthy(svc.State:Get(gale).Badges.HolyKnight, "a later member gets the party's badges")
end

function S.badge_first_then_job_levels(w, T)
    addBadgeJob()
    local svc = T.boot(w)
    T.truthy(svc:AddBadge("HolyKnight"))
    T.falsy(svc.State:Get(T.SHART).Unlocked.HolyKnight)
    svc:AddManualJP(T.SHART, 200, "Squire")
    svc:AddManualJP(T.SHART, 400, "Knight")
    T.truthy(svc.State:Get(T.SHART).Unlocked.HolyKnight, "the badge counts once the levels are there")
    T.falsy(svc.State:Get(T.TAV).Unlocked.HolyKnight, "each character needs its own levels")
    T.contains(w.notifications, "Shadowheart unlocked the Holy Knight job!")
end

function S.grants_follow_learning_and_job_changes(w, T)
    local svc = T.boot(w)
    local tav = w.chars[T.TAV]
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.truthy(svc:Learn(T.TAV, "Focus"))
    T.truthy(tav.spells.Shout_FFTJ_Focus, "learned Squire action granted while Squire is the job")
    T.truthy(svc:SetPrimary(T.TAV, "Knight"))
    T.falsy(tav.spells.Shout_FFTJ_Focus, "removed when it is neither primary nor secondary")
    T.falsy(tav.passives.FFTJ_Job_Squire)
    T.truthy(tav.passives.FFTJ_Job_Knight)
    T.truthy(svc:SetSecondary(T.TAV, "Squire"))
    T.truthy(tav.spells.Shout_FFTJ_Focus, "back as the secondary skill set")
    T.truthy(svc:SetSecondary(T.TAV, nil))
    T.falsy(tav.spells.Shout_FFTJ_Focus)
    T.truthy(tav.spells.Shout_FFTJ_JobBoard, "the Job Board spell always stays")
end

function S.grant_changes_are_logged(w, T)
    local svc = T.boot(w)
    T.contains(w.prints, "Tav: added Shout_FFTJ_JPTraining, Shout_FFTJ_JobBoard, FFTJ_Job_Squire")
    svc:AddManualJP(T.TAV, 300, "Squire")
    T.truthy(svc:Learn(T.TAV, "Focus"))
    T.contains(w.prints, "Tav: added Shout_FFTJ_Focus")
    T.truthy(svc:SetPrimary(T.TAV, "Knight"))
    T.contains(w.prints, "Tav: added FFTJ_Job_Knight; removed Shout_FFTJ_Focus, FFTJ_Job_Squire")
end

function S.support_and_movement_slots_grant_passives(w, T)
    local svc = T.boot(w, { extra = { Rules = { MainJobAlwaysOn = {} } } }) -- slots only, as before phase 2
    local tav = w.chars[T.TAV]
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.truthy(svc:Learn(T.TAV, "Movement1"))
    T.falsy(tav.passives.FFTJ_Movement1, "learning alone does not equip")
    T.truthy(svc:Equip(T.TAV, "Movement1"))
    T.truthy(tav.passives.FFTJ_Movement1)
    T.truthy(svc:Learn(T.TAV, "EvasiveStance"))
    T.truthy(svc:Equip(T.TAV, "EvasiveStance"))
    T.truthy(tav.spells.Shout_FFTJ_Defend, "a support can grant an action")
    T.eq(svc.State:Get(T.TAV).Passive2, "EvasiveStance", "the second free passive slot")
    T.truthy(svc:Unequip(T.TAV, "1"))
    T.falsy(tav.passives.FFTJ_Movement1)
end

function S.native_spells_are_never_removed(w, T)
    local svc = T.boot(w)
    local tav = w.chars[T.TAV]
    tav.spells.Target_FFTJ_Rush = true -- e.g. given by another mod or an item
    svc:AddManualJP(T.TAV, 300, "Squire")
    T.truthy(svc:Learn(T.TAV, "Rush"))
    T.falsy(svc.State:Get(T.TAV).Granted.Spells.Target_FFTJ_Rush, "not marked as ours")
    T.truthy(svc:SetPrimary(T.TAV, "Archer"))
    T.truthy(tav.spells.Target_FFTJ_Rush, "still there after the job change")
end

function S.combat_blocks_changes(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.startCombat(w, "c1", { T.TAV })
    local ok, msg = svc:SetPrimary(T.TAV, "Knight")
    T.falsy(ok)
    T.contains(msg, "during combat")
    ok, msg = svc:Learn(T.TAV, "Focus")
    T.falsy(ok)
    T.contains(msg, "during combat")
    T.endCombat(w, "c1", { T.TAV })
    T.truthy(svc:SetPrimary(T.TAV, "Knight"))
end

function S.long_rest_repairs_lost_grants(w, T)
    local svc = T.boot(w)
    w.chars[T.TAV].spells.Shout_FFTJ_JobBoard = nil -- e.g. lost in a respec
    w.fire("LongRestFinished")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JobBoard)
end

function S.uninstall_removes_grants_and_pauses(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 300, "Squire")
    svc:Learn(T.TAV, "Focus")
    w.console("fft_uninstall")
    for _, g in ipairs({ T.TAV, T.SHART, T.ASTA }) do
        T.eq(T.keys(w.chars[g].spells), "", "no spells left on " .. g)
        T.eq(T.keys(w.chars[g].passives), "", "no passives left on " .. g)
    end
    T.startCombat(w, "c1", { T.TAV })
    local before = sum(svc, T, T.TAV, "Squire")
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(sum(svc, T, T.TAV, "Squire"), before, "no JP while paused")
    T.endCombat(w, "c1", { T.TAV })
    w.console("fft_enable")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_Focus)
end

function S.reset_character(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 300, "Squire")
    svc:Learn(T.TAV, "Focus")
    local ok = svc:ResetChar(T.TAV)
    T.truthy(ok)
    T.eq(sum(svc, T, T.TAV, "Squire"), 0)
    T.falsy(w.chars[T.TAV].spells.Shout_FFTJ_Focus)
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JobBoard)
end

function S.companion_joining_later_is_tracked(w, T)
    local svc = T.boot(w)
    local KARLACH = "55555555-5555-4555-8555-555555555555"
    w.newChar(KARLACH, { name = "Karlach", level = 3, xp = 900, class = "Barbarian" })
    w.fire("CharacterJoinedParty", "S_Player_Karlach_" .. KARLACH)
    T.truthy(svc.State:Get(KARLACH))
    T.truthy(w.chars[KARLACH].spells.Shout_FFTJ_JobBoard)
    T.eq(svc.State:Get(KARLACH).Primary, "Squire")
end

function S.npcs_are_checked_once_and_recruits_still_join(w, T)
    local svc = T.boot(w)
    local GOBLIN = "66666666-6666-4666-8666-666666666666"
    w.newChar(GOBLIN, { name = "Goblin", level = 2, player = false, party = false })
    w.osiCalls = {}
    local checks = 0
    local original = Osi.IsSummon
    Osi.IsSummon = function(g)
        checks = checks + 1
        return original(g)
    end
    w.chars[GOBLIN].inCombat = true
    T.cast(w, GOBLIN, "Target_MainHandAttack")
    T.cast(w, GOBLIN, "Target_MainHandAttack")
    w.fire("EnteredCombat", "Goblin_" .. GOBLIN, "c1")
    T.eq(checks, 1, "an NPC is checked once")
    T.falsy(svc.State:Get(GOBLIN))
    w.chars[GOBLIN].player = true
    w.chars[GOBLIN].party = true
    w.fire("CharacterJoinedParty", "Goblin_" .. GOBLIN)
    T.truthy(svc.State:Get(GOBLIN), "recruited NPCs are tracked")
    Osi.IsSummon = original
end

function S.reset_completed_reloads_saved_state(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 120, "Squire")
    w.tick()
    for _, h in pairs(w.events.ResetCompleted.handlers) do
        h({})
    end
    T.eq(sum(svc, T, T.TAV, "Squire"), 120)
    T.truthy(#w.timers >= 1)
end

function S.errors_in_handlers_do_not_escape(w, T)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV })
    local original = Osi.GetLevel
    Osi.GetLevel = function()
        error("boom")
    end
    T.cast(w, T.TAV, "Target_MainHandAttack") -- Game:CharLevel falls back to 1
    Osi.GetLevel = original
    T.eq(sum(svc, T, T.TAV, "Squire"), 13)
    T.contains(w.prints, "GetLevel failed")
    svc.OnCastedSpell = function()
        error("handler bug")
    end
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.contains(w.prints, "handler bug")
end

function S.jp_training_spell_trains_the_party(w, T)
    local svc = T.boot(w)
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JPTraining, "testing tool granted by default")
    local before = #w.notifications
    T.cast(w, T.TAV, "Shout_FFTJ_JPTraining")
    T.eq(sum(svc, T, T.TAV, "Squire"), 1000)
    T.eq(sum(svc, T, T.TAV, "Chemist"), 1000)
    T.eq(sum(svc, T, T.SHART, "Chemist"), 1000, "the whole party, not only the caster")
    T.eq(sum(svc, T, T.TAV, "Knight"), 0, "jobs locked before the cast get nothing yet")
    T.truthy(svc.State:Get(T.TAV).Unlocked.Knight, "Squire Lv4 unlocks Knight")
    T.eq(#w.notifications, before + 1, "one summary instead of a notice per level and unlock")
    T.contains(w.notifications[#w.notifications],
        "+1000 JP in every unlocked job for 3 party members, 12 new jobs unlocked")
    T.cast(w, T.SHART, "Shout_FFTJ_JPTraining")
    T.eq(sum(svc, T, T.TAV, "Knight"), 1000, "jobs unlocked by the last cast train on the next")
    T.eq(sum(svc, T, T.TAV, "Squire"), 2000)
    T.eq(svc.State:Get(T.TAV).Stats.JP.Test, 8000, "2 jobs, then 6")
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Shout_FFTJ_JPTraining")
    T.eq(sum(svc, T, T.TAV, "Squire"), 3000, "no action JP on top of the training")
end

function S.jp_training_is_not_shared(w, T)
    local svc = T.boot(w, { extra = SHARED })
    T.cast(w, T.TAV, "Shout_FFTJ_JPTraining")
    T.eq(sum(svc, T, T.TAV, "Knight"), 0, "training JP does not share into other jobs")
end

function S.testing_tools_can_be_turned_off(w, T)
    local svc = T.boot(w)
    w.console("fft_set", "Test.Tools", "false")
    T.falsy(w.chars[T.TAV].spells.Shout_FFTJ_JPTraining, "removed at once")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JobBoard)
    T.cast(w, T.TAV, "Shout_FFTJ_JPTraining") -- e.g. still on a hotbar
    T.eq(sum(svc, T, T.TAV, "Squire"), 0)
    w.console("fft_unset", "Test.Tools")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JPTraining, "back with the default")
end

function S.mime_echoes_the_last_ally_job_ability(w, T)
    local svc = T.boot(w)
    svc:UnlockAll(T.SHART)
    for _, c in ipairs({ svc.State:Get(T.SHART), svc.State:Get(T.TAV) }) do
        for _, job in ipairs({ "Squire", "Chemist", "Summoner", "Orator", "Geomancer", "Dragoon" }) do
            c.Jobs[job] = { Earned = 99999, Unspent = 0, Learned = {} } -- the Mime's job level requirements
        end
    end
    T.truthy(svc:SetPrimary(T.SHART, "Mime"))
    local mime = w.chars[T.SHART].spells
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    w.fire("TurnStarted", "S_Player_" .. T.SHART)
    T.falsy(mime.Shout_FFTJ_Ashura_Echo, "nothing to echo yet")
    w.fire("TurnEnded", "S_Player_" .. T.SHART)
    T.cast(w, T.TAV, "Shout_FFTJ_Ashura")
    w.fire("TurnStarted", "S_Player_" .. T.SHART)
    T.truthy(mime.Shout_FFTJ_Ashura_Echo, "an ally's job ability: its echo twin for this turn")
    T.cast(w, T.SHART, "Shout_FFTJ_Ashura_Echo")
    T.falsy(mime.Shout_FFTJ_Ashura_Echo, "one echo per turn")
    w.fire("TurnEnded", "S_Player_" .. T.SHART)
    w.fire("TurnStarted", "S_Player_" .. T.SHART)
    T.falsy(mime.Shout_FFTJ_Ashura_Echo, "only what allies used since the Mime's last turn")
    w.fire("TurnEnded", "S_Player_" .. T.SHART)
    T.cast(w, T.TAV, "Target_MainHandAttack")
    w.fire("TurnStarted", "S_Player_" .. T.SHART)
    T.eq(svc.State:Get(T.SHART).Echo, nil, "a plain attack is not a job ability")
    w.fire("TurnEnded", "S_Player_" .. T.SHART)
    T.cast(w, T.TAV, "Zone_FFTJ_KikuIchimonji")
    w.fire("TurnStarted", "S_Player_" .. T.SHART)
    T.truthy(mime.Zone_FFTJ_KikuIchimonji_Echo)
    T.endCombat(w, "c1", { T.TAV, T.SHART })
    T.falsy(mime.Zone_FFTJ_KikuIchimonji_Echo, "echoes end with the fight")
    svc:UnlockAll(T.TAV)
    T.truthy(svc:SetPrimary(T.TAV, "Mime"))
    T.startCombat(w, "c2", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Shout_FFTJ_Ashura")
    w.fire("TurnStarted", "S_Player_" .. T.TAV)
    T.falsy(w.chars[T.TAV].spells.Shout_FFTJ_Ashura_Echo, "a Mime doesn't echo itself")
    T.endCombat(w, "c2", { T.TAV, T.SHART })
end

return S
