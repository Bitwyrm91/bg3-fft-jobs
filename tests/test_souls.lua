-- The Soul Collector (Server/Souls.lua, data/souls.json): soul types from creature keys, Soul Brand + death =
-- devoured, the party's Soul Codex, forms granted by tier, the Soul Known marker, the Soul Codex unlock.
local S = {}

local GOB = "61616161-6161-4161-8161-616161616161"
local GOB2 = "62626262-6262-4262-8262-626262626262"

local function goblin(w, guid)
    w.newChar(guid, { name = "Goblin", template = "Goblin_Melee_Strong_35e843cf-bc73-4754-aaee-fd8272d99ea6",
        stats = "Goblin_Melee_Strong", player = false, party = false, level = 2 })
    return "S_Goblin_" .. guid
end

local function souls(svc)
    return svc.State:Meta().Souls or {}
end

function S.soul_types_come_from_template_stats_and_name(w, T)
    local svc = T.boot(w)
    local Souls = Ext.Require("Server/Souls.lua")
    local d = svc.Data
    T.eq(Souls.TypeOf(d, "goblin_melee_strong_35e8 goblin_melee_strong goblin"), "Goblin")
    T.eq(Souls.TypeOf(d, "hobgoblin_warrior"), "Bugbear", "a hobgoblin is not a goblin")
    T.eq(Souls.TypeOf(d, "imp_weak_feb1d610 imp"), "Imp")
    T.eq(Souls.TypeOf(d, "s_glo_orinsimpersonation_smith"), nil, "'imp' inside a word is no imp")
    T.eq(Souls.TypeOf(d, "mind flayer"), "MindFlayer")
    T.eq(Souls.TypeOf(d, "kuo-toa"), "KuoToa")
    T.eq(Souls.TypeOf(d, "worg_lesser"), "Wolf")
    T.eq(Souls.TypeOf(d, "werewolf"), nil, "werewolves are a later soul")
    T.eq(Souls.TypeOf(d, "duergar_warrior"), nil, "ordinary humanoids give no soul")
end

function S.the_soul_codex_opens_the_job_for_the_party(w, T)
    local svc = T.boot(w, { level = "TUT_Avernus_C" })
    local Rules = Ext.Require("Server/Rules.lua")
    T.falsy(svc.State:Get(T.TAV).Unlocked.SoulCollector)
    local ok, msg = svc:AddBadge("SoulCodex")
    T.truthy(ok, msg)
    T.truthy(svc.State:Get(T.TAV).Unlocked.SoulCollector)
    T.truthy(svc.State:Get(T.SHART).Unlocked.SoulCollector, "no job levels needed")
    T.eq(Rules.RequirementText(svc.Data, "SoulCollector"), "Soul Codex")
    local before = Rules.BadgeCount(svc.State:Get(T.TAV), svc.Data)
    T.eq(before, Rules.BadgeCount(svc.State:Get(T.TAV), svc.Data), "the Soul Codex is no boss badge (Gallant Knight)")
end

function S.a_branded_creature_that_dies_gives_its_soul(w, T)
    local svc = T.boot(w)
    local gob = goblin(w, GOB)
    w.fire("StatusApplied", gob, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0)
    w.chars[GOB].dead = true
    w.fire("Died", gob)
    T.eq(souls(svc).Goblin, 1)
    T.contains(w.notifications, "Tav devoured a Goblin soul (1 in the Soul Codex). New forms: Goblin and Goblin (FFT).")
    T.eq(svc.State:Get(T.SHART).Souls.Goblin, 1, "the Soul Codex is the party's")
end

function S.no_brand_no_soul(w, T)
    local svc = T.boot(w)
    local gob = goblin(w, GOB)
    w.chars[GOB].dead = true
    w.fire("Died", gob)
    T.eq(souls(svc).Goblin, nil)
end

function S.a_brand_that_fell_off_alive_is_forgotten(w, T)
    local svc = T.boot(w)
    local gob = goblin(w, GOB)
    w.fire("StatusApplied", gob, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0)
    w.fire("StatusRemoved", gob, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0)
    w.runTimers()
    w.chars[GOB].dead = true
    w.fire("Died", gob)
    T.eq(souls(svc).Goblin, nil, "the brand had faded")
end

function S.a_brand_removed_by_death_still_counts(w, T)
    local svc = T.boot(w)
    local gob = goblin(w, GOB)
    w.fire("StatusApplied", gob, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0)
    w.chars[GOB].dead = true
    w.fire("StatusRemoved", gob, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0) -- statuses go before Died
    w.fire("Died", gob)
    w.runTimers()
    T.eq(souls(svc).Goblin, 1)
end

function S.forms_follow_the_souls_devoured(w, T)
    local svc = T.boot(w)
    local Souls = Ext.Require("Server/Souls.lua")
    local tav = w.chars[T.TAV]
    svc:AddBadge("SoulCodex")
    T.truthy(svc:SetPrimary(T.TAV, "SoulCollector"))
    T.falsy(svc:Learn(T.TAV, "SoulIncarnation"), "known from the start (StartLearned)")
    T.truthy(tav.spells.Shout_FFTJ_SoulIncarnation and tav.passives.FFTJ_SoulCharges)
    T.falsy(tav.spells.Shout_FFTJ_Soul_Goblin_B1, "no soul, no form")
    T.truthy(Souls.Add(svc, "Goblin", 1))
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B1 and tav.spells.Shout_FFTJ_Soul_Goblin_F1)
    T.truthy(Souls.Add(svc, "Goblin", 2))
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B3 and tav.spells.Shout_FFTJ_Soul_Goblin_F3, "3 souls: tier 3")
    T.falsy(tav.spells.Shout_FFTJ_Soul_Goblin_B1, "the lower tier goes")
    T.falsy(w.chars[T.SHART].spells.Shout_FFTJ_Soul_Goblin_B3, "Shadowheart has no Soul Incarnation")
    T.truthy(svc:SetPrimary(T.TAV, "Squire"))
    T.falsy(tav.spells.Shout_FFTJ_Soul_Goblin_B3, "only while the skill set is in use")
    T.truthy(svc:SetSecondary(T.TAV, "SoulCollector"))
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B3, "as the secondary skill set too")
end

function S.grants_wait_until_the_form_ends(w, T)
    local svc = T.boot(w)
    local Souls = Ext.Require("Server/Souls.lua")
    local tav = w.chars[T.TAV]
    svc:AddBadge("SoulCodex")
    T.truthy(svc:SetPrimary(T.TAV, "SoulCollector"))
    T.truthy(Souls.Add(svc, "Goblin", 1))
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B1)
    tav.statuses.WILDSHAPE_ACTIVE = true -- in a form (the polymorph swaps the spellbook)
    T.truthy(Souls.Add(svc, "Goblin", 2))
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B1, "nothing changes inside the form")
    T.falsy(tav.spells.Shout_FFTJ_Soul_Goblin_B3)
    tav.statuses.WILDSHAPE_ACTIVE = nil
    w.fire("StatusRemoved", "S_Player_" .. T.TAV, "WILDSHAPE_ACTIVE", "S_Player_" .. T.TAV, 0)
    w.runTimers()
    T.truthy(tav.spells.Shout_FFTJ_Soul_Goblin_B3, "applied once the form ends")
    T.falsy(tav.spells.Shout_FFTJ_Soul_Goblin_B1)
end

function S.known_soul_types_are_marked_in_a_fight(w, T)
    local svc = T.boot(w)
    local Souls = Ext.Require("Server/Souls.lua")
    local gob2 = goblin(w, GOB2)
    w.fire("EnteredCombat", gob2, "c1")
    T.falsy(w.chars[GOB2].statuses.FFTJ_SOUL_KNOWN)
    Souls.Add(svc, "Goblin", 1)
    w.fire("EnteredCombat", gob2, "c2")
    T.truthy(w.chars[GOB2].statuses.FFTJ_SOUL_KNOWN)
end

function S.a_boss_gives_its_own_soul_with_every_skill(w, T)
    local svc = T.boot(w)
    local gut = "b983c336-9a14-4e9b-adb9-4689e7e0afa9"
    w.newChar(gut, { name = "True Soul Gut", template = "GOB_Priestess_9e9000e1", player = false, party = false })
    w.fire("StatusApplied", "S_GOB_GoblinPriest_" .. gut, "FFTJ_SOUL_BRAND", "S_Player_" .. T.TAV, 0)
    w.chars[gut].dead = true
    w.fire("Died", "S_GOB_GoblinPriest_" .. gut)
    T.eq(souls(svc).Gut, 1, "Gut's own soul, not a goblin's")
    T.eq(souls(svc).Goblin, nil)
    T.contains(w.notifications, "New forms: True Soul Gut and Black Goblin (Gut).")
    local Souls = Ext.Require("Server/Souls.lua")
    T.eq(svc.Data.Souls.Gut.Forms.F.Skills[3].Souls, 1, "a boss soul gives every skill at once")
end

function S.a_form_is_free_outside_a_fight(w, T)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_Soul_Goblin_B1")
    T.truthy(w.chars[T.TAV].statuses.FFTJ_SOUL_REFUND, "the charge comes back")
    w.chars[T.SHART].inCombat = true
    T.cast(w, T.SHART, "Shout_FFTJ_Soul_Goblin_B1")
    T.falsy(w.chars[T.SHART].statuses.FFTJ_SOUL_REFUND, "in a fight it costs a charge")
    w.chars[T.TAV].statuses.FFTJ_SOUL_REFUND = nil
    T.cast(w, T.TAV, "Shout_FFTJ_Soul_SporeCloud")
    T.falsy(w.chars[T.TAV].statuses.FFTJ_SOUL_REFUND, "a form skill with the same prefix gives no charge back")
end

local US = "6ca92237-eb1e-4ed8-a1ee-18b3bef21558" -- S_TUT_Lab_TrappedDevourer, the story's "Us"

function S.talking_with_us_on_the_nautiloid_gives_the_soul_codex(w, T)
    local svc = T.boot(w, { level = "TUT_Avernus_C" })
    w.newChar(US, { name = "Us", player = false, party = false })
    w.fire("DialogActorJoined", "TUT_Lab_Us", 3, "S_TUT_Lab_TrappedDevourer_" .. US, 0)
    T.falsy(svc.State:Meta().Badges.SoulCodex, "Us alone")
    w.fire("DialogActorJoined", "TUT_Lab_Us", 3, "S_Player_" .. T.TAV, 1)
    T.truthy(svc.State:Meta().Badges.SoulCodex)
    T.contains(w.notifications, "Beside the brain in the jar lies a codex of stolen souls. The party found the Soul Codex.")
    T.truthy(svc.State:Get(T.TAV).Unlocked.SoulCollector)
    local learned = svc.State:Get(T.TAV).Jobs.SoulCollector.Learned
    T.truthy(learned.SoulBrand and learned.SoulIncarnation, "its two arts are known from the start, no Learn click")
    T.falsy(learned.FeralVigor, "the rest still costs JP")
end

function S.past_the_nautiloid_the_soul_codex_is_in_the_camp_chest(w, T)
    local svc = T.boot(w, { level = "TUT_Avernus_C" })
    T.falsy(svc.State:Meta().Badges.SoulCodex)
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    T.truthy(svc.State:Meta().Badges.SoulCodex)
    T.contains(w.notifications, "A codex of stolen souls turned up in your camp's traveller's chest.")
    local before = #w.notifications
    w.fire("LevelGameplayStarted", "SCL_Main_A", 0)
    T.eq(#w.notifications, before, "only once")
end

function S.soul_console_command(w, T)
    local svc = T.boot(w)
    local out = w.console("fft_soul", "add", "giant", "eagle", "3")
    T.contains(out, "Soul Codex: Giant Eagle x3")
    out = w.console("fft_soul", "list")
    T.contains(out, "Giant Eagle x3: Giant Eagle / Black Chocobo")
end

return S
