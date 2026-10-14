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
local Rules = Ext.Require("Server/Rules.lua")

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
-- Flask statuses cast with a higher spell slot end in "_<level>" (tools/upcast.py): FFTJ_CHEM_MIXUP_3 = level 3.
Effects.Upcast = { FFTJ_CHEM_MIXUP = true, FFTJ_CAUSTIC = true, FFTJ_UNSTABLE = true, FFTJ_FULMINATE = true }

function Effects.SplitLevel(status)
    local base, level = string.match(status or "", "^(.-)_(%d)$")
    if base and Effects.Upcast[base] then
        return base, tonumber(level)
    end
    return status, nil
end

function Effects.OnStatusApplied(svc, target, status, source)
    if not target then
        return
    end
    local level
    status, level = Effects.SplitLevel(status)
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
        Effects.ChemicalMixup(svc, source, target, level)
    elseif Effects.Bursts[status] then
        Effects.FlaskBurst(svc, source, target, Effects.Bursts[status], level)
    elseif status == "FFTJ_FULMINATE" then
        Effects.Fulminate(svc, source, target, level)
    elseif status == "FFTJ_CHEM_BURNS" then
        Effects.ChemicalBurns(svc, source, target)
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

-- Chemical Mixup / Chemical Burns (Chemist, custom abilities): four afflictions, each with its damage kind. Effects are
-- lengthened in place with SetStatusDuration(..., Add) (Burns' SpellSuccess, Mixup's FFTJ_MIXUP_EXTEND_* statuses),
-- never applied again: re-applying BURNING would deal its on-apply 1d4 fire once more. Extra turns: 2, in the stats.
Effects.Mixup = {
    { Type = "Fire", Status = "BURNING", Word = "fire" },
    { Type = "Acid", Status = "ACID", Word = "acid" },
    { Type = "Poison", Status = "POISONED", Word = "poison" },
    { Type = "Slashing", Status = "BLEEDING", Word = "glass shards" },
}
Effects.Roll = math.random -- tests swap it for a fixed roll

-- DOS2-style damage over time for BG3's own Poisoned and Acid (user, 2026-10-14: the whole game, everyone): at the
-- start of each creature's turn in a fight. Only the exact statuses, not vanilla statuses built on them (story
-- sickness, drinks), which would otherwise inherit a tick. Config Abilities.PoisonTickDie / AcidTickDie (0 = off).
Effects.Ticks = {
    { Status = "POISONED", Type = "Poison", Die = "PoisonTickDie" },
    { Status = "ACID", Type = "Acid", Die = "AcidTickDie" },
}

function Effects.OnTurnStarted(svc, guid)
    local cfg = svc:Cfg().Abilities
    for _, t in ipairs(Effects.Ticks) do
        local die = tonumber(cfg[t.Die]) or 0
        if die > 0 and svc.Game:Has("Statuses", guid, t.Status) then
            svc.Game:ApplyDamage(guid, Effects.Roll(die), t.Type, guid)
        end
    end
end

local function mixupDice(svc, caster)
    local level = caster and svc.Game:CharLevel(caster)
    local dice = 1
    for _, at in ipairs(svc:Cfg().Abilities.MixupDiceLevels or {}) do
        if type(level) == "number" and level >= at then
            dice = dice + 1
        end
    end
    return dice
end

local function rollDamage(svc, dice)
    local total = 0
    for _ = 1, dice do
        total = total + Effects.Roll(svc:Cfg().Abilities.MixupDie or 4)
    end
    return total
end

-- The afflictions a creature has: { [index in Effects.Mixup] = turns left (-1 = no end) }, and how many.
local function afflictions(svc, target)
    local has, n = {}, 0
    for i, a in ipairs(Effects.Mixup) do
        if svc.Game:HasStatus(target, a.Status) then
            has[i] = svc.Game:StatusTurns(target, a.Status) or 1
            n = n + 1
        end
    end
    return has, n
end

local function afflict(svc, target, status, turns, source)
    svc.Game:Try("ApplyStatus", function()
        Osi.ApplyStatus(target, status, 6 * turns, 1, source or target)
    end)
end

-- The shortest-lasting effect in `has` (turns >= 0), leaving out index `skip`.
local function shortest(has, skip)
    local low
    for i, turns in pairs(has) do
        if i ~= skip and turns >= 0 and (not low or turns < has[low]) then
            low = i
        end
    end
    return low
end

-- Saturation (Chemist support passive): a flask that added one of the four lengthens the shortest of the others the
-- target already had by 1 turn (FFTJ_SATURATE_* = SetStatusDuration(..., 1, Add)); once per throw.
local function saturate(svc, caster, target, has, skip)
    if not caster or not svc.Game:Has("Passives", caster, "FFTJ_Saturation") then
        return
    end
    local low = shortest(has, skip)
    if low then
        afflict(svc, target, "FFTJ_SATURATE_" .. Effects.Mixup[low].Status, 0, caster)
    end
end

-- level (spell slot, nil = the free cantrip): level N rolls N - 1 more dice and adds up to N effects.
function Effects.ChemicalMixup(svc, caster, target, level)
    local cfg = svc:Cfg().Abilities
    local has, n = afflictions(svc, target)
    local dice, picks, extra = mixupDice(svc, caster) + math.max(0, (level or 1) - 1), {}, ""
    if n < #Effects.Mixup then
        local missing = {}
        for i = 1, #Effects.Mixup do
            if not has[i] then
                missing[#missing + 1] = i
            end
        end
        -- Catalyst: with MixupCatalystAt effects already on, two missing ones at once
        local count = math.max((n >= (cfg.MixupCatalystAt or 2)) and 2 or 1, level or 1)
        for _ = 1, math.min(count, #missing) do
            local k = Effects.Roll(#missing)
            picks[#picks + 1] = Effects.Mixup[missing[k]]
            table.remove(missing, k)
        end
    else
        -- all four already: one more damage die, and the shortest effect lasts longer
        picks[1] = Effects.Mixup[Effects.Roll(#Effects.Mixup)]
        dice = dice + (cfg.MixupFullExtraDice or 1)
        local low = shortest(has)
        if low then
            afflict(svc, target, "FFTJ_MIXUP_EXTEND_" .. Effects.Mixup[low].Status, 0, caster)
            extra = ", " .. Effects.Mixup[low].Status .. " lengthened"
        end
    end
    local pick = picks[1]
    local damage = rollDamage(svc, dice)
    svc.Game:ApplyDamage(target, damage, pick.Type, caster)
    if n < #Effects.Mixup then
        if n > 0 then
            saturate(svc, caster, target, has)
        end
        for _, p in ipairs(picks) do
            afflict(svc, target, p.Status, cfg.MixupStatusTurns or 2, caster)
            extra = extra .. ", adds " .. p.Status
        end
    end
    svc.Log.Info(string.format("Chemical Mixup: %s, %d %s damage to %s%s", pick.Word, damage, pick.Type,
        name(svc, target), extra))
    return pick, damage, picks
end

function Effects.ChemicalBurns(svc, caster, target)
    local cfg = svc:Cfg().Abilities
    local has, n = afflictions(svc, target)
    local dice, total = mixupDice(svc, caster), 0
    for i in pairs(has) do
        local a = Effects.Mixup[i]
        local damage = rollDamage(svc, dice)
        total = total + damage
        svc.Game:ApplyDamage(target, damage, a.Type, caster) -- (the spell's SetStatusDuration adds the turns)
    end
    local spread = 0
    if n == #Effects.Mixup then
        -- all four: the target explodes and spreads them to enemies close by
        local radius = cfg.BurnsExplodeRadius or 3
        for _, other in ipairs(svc.Game:AllCharacters()) do
            local d = other ~= target and svc.Game:Distance(target, other)
            if d and d <= radius and not svc.Game:IsDead(other) and not svc.State:Get(other)
                and (not caster or svc.Game:IsEnemy(caster, other)) then
                for _, a in ipairs(Effects.Mixup) do
                    afflict(svc, other, a.Status, cfg.BurnsExplodeTurns or 2, caster)
                end
                spread = spread + 1
            end
        end
        tell(svc, caster, string.format("%s explodes in chemical fire!", name(svc, target)))
    end
    svc.Log.Info(string.format("Chemical Burns: %d effects on %s, %d damage, spread to %d", n, name(svc, target),
        total, spread))
    return n, total, spread
end

-- Caustic Flask / Unstable Flask (Chemist, custom cantrips): a burst around the target (allies too). Everyone caught
-- gets the flask's effect (not applied again if they already have it) and its damage; anyone who already had `If`
-- also gets `Adds`. Burning's own on-apply 1d4 fire counts as the first damage die.
Effects.Bursts = {
    FFTJ_CAUSTIC = { Name = "Caustic Flask", Type = "Acid", Status = "ACID", If = "BLEEDING", Adds = "POISONED" },
    FFTJ_UNSTABLE = { Name = "Unstable Flask", Type = "Fire", Status = "BURNING", If = "POISONED", Adds = "ACID" },
}

local function hasNamed(has, status)
    for i, a in ipairs(Effects.Mixup) do
        if a.Status == status then
            return has[i] ~= nil
        end
    end
    return false
end

function Effects.FlaskBurst(svc, caster, target, def, level)
    local cfg = svc:Cfg().Abilities
    local radius, turns = cfg.FlaskBurstRadius or 1.5, cfg.MixupStatusTurns or 2
    local dice = mixupDice(svc, caster) + math.max(0, (level or 1) - 1)
    local hit = 0
    for _, other in ipairs(svc.Game:AllCharacters()) do
        local d = other == target and 0 or svc.Game:Distance(target, other)
        if d and d <= radius and not svc.Game:IsDead(other) then
            local has, n = afflictions(svc, other)
            local already = hasNamed(has, def.Status)
            local own = (def.Status == "BURNING" and not already) and dice - 1 or dice
            if own > 0 then
                svc.Game:ApplyDamage(other, rollDamage(svc, own), def.Type, caster)
            end
            local added = false
            if not already then
                afflict(svc, other, def.Status, turns, caster)
                added = true
            end
            if hasNamed(has, def.If) and not hasNamed(has, def.Adds) then
                afflict(svc, other, def.Adds, turns, caster)
                added = true
            end
            if added and n > 0 then
                saturate(svc, caster, other, has)
            end
            hit = hit + 1
        end
    end
    svc.Log.Info(string.format("%s on %s: %d caught", def.Name, name(svc, target), hit))
    return hit
end

-- Fulminate Flask (Chemist, custom): a tiny burst around the target; a Burning target makes it larger and sets
-- everyone in it on fire (area effects hit allies too). Each creature caught gets FFTJ_FULMINATE_BLAST (damage + Constitution save, in the stats).
-- The save DC: the thrower's highest ability (the blast's per-ability twin, tools/statcast.py), else Intelligence.
function Effects.Fulminate(svc, caster, target, level)
    local blast = (level and level >= 2) and ("FFTJ_FULMINATE_BLAST_" .. level) or "FFTJ_FULMINATE_BLAST"
    blast = Rules.CastStatus(svc.Data, svc:GetChar(caster), svc:Cfg(), blast)
    local cfg = svc:Cfg().Abilities
    local burning = svc.Game:HasStatus(target, "BURNING")
    local radius = burning and (cfg.FulminateBurningRadius or 2) or (cfg.FulminateRadius or 1)
    local hit = 0
    for _, other in ipairs(svc.Game:AllCharacters()) do
        local d = other == target and 0 or svc.Game:Distance(target, other)
        if d and d <= radius and not svc.Game:IsDead(other) then
            afflict(svc, other, blast, 0, caster)
            if burning and other ~= target and not svc.Game:HasStatus(other, "BURNING") then
                local has, n = afflictions(svc, other)
                if n > 0 then
                    saturate(svc, caster, other, has)
                end
                afflict(svc, other, "BURNING", cfg.FulminateBurningTurns or 2, caster)
            end
            hit = hit + 1
        end
    end
    svc.Log.Info(string.format("Fulminate Flask on %s: %d caught (radius %s m%s)", name(svc, target), hit, radius,
        burning and ", Burning target" or ""))
    return hit, radius
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
