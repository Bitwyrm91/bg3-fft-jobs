-- Peddler (Fell Seal job, 2026-10-14): the parts of its abilities that need the server script.
--   Traps: the trap item's projectile marks the creature that walked in (FFTJ_TRAP_SPRUNG_*). Here: its turn ends at
--   once (only while it is that creature's turn), then the trap's effect lands with the trap's owner as the source
--   (a Dexterity save against the owner's DC: FFTJ_TRAP_* status twins from tools/statcast.py), or Painful Trap takes
--   a share of its current HP (config Abilities.PainfulTrapShare, no save; bosses too, as in Fell Seal).
--   Item Potency on BG3's own items: a healing potion drunk or thrown by someone with Item Potency heals a second time
--   (FFTJ_POTENT_* twins); Alchemist's Fire thrown by them burns twice as long. The Chemist skills and grenades are
--   stats only (FFTJ_ItemPotency, FFTJ_ItemPotency_Heal).
local Rules = Ext.Require("Server/Rules.lua")

local Peddler = {}

-- marker -> the spell that lays the trap (its last caster is the owner when the game can't name one), the effect
Peddler.Traps = {
    FFTJ_TRAP_SPRUNG_LACERATING = { Spell = "Target_FFTJ_LaceratingTrap", Effect = "FFTJ_TRAP_LACERATE",
        Name = "Lacerating Trap" },
    FFTJ_TRAP_SPRUNG_IMMOBILIZING = { Spell = "Target_FFTJ_ImmobilizingTrap", Effect = "FFTJ_TRAP_IMMOBILIZE",
        Name = "Immobilizing Trap" },
    FFTJ_TRAP_SPRUNG_PAINFUL = { Spell = "Target_FFTJ_PainfulTrap", Painful = true, Name = "Painful Trap" },
    FFTJ_TRAP_SPRUNG_ALLURING = { Spell = "Target_FFTJ_AlluringTrap", Effect = "FFTJ_TRAP_ALLURE",
        Name = "Alluring Trap" },
}
Peddler.TrapSpells = {}
for _, def in pairs(Peddler.Traps) do
    Peddler.TrapSpells[def.Spell] = true
end

-- BG3 healing potion status -> our twin with the same healing (Status_FFTJ_Peddler.txt)
Peddler.Potions = {
    POTION_OF_HEALING = "FFTJ_POTENT_HEALING",
    POTION_OF_HEALING_GREATER = "FFTJ_POTENT_HEALING_GREATER",
    POTION_OF_HEALING_SUPERIOR = "FFTJ_POTENT_HEALING_SUPERIOR",
    POTION_OF_HEALING_SUPREME = "FFTJ_POTENT_HEALING_SUPREME",
}
Peddler.POTENCY = "FFTJ_ItemPotency"
Peddler.ALCHEMIST_FIRE = "Projectile_AlchemistFire"
Peddler.FIRE_TURNS = 6 -- vanilla Alchemist's Fire: Burning for 3 turns
Peddler.FIRE_WINDOW_MS = 3000 -- the Burning of a throw arrives right after the cast

-- Cheap test for the StatusApplied event (it fires for every status in the game).
function Peddler.Handles(status)
    return Peddler.Traps[status] ~= nil or Peddler.Potions[status] ~= nil or status == "BURNING"
end

local function hasPotency(svc, guid)
    local char = guid and svc.State:Get(guid)
    return char ~= nil and char.Granted ~= nil and char.Granted.Passives ~= nil
        and char.Granted.Passives[Peddler.POTENCY] == true
end

local function name(svc, guid)
    local char = guid and svc.State:Get(guid)
    return (char and char.Name) or (guid and svc.Game:DisplayName(guid)) or "Someone"
end

-- Osiris CastedSpell (party members): who laid which trap last; an Alchemist's Fire throw with Item Potency.
function Peddler.OnCastedSpell(svc, caster, spell)
    if type(spell) ~= "string" or not caster then
        return
    end
    local base = string.gsub(spell, "_Echo$", "")
    if Peddler.TrapSpells[base] then
        svc.TrapLayers[base] = caster
    elseif spell == Peddler.ALCHEMIST_FIRE and hasPotency(svc, caster) then
        local throw = { Done = {} }
        svc.FireThrows[caster] = throw
        svc.WaitFor(Peddler.FIRE_WINDOW_MS, function()
            if svc.FireThrows[caster] == throw then
                svc.FireThrows[caster] = nil
            end
        end)
    end
end

-- The trap's owner: the summoner of the trap item that fired, else the last party member who laid that trap.
function Peddler.Owner(svc, source, def)
    local owner = source and svc.Game:OwnerOf(source)
    if owner and svc.State:Get(owner) then
        return owner
    end
    if source and svc.State:Get(source) then
        return source
    end
    return svc.TrapLayers[def.Spell]
end

function Peddler.Spring(svc, target, def, source)
    local game = svc.Game
    local owner = Peddler.Owner(svc, source, def)
    if def.Painful then
        local hp = game:HP(target)
        if type(hp) == "number" and hp > 0 then
            local damage = math.max(1, math.floor(hp * svc:Cfg().Abilities.PainfulTrapShare))
            game:ApplyDamage(target, damage, "Piercing", owner or source)
            svc.Log.Info(string.format("%s: %d piercing damage to %s", def.Name, damage, name(svc, target)))
        end
    else
        local status = Rules.CastStatus(svc.Data, owner and svc.State:Get(owner), svc:Cfg(), def.Effect)
        game:ApplyStatusFrom(target, status, 0, owner or source)
        svc.Log.Info(string.format("%s sprang on %s (%s)", def.Name, name(svc, target), status))
    end
    if svc.ActiveTurn == target then
        game:EndTurn(target)
    end
end

-- Osiris StatusApplied(object, status, causee) for the statuses Peddler.Handles accepts.
function Peddler.OnStatusApplied(svc, target, status, source)
    if not target then
        return
    end
    local def = Peddler.Traps[status]
    if def then
        Peddler.Spring(svc, target, def, source)
    elseif Peddler.Potions[status] then
        if hasPotency(svc, source) then
            svc.Game:ApplyStatusFrom(target, Peddler.Potions[status], 0, source)
        end
    elseif status == "BURNING" then
        local throw = source and svc.FireThrows[source]
        if throw and not throw.Done[target] then
            throw.Done[target] = true -- our own re-apply below fires this event again
            svc.Game:ApplyStatusFrom(target, "BURNING", Peddler.FIRE_TURNS * 6, source)
        end
    end
end

return Peddler
