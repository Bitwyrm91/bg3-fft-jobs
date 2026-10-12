-- Job abilities whose effect runs in the server script (Effects.lua): Steal, Gravity, boss immunities, Gil Snapper,
-- Poach. The stats apply marker statuses; these tests fire the Osiris events the game would send.
local S = {}

local GOB = "66666666-6666-4666-8666-666666666666"
local SWORD = "77777777-7777-4777-8777-777777777777"

local function enemy(w, fields)
    local f = { name = "Goblin", level = 3, player = false, party = false, maxHp = 40, hp = 40 }
    for k, v in pairs(fields or {}) do
        f[k] = v
    end
    return w.newChar(GOB, f)
end

local function applied(w, target, status, source)
    w.fire("StatusApplied", "S_" .. target, status, source and ("S_Player_" .. source) or "", 0)
end

function S.steal_weapon_takes_the_item(w, T)
    T.boot(w)
    local gob = enemy(w)
    w.newItem(SWORD, { name = "Scimitar" })
    gob.equipment["Melee Main Weapon"] = SWORD
    applied(w, GOB, "FFTJ_STEAL_WEAPON", T.TAV)
    T.eq(gob.equipment["Melee Main Weapon"], nil, "unequipped")
    T.eq(w.chars[T.TAV].inventory[1], SWORD, "in the thief's inventory")
    T.contains(w.notifications, "Tav stole Scimitar from Goblin!")
end

function S.steal_weapon_falls_back_to_the_ranged_weapon(w, T)
    T.boot(w)
    local gob = enemy(w)
    w.newItem(SWORD, { name = "Shortbow" })
    gob.equipment["Ranged Main Weapon"] = SWORD
    applied(w, GOB, "FFTJ_STEAL_WEAPON", T.TAV)
    T.eq(w.chars[T.TAV].inventory[1], SWORD)
end

function S.steal_shield_takes_only_shields(w, T)
    T.boot(w)
    local gob = enemy(w)
    w.itemStats.WPN_Dagger = { ModifierList = "Weapon" }
    w.itemStats.ARM_Shield = { ModifierList = "Armor" }
    w.newItem(SWORD, { name = "Dagger", stats = "WPN_Dagger" })
    gob.equipment["Melee Offhand Weapon"] = SWORD
    applied(w, GOB, "FFTJ_STEAL_SHIELD", T.TAV)
    T.eq(#w.chars[T.TAV].inventory, 0, "an off-hand dagger is no shield")
    T.contains(w.notifications, "Goblin has no shield to steal.")
    w.newItem(SWORD, { name = "Wooden Shield", stats = "ARM_Shield" })
    applied(w, GOB, "FFTJ_STEAL_SHIELD", T.TAV)
    T.eq(w.chars[T.TAV].inventory[1], SWORD)
end

function S.story_items_cannot_be_stolen(w, T)
    T.boot(w)
    local gob = enemy(w)
    w.newItem(SWORD, { name = "Idol", story = true })
    gob.equipment.Amulet = SWORD
    applied(w, GOB, "FFTJ_STEAL_ACCESSORY", T.TAV)
    T.eq(gob.equipment.Amulet, SWORD, "still worn")
    T.contains(w.notifications, "Goblin's accessory can't be stolen.")
end

function S.steal_gil_and_exp_once_per_creature(w, T)
    local svc = T.boot(w)
    enemy(w)
    local tav = w.chars[T.TAV]
    local xp = tav.xp
    applied(w, GOB, "FFTJ_STEAL_GIL", T.TAV)
    T.eq(tav.gold, 30, "10 x level 3")
    T.contains(w.notifications, "Tav stole 30 gold from Goblin!")
    applied(w, GOB, "FFTJ_STEAL_GIL", T.TAV)
    T.eq(tav.gold, 30, "once per creature")
    T.contains(w.notifications, "Goblin has no gold left to steal.")
    applied(w, GOB, "FFTJ_STEAL_EXP", T.TAV)
    T.eq(tav.xp, xp + 30)
    T.truthy(svc.State:Meta().Robbed[GOB].EXP, "saved")
end

function S.gravity_takes_a_share_of_max_hp(w, T)
    T.boot(w)
    local gob = enemy(w)
    applied(w, GOB, "FFTJ_GRAVITY", T.TAV)
    T.eq(gob.hp, 30, "a quarter of 40")
    applied(w, GOB, "FFTJ_GRAVIGA", T.TAV)
    T.eq(gob.hp, 10, "half of 40")
end

function S.bosses_are_immune(w, T)
    T.boot(w)
    local gob = enemy(w, { name = "Dror Ragzlin", boss = true })
    applied(w, GOB, "FFTJ_GRAVITY", T.TAV)
    T.eq(gob.hp, 40, "no Gravity damage")
    T.contains(w.notifications, "Dror Ragzlin is immune.")
    for _, st in ipairs({ "FFTJ_DOOM", "FFTJ_STOP", "FFTJ_STONE" }) do
        gob.statuses[st] = true
        applied(w, GOB, st, T.TAV)
        T.falsy(gob.statuses[st], st .. " lifted off the boss")
    end
    local minion = "88888888-8888-4888-8888-888888888888"
    w.newChar(minion, { name = "Goblin", player = false, party = false })
    w.chars[minion].statuses.FFTJ_DOOM = true
    applied(w, minion, "FFTJ_DOOM", T.TAV)
    T.truthy(w.chars[minion].statuses.FFTJ_DOOM, "others keep it")
end

function S.gil_snapper_pays_for_damage_taken(w, T)
    local svc = T.boot(w)
    enemy(w)
    w.fire("AttackedBy", "S_Player_" .. T.TAV, "S_" .. GOB, "S_" .. GOB, "Slashing", 7, "Attack", 0)
    T.eq(w.chars[T.TAV].gold, 0, "only with Gil Snapper")
    svc.State:Get(T.TAV).Granted.Passives.FFTJ_GilSnapper = true
    w.fire("AttackedBy", "S_Player_" .. T.TAV, "S_" .. GOB, "S_" .. GOB, "Slashing", 7, "Attack", 0)
    T.eq(w.chars[T.TAV].gold, 7)
end

function S.poach_pays_for_a_marked_kill(w, T)
    local svc = T.boot(w)
    enemy(w, { level = 4 })
    svc.State:Get(T.TAV).Granted.Passives.FFTJ_Poach = true
    w.fire("KilledBy", "S_" .. GOB, "S_Player_" .. T.TAV, "S_Player_" .. T.TAV, 0)
    T.eq(w.chars[T.TAV].gold, 0, "not marked: nothing")
    applied(w, GOB, "FFTJ_POACH_MARK", T.TAV)
    w.fire("KilledBy", "S_" .. GOB, "S_Player_" .. T.TAV, "S_Player_" .. T.TAV, 0)
    T.eq(w.chars[T.TAV].gold, 20, "5 x level 4")
    T.contains(w.notifications, "Tav poached a trophy from Goblin worth 20 gold!")
end

function S.other_statuses_are_ignored(w, T)
    T.boot(w)
    local before = #w.osiCalls
    applied(w, T.TAV, "BLESS", T.SHART)
    T.eq(#w.osiCalls, before, "no game calls for statuses that are not ours")
end

return S
