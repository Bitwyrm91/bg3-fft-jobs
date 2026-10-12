-- SE console commands (!fft_*) as the player types them.
local S = {}

local function out(lines)
    return table.concat(lines, "\n")
end

function S.help_lists_every_command(w, T)
    T.boot(w)
    local text = out(w.console("fft_help"))
    for name in pairs(w.commands) do
        T.contains(text, "!" .. name)
    end
    T.eq(#w.console("fft_help"), 1 + 25, "25 commands")
end

function S.party_and_status(w, T)
    T.boot(w)
    local party = out(w.console("fft_party"))
    T.contains(party, "Tav: Squire Lv1")
    T.contains(party, "Shadowheart: Chemist Lv1")
    local status = out(w.console("fft_status", "shadow"))
    T.contains(status, "Shadowheart: Chemist")
    T.contains(status, "White Mage")
    T.contains(status, "locked (needs Chemist Lv2)")
    T.contains(out(w.console("fft_status", "nobody")), "No party member called nobody")
end

function S.job_learn_equip_by_name(w, T)
    local svc = T.boot(w)
    T.contains(out(w.console("fft_addjp", "700")), "Tav +700 JP in Squire")
    T.contains(out(w.console("fft_learn", "Focus")), "Tav learned Focus")
    T.contains(out(w.console("fft_learn", "JPBoost")), "It works without a slot while Squire is the job")
    T.contains(out(w.console("fft_equip", "jpboost")), "support slot = JP Boost")
    T.contains(out(w.console("fft_job", "knight")), "Tav is now a Knight")
    T.contains(out(w.console("fft_secondary", "squire")), "secondary skill set Fundaments")
    T.contains(out(w.console("fft_secondary", "none")), "secondary skill set cleared")
    T.contains(out(w.console("fft_unequip", "support")), "support slot cleared")
    T.contains(out(w.console("fft_job", "monk")), "Unknown job monk")
    T.contains(out(w.console("fft_learn", "Meteor")), "Unknown ability Meteor")
    T.contains(out(w.console("fft_learn", "Cure")), "Not done: White Mage is still locked")
    T.eq(svc.State:Get(T.TAV).Primary, "Knight")
end

function S.addjp_parses_job_and_who(w, T)
    local svc = T.boot(w)
    w.console("fft_addjp", "120", "shadowheart")
    T.eq(svc.State:Get(T.SHART).Jobs.Chemist.Earned, 120, "no job given: the primary job")
    w.console("fft_addjp", "80", "blackmage", "shadowheart")
    T.eq(svc.State:Get(T.SHART).Jobs.BlackMage.Earned, 80, "JP can be banked in a locked job")
    T.contains(out(w.console("fft_addjp", "lots")), "Usage")
end

function S.tuning_commands_change_jp(w, T, Mocks)
    local svc = T.boot(w)
    T.contains(out(w.console("fft_mult", "2")), "JP.GlobalMultiplier = 2")
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 26, "13 * 2")
    T.contains(out(w.console("fft_set", "JP.Action.EnhancedBonus", "0")), "JP.Action.EnhancedBonus = 0")
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 46, "+ 10 * 2")
    local saved = Mocks.Json.decode(w.files["FFTJobs/config.json"])
    T.eq(saved.Overrides.JP.GlobalMultiplier, 2, "console changes are saved")
    T.contains(out(w.console("fft_unset", "JP.GlobalMultiplier")), "back to the preset value")
    T.contains(out(w.console("fft_preset", "grindy")), "preset Grindy")
    T.contains(out(w.console("fft_preset", "easy")), "Unknown preset easy")
    T.contains(out(w.console("fft_config")), "preset Grindy")
    T.contains(out(w.console("fft_set")), "Usage")
    T.contains(out(w.console("fft_set", "JP.Bogus", "1")), "Unknown setting")
end

function S.reload_reads_the_edited_file(w, T, Mocks)
    local svc = T.boot(w)
    local doc = Mocks.Json.decode(w.files["FFTJobs/config.json"])
    doc.Overrides.JP.LongRest = 100
    w.files["FFTJobs/config.json"] = Mocks.Json.encode(doc)
    T.contains(out(w.console("fft_reload")), "loaded FFTJobs/config.json")
    w.fire("LongRestFinished")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 100)
end

function S.reload_with_lower_thresholds_unlocks_jobs(w, T, Mocks)
    local svc = T.boot(w)
    w.console("fft_addjp", "150")
    T.falsy(svc.State:Get(T.TAV).Unlocked.Knight)
    local doc = Mocks.Json.decode(w.files["FFTJobs/config.json"])
    doc.Overrides.JobLevels.Thresholds = { 100, 400, 700, 1100, 1600, 2200, 3000 }
    w.files["FFTJobs/config.json"] = Mocks.Json.encode(doc)
    w.console("fft_reload")
    T.truthy(svc.State:Get(T.TAV).Unlocked.Knight)
end

function S.unlockall_reset_regrant(w, T)
    local svc = T.boot(w)
    T.contains(out(w.console("fft_unlockall", "astarion")), "every implemented job unlocked (for the whole party)")
    T.truthy(svc.State:Get(T.ASTA).Unlocked.BlackMage)
    T.truthy(svc.State:Get(T.TAV).Unlocked.BlackMage, "party-wide unlocks")
    w.console("fft_addjp", "300", "squire", "astarion")
    T.contains(out(w.console("fft_reset", "astarion")), "reset to a fresh Squire")
    T.eq(svc.State:Get(T.ASTA).Jobs.Squire.Earned, 0, "JP is gone")
    T.truthy(svc.State:Get(T.ASTA).Unlocked.BlackMage, "the party's unlocks stay")
    w.chars[T.TAV].spells.Shout_FFTJ_JobBoard = nil
    T.contains(out(w.console("fft_regrant", "all")), "every party member")
    T.truthy(w.chars[T.TAV].spells.Shout_FFTJ_JobBoard)
end

function S.reset_without_party_wide_unlocks(w, T)
    local svc = T.boot(w, { extra = { Rules = { PartyWideUnlocks = false } } })
    T.contains(out(w.console("fft_unlockall", "astarion")), "every implemented job unlocked")
    T.falsy(svc.State:Get(T.TAV).Unlocked.BlackMage)
    w.console("fft_reset", "astarion")
    T.falsy(svc.State:Get(T.ASTA).Unlocked.BlackMage)
end

function S.badge_command(w, T)
    T.boot(w)
    T.contains(out(w.console("fft_badge", "list")), "No badges yet")
    T.contains(out(w.console("fft_badge", "crown")), "Unknown badge crown")
end

function S.grants_command_reports_game_state(w, T)
    T.boot(w)
    w.console("fft_addjp", "300")
    w.console("fft_learn", "Focus")
    local text = out(w.console("fft_grants"))
    T.contains(text, "Tav: job Squire, secondary -")
    T.contains(text, "Spells Shout_FFTJ_Focus: in game")
    T.contains(text, "Passives FFTJ_Job_Squire: in game")
    w.chars[T.TAV].spells.Shout_FFTJ_Focus = nil -- e.g. dropped by the game
    T.contains(out(w.console("fft_grants")), "Spells Shout_FFTJ_Focus: MISSING in game")
end

function S.learning_says_how_to_use_it(w, T)
    T.boot(w)
    w.console("fft_addjp", "300", "squire", "shadowheart")
    T.contains(out(w.console("fft_learn", "Focus", "shadowheart")), "To use it, make Squire Shadowheart's job or secondary")
    T.contains(out(w.console("fft_secondary", "squire", "shadowheart")), "(Squire), 1 learned action usable")
    w.console("fft_addjp", "300")
    T.contains(out(w.console("fft_learn", "Focus")), "Added to Tav's spells")
    T.contains(out(w.console("fft_job", "chemist")), "Tav is now a Chemist")
    T.contains(out(w.console("fft_job", "squire")), "Tav is now a Squire, 1 learned action usable")
end

function S.train_command(w, T)
    local svc = T.boot(w)
    T.contains(out(w.console("fft_train")), "+1000 JP in every unlocked job for 3 party members")
    T.eq(svc.State:Get(T.ASTA).Jobs.Squire.Earned, 1000)
    w.console("fft_train", "250")
    T.eq(svc.State:Get(T.ASTA).Jobs.Squire.Earned, 1250)
    T.eq(svc.State:Get(T.ASTA).Jobs.Knight.Earned, 250, "Knight was unlocked by the first call")
    T.contains(out(w.console("fft_train", "lots")), "Usage")
    T.contains(out(w.console("fft_train", "0")), "Not done: Amount must be a positive number")
    T.contains(out(w.console("fft_set", "Test.JPPerCast", "50")), "Test.JPPerCast = 50")
    w.console("fft_train")
    T.eq(svc.State:Get(T.ASTA).Jobs.Squire.Earned, 1300)
end

function S.telemetry_summary(w, T)
    T.boot(w)
    T.startCombat(w, "c1", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.endCombat(w, "c1", { T.TAV, T.SHART })
    local text = out(w.console("fft_telemetry"))
    T.contains(text, "1 fights")
    T.contains(text, "Tav: 1 fights, 1 actions")
    T.contains(text, "Astarion")
end

function S.board_command_opens_window(w, T)
    T.boot(w)
    T.contains(out(w.console("fft_board", "shadowheart")), "Job Board opened")
    T.eq(#w.windows, 1)
    T.truthy(w.windows[1].Open)
end

return S
