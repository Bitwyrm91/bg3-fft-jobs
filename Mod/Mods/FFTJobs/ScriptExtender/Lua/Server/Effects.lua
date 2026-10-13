-- Job abilities whose effect needs the server script. The stats only apply a marker status (or a passive marks the
-- character); Osiris events bring them here:
--   Steal (Thief): the item moves from the target's equipment to the thief's inventory; gold; experience.
--   Crush (Divine Knight): the item falls off the target onto the ground.
--   Gravity, Graviga (Time Mage): a share of the target's maximum HP as force damage.
--   Bosses shrug off Doom, Stop and Stone, as in FFT.
--   Gil Snapper (Thief): gold equal to the damage taken.
--   Poach (Thief): a monster the poacher hit this turn pays out when it dies.
--   Abyssal Blade, Unholy Sacrifice (Dark Knight): the caster pays a share of its maximum HP (never the last one).
-- Every number is in the config (Abilities.*).
local Effects = {}

-- Spell -> the config key of the share of the caster's maximum HP it costs (an Echo of it costs the same).
Effects.Sacrifice = {
    Shout_FFTJ_AbyssalBlade = "AbyssalBladeHPCost", Shout_FFTJ_UnholySacrifice = "UnholySacrificeHPCost",
}

-- Steal marker -> the equipment slots it searches, in order (BG3 slot names for Osi.GetEquippedItem), and its name.
Effects.Steal = {
    FFTJ_STEAL_HELM = { Slots = { "Helmet" }, What = "headwear" },
    FFTJ_STEAL_ARMOR = { Slots = { "Breast" }, What = "armour" },
    FFTJ_STEAL_SHIELD = { Slots = { "Melee Offhand Weapon" }, What = "shield", ShieldOnly = true },
    FFTJ_STEAL_WEAPON = { Slots = { "Melee Main Weapon", "Ranged Main Weapon" }, What = "weapon" },
    FFTJ_STEAL_ACCESSORY = { Slots = { "Amulet", "Ring", "Ring2", "Cloak", "Gloves", "Boots" }, What = "accessory" },
}
-- Crush marker (Divine Knight's Unyielding Blade) -> the slots it searches: the item is knocked off and dropped on the
-- ground (FFT destroys it; here the loot stays), story items hold.
Effects.Crush = {
    FFTJ_CRUSH_HELM = { Slots = { "Helmet" }, What = "headwear" },
    FFTJ_CRUSH_ARMOR = { Slots = { "Breast" }, What = "armour" },
    FFTJ_CRUSH_WEAPON = { Slots = { "Melee Main Weapon", "Ranged Main Weapon" }, What = "weapon" },
    FFTJ_CRUSH_ACCESSORY = { Slots = { "Amulet", "Ring", "Ring2", "Cloak", "Gloves", "Boots" }, What = "accessory" },
}
-- Steal marker -> what is taken once per creature.
Effects.StealOnce = { FFTJ_STEAL_GIL = "Gil", FFTJ_STEAL_EXP = "EXP" }
-- Gravity marker -> the config key of the share of maximum HP it takes.
Effects.Gravity = { FFTJ_GRAVITY = "GravityShare", FFTJ_GRAVIGA = "GravigaShare" }
-- Statuses FFT bosses are immune to: the script lifts them off a boss right away.
Effects.BossImmune = {
    FFTJ_DOOM = true, FFTJ_STOP = true, FFTJ_STONE = true, FFTJ_ENTICED = true, FFTJ_TAMED = true,
    FFTJ_TOAD = true,
}

-- Cheap test for the StatusApplied event, which fires for every status in the game.
function Effects.Handles(status)
    return type(status) == "string" and string.sub(status, 1, 5) == "FFTJ_"
end

-- A message for the player who used the ability (party members only; always in the log).
local function tell(svc, guid, text)
    if guid and svc.State:Get(guid) then
        svc:Notify(guid, text)
    else
        svc.Log.Info(text)
    end
end

local function name(svc, guid)
    local char = guid and svc.State:Get(guid)
    return (char and char.Name) or (guid and svc.Game:DisplayName(guid)) or "Someone"
end

-- Osiris StatusApplied(object, status, causee): target = the creature, source = who applied the status.
function Effects.OnStatusApplied(svc, target, status, source)
    if not target then
        return
    end
    if Effects.BossImmune[status] then
        if svc.Game:IsBoss(target) then
            svc.Game:Remove("Statuses", target, status)
            tell(svc, source, string.format("%s is immune.", name(svc, target)))
        end
    elseif Effects.Steal[status] then
        Effects.StealItem(svc, source, target, Effects.Steal[status])
    elseif Effects.Crush[status] then
        Effects.CrushItem(svc, source, target, Effects.Crush[status])
    elseif Effects.StealOnce[status] then
        Effects.StealOnceFrom(svc, source, target, Effects.StealOnce[status])
    elseif Effects.Gravity[status] then
        Effects.GravityHit(svc, source, target, Effects.Gravity[status])
    elseif status == "FFTJ_CHEM_MIXUP" then
        Effects.ChemicalMixup(svc, source, target)
    elseif status == "FFTJ_POACH_MARK" and source then
        svc.PoachMarks[target] = source
    end
end

function Effects.StealItem(svc, thief, target, def)
    local game = svc.Game
    if not thief then
        return
    end
    for _, slot in ipairs(def.Slots) do
        local item = game:EquippedItem(target, slot)
        -- IsShield is nil when the item's stats can't be read: the off-hand item is taken then
        if item and (not def.ShieldOnly or game:IsShield(item) ~= false) then
            if game:IsStoryItem(item) then
                tell(svc, thief, string.format("%s's %s can't be stolen.", name(svc, target), def.What))
                return
            end
            game:Unequip(target, item)
            game:ToInventory(item, thief)
            tell(svc, thief, string.format("%s stole %s from %s!", name(svc, thief), game:DisplayName(item),
                name(svc, target)))
            return
        end
    end
    tell(svc, thief, string.format("%s has no %s to steal.", name(svc, target), def.What))
end

-- Unyielding Blade: the first item found in the marker's slots falls off the target onto the ground.
function Effects.CrushItem(svc, attacker, target, def)
    local game = svc.Game
    for _, slot in ipairs(def.Slots) do
        local item = game:EquippedItem(target, slot)
        if item then
            if game:IsStoryItem(item) then
                tell(svc, attacker, string.format("%s's %s holds.", name(svc, target), def.What))
                return
            end
            game:Unequip(target, item)
            game:Drop(item)
            tell(svc, attacker, string.format("%s knocked %s off %s!", name(svc, attacker), game:DisplayName(item),
                name(svc, target)))
            return
        end
    end
    tell(svc, attacker, string.format("%s has no %s to break.", name(svc, target), def.What))
end

-- Gold or experience, once per creature (saved: Meta.Robbed[target][kind]).
function Effects.StealOnceFrom(svc, thief, target, kind)
    if not thief then
        return
    end
    local meta = svc.State:Meta()
    meta.Robbed = meta.Robbed or {}
    local marks = meta.Robbed[target] or {}
    local what = kind == "Gil" and "gold" or "experience"
    if marks[kind] then
        tell(svc, thief, string.format("%s has no %s left to steal.", name(svc, target), what))
        return
    end
    local cfg = svc:Cfg().Abilities
    local level = svc.Game:CharLevel(target)
    local amount
    if kind == "Gil" then
        amount = math.floor(cfg.StealGilPerLevel * level)
        svc.Game:AddGold(thief, amount)
    else
        amount = math.floor(cfg.StealEXPPerLevel * level)
        svc.Game:AddExplorationXP(thief, amount)
    end
    marks[kind] = true
    meta.Robbed[target] = marks
    svc.State:MarkDirty()
    tell(svc, thief, string.format("%s stole %d %s from %s!", name(svc, thief), amount, what, name(svc, target)))
end

function Effects.GravityHit(svc, caster, target, shareKey)
    local game = svc.Game
    if game:IsBoss(target) then
        tell(svc, caster, string.format("%s is immune.", name(svc, target)))
        return
    end
    local maxHp = game:MaxHP(target)
    if type(maxHp) ~= "number" or maxHp <= 0 then
        return
    end
    local damage = math.max(1, math.floor(maxHp * svc:Cfg().Abilities[shareKey]))
    game:ApplyDamage(target, damage, "Force", caster)
    svc.Log.Info(string.format("%s: %d force damage to %s", shareKey == "GravigaShare" and "Graviga" or "Gravity",
        damage, name(svc, target)))
end

-- Chemical Mixup (Chemist): a random element, damage that scales like a cantrip, and the matching effect.
Effects.Mixup = {
    { Type = "Fire", Status = "BURNING", Word = "fire" },
    { Type = "Acid", Status = "ACID", Word = "acid" },
    { Type = "Poison", Status = "POISONED", Word = "poison" },
    { Type = "Slashing", Status = "BLEEDING", Word = "glass shards" },
}

function Effects.ChemicalMixup(svc, caster, target, roll)
    roll = roll or math.random
    local cfg = svc:Cfg().Abilities
    local pick = Effects.Mixup[roll(#Effects.Mixup)]
    local level = (caster and svc.Game:CharLevel(caster)) or 1
    local dice = 1
    for _, at in ipairs(cfg.MixupDiceLevels or {}) do
        if type(level) == "number" and level >= at then
            dice = dice + 1
        end
    end
    local damage = 0
    for _ = 1, dice do
        damage = damage + roll(cfg.MixupDie or 4)
    end
    svc.Game:ApplyDamage(target, damage, pick.Type, caster)
    svc.Game:Try("ApplyStatus", function()
        Osi.ApplyStatus(target, pick.Status, 6 * (cfg.MixupStatusTurns or 2), 1, caster or target)
    end)
    svc.Log.Info(string.format("Chemical Mixup: %s, %d %s damage to %s", pick.Word, damage, pick.Type,
        name(svc, target)))
    return pick, damage
end

-- Osiris CastedSpell (once per cast, unlike a status on every target): the Dark Knight's HP sacrifice.
function Effects.OnCastedSpell(svc, caster, spell)
    local key = type(spell) == "string" and Effects.Sacrifice[(string.gsub(spell, "_Echo$", ""))]
    if not key or not caster then
        return
    end
    local game = svc.Game
    local maxHp, hp = game:MaxHP(caster), game:HP(caster)
    if type(maxHp) ~= "number" or type(hp) ~= "number" or maxHp <= 0 then
        return
    end
    local cost = math.min(math.max(1, math.floor(maxHp * svc:Cfg().Abilities[key])), hp - 1)
    if cost > 0 then
        game:ApplyDamage(caster, cost, "Necrotic", caster)
        svc.Log.Info(string.format("%s sacrificed %d HP (%s)", name(svc, caster), cost, spell))
    end
end

-- Osiris AttackedBy: Gil Snapper pays gold for the damage taken.
function Effects.OnAttackedBy(svc, defender, amount)
    local char = defender and svc.State:Get(defender)
    if not char or not (char.Granted and char.Granted.Passives and char.Granted.Passives.FFTJ_GilSnapper) then
        return
    end
    if type(amount) ~= "number" or amount <= 0 then
        return
    end
    local gold = math.floor(amount * svc:Cfg().Abilities.GilSnapperShare)
    if gold > 0 then
        svc.Game:AddGold(defender, gold)
        svc.Log.Info(string.format("%s snapped up %d gold (Gil Snapper)", char.Name or defender, gold))
    end
end

-- Osiris KilledBy: a creature marked by a poacher this turn pays out.
function Effects.OnKilledBy(svc, defender)
    local poacher = defender and svc.PoachMarks[defender]
    if not poacher then
        return
    end
    svc.PoachMarks[defender] = nil
    local char = svc.State:Get(poacher)
    if not char or not (char.Granted and char.Granted.Passives and char.Granted.Passives.FFTJ_Poach) then
        return
    end
    local gold = math.floor(svc:Cfg().Abilities.PoachGoldPerLevel * svc.Game:CharLevel(defender))
    if gold > 0 then
        svc.Game:AddGold(poacher, gold)
        tell(svc, poacher, string.format("%s poached a trophy from %s worth %d gold!", char.Name, name(svc, defender),
            gold))
    end
end

return Effects
