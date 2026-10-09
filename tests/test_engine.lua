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

function S.level_up_and_unlock_notifications(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 200, "Squire")
    T.contains(w.notifications, "Tav: Squire is now job level 2")
    T.contains(w.notifications, "Tav unlocked the Knight job!")
    T.contains(w.notifications, "Tav unlocked the Archer job!")
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

function S.support_and_movement_slots_grant_passives(w, T)
    local svc = T.boot(w)
    local tav = w.chars[T.TAV]
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.truthy(svc:Learn(T.TAV, "Movement1"))
    T.falsy(tav.passives.FFTJ_Movement1, "learning alone does not equip")
    T.truthy(svc:Equip(T.TAV, "Movement1"))
    T.truthy(tav.passives.FFTJ_Movement1)
    T.truthy(svc:Learn(T.TAV, "EvasiveStance"))
    T.truthy(svc:Equip(T.TAV, "EvasiveStance"))
    T.truthy(tav.spells.Shout_FFTJ_Defend, "a support can grant an action")
    T.truthy(svc:Unequip(T.TAV, "movement"))
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

return S
