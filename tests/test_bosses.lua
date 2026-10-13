-- Boss badges (Server/Bosses.lua, docs/SPECIAL_JOBS.md): defeated bosses, bosses who join, spared bosses at the next
-- act, the defeated record of saves made before the mod was installed.
local S = {}

local GUT = "b983c336-9a14-4e9b-adb9-4689e7e0afa9"
local MINTHARA = "25721313-0c15-4935-8176-9f134385451b"
local NERE = "06bf05c5-216b-4eaf-91f5-8f1dd3d57f30"
local ETHEL = "c457d064-83fb-4ec6-b74d-1f30dfafd12d"
local FLIND = "34464430-fed8-4f50-86d5-bd35846920a0"
local YURGIR = "1dc8091d-2af6-4d33-9268-998ef266d19c"
local KETHERIC_AVATAR = "9061c1d3-5965-4251-9c07-bcebe53d0660"
local GORTASH = "b878a854-f790-4999-95c4-3f20f00f65ac"

local function boss(w, guid, name)
    w.newChar(guid, { name = name, level = 5, player = false, party = false, boss = true })
    return "S_Boss_" .. guid
end

local function badges(svc)
    return svc.State:Meta().Badges
end

local function bootIn(w, T, level, extra)
    return T.boot(w, { level = level, extra = extra })
end

function S.a_boss_who_dies_drops_its_badge(w, T)
    local svc = T.boot(w)
    local gut = boss(w, GUT, "True Soul Gut")
    w.chars[GUT].dead = true
    w.fire("Died", gut)
    T.truthy(badges(svc).Cleric)
    T.contains(w.notifications, "True Soul Gut is defeated. The party found the Cleric Badge!")
    T.truthy(svc.State:Get(T.SHART).Badges.Cleric, "the badge serves the whole party")
    local before = #w.notifications
    w.fire("Died", gut)
    T.eq(#w.notifications, before, "only once")
end

function S.the_story_defeated_record_counts_after_a_fight(w, T)
    local svc = T.boot(w)
    boss(w, NERE, "True Soul Nere")
    T.startCombat(w, "c1", { T.TAV })
    w.defeated[NERE] = true -- knocked out, surrendered, ...: the story's DB_Defeated
    T.endCombat(w, "c1", { T.TAV })
    T.truthy(badges(svc).DivineKnight)
    T.contains(w.notifications, "True Soul Nere is defeated. The party found the Divine Knight Badge!")
end

function S.bosses_beaten_before_the_mod_was_installed_count_on_load(w, T)
    w.defeated[GUT] = true
    w.defeated[KETHERIC_AVATAR] = true -- any of a boss's characters
    local svc = T.boot(w)
    T.truthy(badges(svc).Cleric)
    T.truthy(badges(svc).HolyKnight)
    T.falsy(badges(svc).Netherseer)
end

function S.a_boss_who_joins_hands_over_the_badge(w, T)
    local svc = T.boot(w)
    w.newChar(MINTHARA, { name = "Minthara", level = 5, class = "Paladin" })
    w.fire("CharacterJoinedParty", "S_GOB_DrowCommander_" .. MINTHARA)
    T.truthy(badges(svc).FellKnight)
    T.contains(w.notifications, "Nightwarden Minthara joined the party. The party found the Fell Knight Badge!")
    T.truthy(svc.State:Get(MINTHARA), "and she is tracked like any companion")
    T.truthy(svc.State:Get(MINTHARA).Badges.FellKnight)
end

function S.a_spared_boss_the_party_fought_gives_its_badge_in_the_next_act(w, T)
    local svc = T.boot(w)
    local ethel = boss(w, ETHEL, "Auntie Ethel")
    boss(w, FLIND, "Flind")
    w.fire("EnteredCombat", ethel, "c1")
    T.falsy(badges(svc).Astrologer, "not while she may still be beaten")
    T.truthy(svc.State:Meta().BossMet.Astrologer)
    w.fire("LevelGameplayStarted", "SCL_Main_A", 0)
    T.truthy(badges(svc).Astrologer)
    T.contains(w.notifications, "Auntie Ethel was spared. The party found the Astrologer Badge!")
    T.falsy(badges(svc).GameHunter, "a boss the party never met gives nothing")
    T.eq(svc.State:Meta().Act, 2)
end

function S.meeting_in_a_dialog_needs_a_party_member(w, T)
    local svc = bootIn(w, T, "SCL_Main_A")
    local yurgir = boss(w, YURGIR, "Yurgir")
    local gut = boss(w, GUT, "True Soul Gut")
    w.fire("DialogActorJoined", "AD_Gut", 7, gut, 0)
    w.fire("DialogEnded", "AD_Gut", 7)
    T.falsy((svc.State:Meta().BossMet or {}).Cleric, "a boss talking on its own is no meeting")
    w.fire("DialogActorJoined", "Yurgir_Talk", 8, yurgir, 0)
    w.fire("DialogActorJoined", "Yurgir_Talk", 8, "S_Player_" .. T.TAV, 1)
    T.truthy(svc.State:Meta().BossMet.Soldier)
    w.fire("DialogEnded", "Yurgir_Talk", 8)
    w.fire("LevelGameplayStarted", "BGO_Main_A", 0)
    T.truthy(badges(svc).Soldier, "Yurgir freed from his contract: spared")
end

function S.later_bosses_wait_for_their_own_act(w, T)
    local svc = bootIn(w, T, "SCL_Main_A")
    local gortash = boss(w, GORTASH, "Gortash")
    w.fire("DialogActorJoined", "Moonrise", 9, gortash, 0)
    w.fire("DialogActorJoined", "Moonrise", 9, "S_Player_" .. T.TAV, 1)
    w.fire("LevelGameplayStarted", "BGO_Main_A", 0)
    T.falsy(badges(svc).Machinist, "Gortash is an Act 3 boss: met in Act 2, he is not spared by reaching Act 3")
end

function S.zhalk_is_left_behind_when_the_party_reaches_the_shore(w, T)
    local svc = bootIn(w, T, "TUT_Avernus_C")
    T.falsy(badges(svc).SkyPirate)
    T.eq(svc.State:Meta().Act, 0)
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.truthy(badges(svc).SkyPirate)
    T.contains(w.notifications, "Commander Zhalk was left behind on the nautiloid. The party found the Sky Pirate Badge!")
end

function S.a_save_first_seen_mid_game_only_settles_the_act(w, T)
    local svc = bootIn(w, T, "SCL_Main_A")
    T.eq(svc.State:Meta().Act, 2)
    T.truthy(badges(svc).SkyPirate, "the prologue boss counts met or not")
    T.falsy(badges(svc).Astrologer, "nobody saw the party meet the Act 1 bosses")
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.eq(svc.State:Meta().Act, 2, "the act never goes back")
end

function S.badges_from_bosses_can_be_turned_off(w, T)
    local svc = bootIn(w, T, "TUT_Avernus_C", { Badges = { FromBosses = false } })
    local gut = boss(w, GUT, "True Soul Gut")
    w.fire("Died", gut)
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.eq(next(badges(svc)), nil, "no boss badges at all")
    T.truthy(svc:AddBadge("Cleric"), "!fft_badge still works")
end

function S.spared_bosses_can_be_turned_off(w, T)
    local svc = bootIn(w, T, "TUT_Avernus_C", { Badges = { SparedBosses = false } })
    w.defeated[GUT] = true
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.falsy(badges(svc).SkyPirate, "Zhalk is not defeated")
    T.truthy(badges(svc).Cleric, "defeated bosses still count")
end

function S.badge_list_shows_the_bosses(w, T)
    local svc = T.boot(w)
    svc:AddBadge("Cleric")
    local out = table.concat(w.console("fft_badge", "list"), "\n")
    T.contains(out, "Cleric: Cleric Badge, from True Soul Gut (Act 1), found")
    T.contains(out, "SkyPirate: Sky Pirate Badge, from Commander Zhalk (prologue), found")
    T.contains(out, "SwordSaint: Sword Saint Badge, from Sarevok Anchev (Act 3), not yet")
end

function S.requirements_name_the_boss(w, T)
    local svc = T.boot(w)
    local Rules = Ext.Require("Server/Rules.lua")
    T.eq(Rules.RequirementText(svc.Data, "Cleric"), "Cleric Badge (True Soul Gut), White Mage Lv4, Chemist Lv4")
end

function S.special_jobs_have_their_own_section_on_the_board(w, T, Mocks)
    local svc = T.boot(w)
    svc.Data.Jobs.SwordSaint.Implemented = false -- as long as a special job is not built (the copy is this test's)
    svc:AddBadge("SwordSaint")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local found = Mocks.FindWidgets(win, function(x)
        return x.Kind == "SeparatorText" and x.Label == "Special jobs: each needs a boss's badge"
    end)
    T.eq(#found, 1)
    local tile
    for _, b in ipairs(Mocks.FindWidgets(win, function(x)
        return x.Kind == "Button" and x.Label == "Sword Saint (soon)##tileSwordSaint"
    end)) do
        tile = b
    end
    T.truthy(tile, "the Sword Saint tile")
    tile.OnClick(tile)
    local lines = {}
    for _, x in ipairs(Mocks.FindWidgets(win, function(x)
        return x.Kind == "Text"
    end)) do
        lines[#lines + 1] = x.Label
    end
    local text = table.concat(lines, "\n")
    T.contains(text, "Unlock: Sword Saint Badge (Sarevok Anchev), Knight Lv8, Samurai Lv8.")
    T.contains(text, "You still need: Knight Lv8 (has Lv1), Samurai Lv8 (has Lv1).", "the badge is found")
end

-- Special jobs, built one by one: each needs its boss's badge plus job levels, then works like any job.
function S.cleric_needs_the_badge_and_levels(w, T)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 1100, "WhiteMage")
    svc:AddManualJP(T.TAV, 1100, "Chemist")
    T.falsy(svc.State:Get(T.TAV).Unlocked.Cleric, "White Mage Lv4 and Chemist Lv4 are not enough")
    w.newChar(GUT, { name = "True Soul Gut", level = 4, player = false, party = false })
    w.fire("Died", "S_GOB_GoblinPriest_" .. GUT)
    T.truthy(svc.State:Get(T.TAV).Unlocked.Cleric)
    T.contains(w.notifications, "True Soul Gut is defeated. The party found the Cleric Badge. Tav unlocked the Cleric job!")
    T.truthy(svc:SetPrimary(T.TAV, "Cleric"))
    local tav = w.chars[T.TAV]
    T.truthy(tav.passives.FFTJ_Job_Cleric and tav.passives.FFTJ_HolyMagicks, "job marker and Holy Magicks")
    T.truthy(svc:Learn(T.TAV, "Dispelna"), "Alma's own magick costs 0 JP")
    T.truthy(tav.spells.Target_FFTJ_Dispelna)
    svc:AddManualJP(T.TAV, 50, "Cleric")
    T.truthy(svc:Learn(T.TAV, "ClericCure"))
    T.truthy(tav.spells.Target_FFTJ_Cure, "the White Magicks' spell, learned as the Cleric's own")
end

-- Every built special job: its badge and job levels unlock it; as the job, every ability can be learned and is granted.
function S.every_built_special_job_unlocks_learns_and_grants(w, T)
    local svc = T.boot(w)
    local data = svc.Data
    local built = 0
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Group == "Special" and job.Implemented then
            built = built + 1
            local guid = "77777777-7777-4777-8777-" .. string.format("%012d", built)
            w.newChar(guid, { name = "Tester" .. built, level = 6, class = "Fighter" })
            w.fire("CharacterJoinedParty", "S_Player_" .. guid)
            for _, req in ipairs(job.Unlock) do
                if req.Job then
                    svc:AddManualJP(guid, 3000, req.Job)
                end
            end
            local badge = job.Unlock[1].Badge
            if not svc.State:Meta().Badges[badge] then -- (Zhalk's comes with Act 1, where the test boots)
                T.falsy(svc.State:Get(guid).Unlocked[jobId], jobId .. " needs its badge")
            end
            T.truthy(svc:AddBadge(badge))
            T.truthy(svc.State:Get(guid).Unlocked[jobId], jobId .. ": badge + levels unlock it")
            T.truthy(svc:SetPrimary(guid, jobId))
            svc:AddManualJP(guid, 20000, jobId)
            for _, aid in ipairs(data.AbilitiesByJob[jobId]) do
                local ok, msg = svc:Learn(guid, aid)
                T.truthy(ok, jobId .. " " .. aid .. ": " .. tostring(msg))
                local ab = data.Abilities[aid]
                if ab.Type == "Action" then
                    for _, s in ipairs(ab.Grants.Spells or {}) do
                        T.truthy(w.chars[guid].spells[s], jobId .. " grants " .. s)
                    end
                end
            end
            for _, p in ipairs(job.Innate.Passives or {}) do
                T.truthy(w.chars[guid].passives[p], jobId .. " innate " .. p)
            end
            T.truthy(w.chars[guid].passives[job.Mastery.Grants.Passives[1]], jobId .. " mastered: perk")
        end
    end
    T.truthy(built >= 1, "at least one special job is built")
end

return S
