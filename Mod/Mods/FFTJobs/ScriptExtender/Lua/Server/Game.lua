-- Everything that talks to the game (Osi.*, Ext.Entity, Ext.Stats, ...). All calls are protected: a failing
-- call is logged once per name and returns nil, so one bad call never stops the rest of the engine.
local Util = Ext.Require("Shared/Util.lua")

local Game = {}
Game.__index = Game

function Game.New(log)
    local self = setmetatable({}, Game)
    self.Log = log
    self.Failed = {}
    self.CostCache = {}
    self.IconCache = {}
    return self
end

function Game:Try(name, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        if not self.Failed[name] then
            self.Failed[name] = true
            self.Log.Warn(name .. " failed: " .. tostring(result))
        end
        return nil
    end
    return result
end

local function isTrue(v)
    return v == 1 or v == true
end

function Game:HostCharacter()
    return Util.Guid(self:Try("GetHostCharacter", function()
        return Osi.GetHostCharacter()
    end))
end

function Game:IsInCombat(guid)
    return isTrue(self:Try("IsInCombat", function()
        return Osi.IsInCombat(guid)
    end))
end

function Game:IsDead(guid)
    return isTrue(self:Try("IsDead", function()
        return Osi.IsDead(guid)
    end))
end

function Game:IsSummon(guid)
    return isTrue(self:Try("IsSummon", function()
        return Osi.IsSummon(guid)
    end))
end

function Game:IsPlayer(guid)
    return isTrue(self:Try("IsPlayer", function()
        return Osi.IsPlayer(guid)
    end))
end

-- In the active party (controllable members only).
function Game:IsPartyMember(guid)
    return isTrue(self:Try("IsPartyMember", function()
        return Osi.IsPartyMember(guid, 0)
    end))
end

function Game:Entity(guid)
    return self:Try("Ext.Entity.Get", function()
        return Ext.Entity.Get(guid)
    end)
end

function Game:HasPartyMemberComponent(guid)
    local e = self:Entity(guid)
    return e ~= nil and self:Try("PartyMember component", function()
        return e.PartyMember ~= nil
    end) == true
end

-- Player characters and companions, not summons.
function Game:IsTrackable(guid)
    if type(guid) ~= "string" or #guid ~= 36 then
        return false
    end
    if self:IsSummon(guid) then
        return false
    end
    return self:IsPlayer(guid) or self:IsPartyMember(guid) or self:HasPartyMemberComponent(guid)
end

-- Every party member the game lists: DB_Players (Osiris) and entities with a PartyMember component.
-- (DB_IsPlayer, from the DOS2-era helper list, does not exist in BG3: seen in game 2026-10-12.)
function Game:PartyMembers()
    local seen, list = {}, {}
    local function add(raw)
        local g = Util.Guid(raw)
        if g and not seen[g] and self:IsTrackable(g) then
            seen[g] = true
            list[#list + 1] = g
        end
    end
    local rows = self:Try("DB_Players", function()
        return Osi.DB_Players:Get(nil)
    end)
    for _, row in ipairs(rows or {}) do
        add(row[1])
    end
    local entities = self:Try("GetAllEntitiesWithComponent(PartyMember)", function()
        return Ext.Entity.GetAllEntitiesWithComponent("PartyMember")
    end)
    for _, e in ipairs(entities or {}) do
        add(self:Try("Uuid component", function()
            return e.Uuid.EntityUuid
        end))
    end
    add(self:HostCharacter())
    return list
end

function Game:CharLevel(guid)
    return self:Try("GetLevel", function()
        return Osi.GetLevel(guid)
    end) or 1
end

function Game:TotalXP(guid)
    local e = self:Entity(guid)
    if not e then
        return nil
    end
    return self:Try("Experience component", function()
        return e.Experience and e.Experience.TotalExperience
    end)
end

function Game:DisplayName(guid)
    local name = self:Try("GetDisplayName", function()
        local handle = Osi.GetDisplayName(guid)
        return handle and Ext.Loca.GetTranslatedString(handle)
    end)
    if not name or name == "" then
        local e = self:Entity(guid)
        name = e and self:Try("DisplayName component", function()
            return e.DisplayName.Name:Get()
        end)
    end
    if not name or name == "" then
        name = string.sub(guid, 1, 8)
    end
    return name
end

-- BG3 class name of the first class ("Wizard", "Fighter", ...), or nil.
function Game:ClassName(guid)
    local e = self:Entity(guid)
    if not e then
        return nil
    end
    return self:Try("class lookup", function()
        local classes = e.Classes and e.Classes.Classes
        local first = classes and classes[1]
        if not first then
            return nil
        end
        local desc = Ext.StaticData.Get(first.ClassUUID, "ClassDescription")
        return desc and tostring(desc.Name)
    end)
end

-- "action", "bonus", "reaction", "free" from the spell's UseCosts, or nil when the stats are unreadable.
function Game:SpellCostKind(spellId)
    local cached = self.CostCache[spellId]
    if cached ~= nil then
        return cached or nil
    end
    local costs = self:Try("Ext.Stats.Get", function()
        local stat = Ext.Stats.Get(spellId, nil, false)
        return stat and stat.UseCosts
    end)
    local kind = false
    if type(costs) == "string" then
        local names = {}
        for part in string.gmatch(costs, "[^;]+") do
            local name = string.match(part, "^%s*([%w_]+)")
            if name then
                names[name] = true
            end
        end
        if names.ActionPoint then
            kind = "action"
        elseif names.BonusActionPoint then
            kind = "bonus"
        elseif names.ReactionActionPoint then
            kind = "reaction"
        else
            kind = "free"
        end
    end
    self.CostCache[spellId] = kind
    return kind or nil
end

-- The icon of a spell/passive/status stats entry (resolved through its using chain by the game), or nil.
function Game:StatIcon(statId)
    if type(statId) ~= "string" then
        return nil
    end
    local cached = self.IconCache[statId]
    if cached ~= nil then
        return cached or nil
    end
    local icon = self:Try("Ext.Stats.Get icon", function()
        local stat = Ext.Stats.Get(statId, nil, false)
        return stat and stat.Icon
    end)
    self.IconCache[statId] = (type(icon) == "string" and icon ~= "") and icon or false
    return self.IconCache[statId] or nil
end

---------------------------------------------------------------- grants

function Game:Has(kind, guid, id)
    if kind == "Spells" then
        return isTrue(self:Try("HasSpell", function()
            return Osi.HasSpell(guid, id)
        end))
    elseif kind == "Passives" then
        return isTrue(self:Try("HasPassive", function()
            return Osi.HasPassive(guid, id)
        end))
    else
        return isTrue(self:Try("HasActiveStatus", function()
            return Osi.HasActiveStatus(guid, id)
        end))
    end
end

function Game:Add(kind, guid, id)
    if kind == "Spells" then
        self:Try("AddSpell", function()
            Osi.AddSpell(guid, id, 0, 1)
        end)
    elseif kind == "Passives" then
        self:Try("AddPassive", function()
            Osi.AddPassive(guid, id)
        end)
    else
        self:Try("ApplyStatus", function()
            Osi.ApplyStatus(guid, id, -1, 1, guid)
        end)
    end
end

function Game:Remove(kind, guid, id)
    if kind == "Spells" then
        self:Try("RemoveSpell", function()
            Osi.RemoveSpell(guid, id, 1)
        end)
    elseif kind == "Passives" then
        self:Try("RemovePassive", function()
            Osi.RemovePassive(guid, id)
        end)
    else
        self:Try("RemoveStatus", function()
            Osi.RemoveStatus(guid, id)
        end)
    end
end

function Game:Notify(guid, text)
    self:Try("ShowNotification", function()
        Osi.ShowNotification(guid, text)
    end)
end

---------------------------------------------------------------- job ability effects (Effects.lua)
-- Osiris names and arities from LaughingLeader's generated Osi.lua (2026-10-12). UNVERIFIED IN GAME: the slot
-- names ("Helmet", "Breast", "Melee Main Weapon", ...), the item stats lookup in IsShield, Health.MaxHp.

function Game:EquippedItem(guid, slot)
    local item = self:Try("GetEquippedItem", function()
        return Osi.GetEquippedItem(guid, slot)
    end)
    return (type(item) == "string" and item ~= "") and item or nil
end

-- true/false from the item's stats (a shield is an Armor entry), nil when they can't be read.
function Game:IsShield(item)
    local e = self:Entity(item)
    local statsId = e and self:Try("item stats id", function()
        return e.Data and e.Data.StatsId
    end)
    if type(statsId) ~= "string" or statsId == "" then
        return nil
    end
    local list = self:Try("item stats type", function()
        local stat = Ext.Stats.Get(statsId, nil, false)
        return stat and stat.ModifierList
    end)
    if type(list) ~= "string" then
        return nil
    end
    return list == "Armor"
end

function Game:IsStoryItem(item)
    return isTrue(self:Try("IsStoryItem", function()
        return Osi.IsStoryItem(item)
    end))
end

function Game:Unequip(guid, item)
    self:Try("Unequip", function()
        Osi.Unequip(guid, item)
    end)
end

function Game:ToInventory(item, guid)
    self:Try("ToInventory", function()
        Osi.ToInventory(item, guid, 1, 1, 1)
    end)
end

function Game:AddGold(guid, amount)
    self:Try("AddGold", function()
        Osi.AddGold(guid, amount)
    end)
end

function Game:AddExplorationXP(guid, amount)
    self:Try("AddExplorationExperience", function()
        Osi.AddExplorationExperience(guid, amount)
    end)
end

function Game:IsBoss(guid)
    return isTrue(self:Try("IsBoss", function()
        return Osi.IsBoss(guid)
    end))
end

function Game:MaxHP(guid)
    local e = self:Entity(guid)
    return e and self:Try("Health component", function()
        return e.Health and e.Health.MaxHp
    end)
end

function Game:ApplyDamage(guid, amount, damageType, source)
    self:Try("ApplyDamage", function()
        Osi.ApplyDamage(guid, amount, damageType, source or guid)
    end)
end

return Game
