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
    svc:AddBadge("Cleric")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local found = Mocks.FindWidgets(win, function(x)
        return x.Kind == "SeparatorText" and x.Label == "Special jobs: each needs a boss's badge"
    end)
    T.eq(#found, 1)
    local tile
    for _, b in ipairs(Mocks.FindWidgets(win, function(x)
        return x.Kind == "Button" and x.Label == "Cleric (soon)##tileCleric"
    end)) do
        tile = b
    end
    T.truthy(tile, "the Cleric tile")
    tile.OnClick(tile)
    local lines = {}
    for _, x in ipairs(Mocks.FindWidgets(win, function(x)
        return x.Kind == "Text"
    end)) do
        lines[#lines + 1] = x.Label
    end
    local text = table.concat(lines, "\n")
    T.contains(text, "Unlock: Cleric Badge (True Soul Gut), White Mage Lv4, Chemist Lv4.")
    T.contains(text, "You still need: White Mage Lv4 (has Lv1), Chemist Lv4 (has Lv1).", "the badge is found")
end

return S
