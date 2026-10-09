-- Applies the difference between what a character should have (Rules.DesiredGrants) and what the mod
-- granted before (char.Granted). Only things the mod added are ever removed.
local Util = Ext.Require("Shared/Util.lua")

local Grants = {}

Grants.Kinds = { "Spells", "Passives", "Statuses" }

-- repair = true also re-adds owned grants the character lost (respec, old saves). Returns changed (bool).
function Grants.Apply(game, guid, char, desired, repair)
    local changed = false
    char.Granted = char.Granted or {}
    for _, kind in ipairs(Grants.Kinds) do
        local owned = char.Granted[kind] or {}
        char.Granted[kind] = owned
        local want = desired[kind] or {}
        -- remove first, so a variant swap (e.g. Potion -> thrown Potion) never stacks both
        for _, id in ipairs(Util.SortedKeys(owned)) do
            if not want[id] then
                game:Remove(kind, guid, id)
                owned[id] = nil
                changed = true
            end
        end
        for _, id in ipairs(Util.SortedKeys(want)) do
            if not owned[id] then
                if not game:Has(kind, guid, id) then
                    game:Add(kind, guid, id)
                    owned[id] = true
                    changed = true
                end
            elseif repair and not game:Has(kind, guid, id) then
                game:Add(kind, guid, id)
            end
        end
    end
    return changed
end

function Grants.RemoveAll(game, guid, char)
    local empty = { Spells = {}, Passives = {}, Statuses = {} }
    return Grants.Apply(game, guid, char, empty, false)
end

return Grants
