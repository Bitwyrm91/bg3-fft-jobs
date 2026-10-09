-- The saved state: one plain table kept in memory and written to the "State" mod variable after changes.
local Util = Ext.Require("Shared/Util.lua")
local Rules = Ext.Require("Server/Rules.lua")

local State = {}
State.__index = State

State.Schema = 1

-- storage = {Read() -> table|nil, Write(table)}, defer = function(fn) run fn later (once per tick in game)
function State.New(storage, defer, log)
    local self = setmetatable({}, State)
    self.Storage = storage
    self.Defer = defer
    self.Log = log
    self.Root = nil
    self.Dirty = false
    self.FlushQueued = false
    return self
end

function State:IsLoaded()
    return self.Root ~= nil
end

local function emptyRoot()
    return { Schema = State.Schema, Chars = {}, Meta = { Disabled = false } }
end

-- Reads the mod variable once; a copy is kept so later writes never alias the SE's cached table.
function State:Load()
    local ok, saved = pcall(self.Storage.Read)
    if not ok then
        if self.Log then
            self.Log.Error("could not read saved state: " .. tostring(saved))
        end
        saved = nil
    end
    if type(saved) == "table" and saved.Schema ~= nil then
        self.Root = Util.DeepCopy(saved)
        self.Root.Chars = self.Root.Chars or {}
        self.Root.Meta = self.Root.Meta or { Disabled = false }
        for _, char in pairs(self.Root.Chars) do
            Rules.Normalize(char)
        end
    else
        self.Root = emptyRoot()
    end
    self.Dirty = false
    return self.Root
end

function State:Chars()
    return self.Root and self.Root.Chars or {}
end

function State:Get(guid)
    return self.Root and self.Root.Chars[guid]
end

function State:Set(guid, char)
    self.Root.Chars[guid] = char
    self:MarkDirty()
end

function State:Remove(guid)
    self.Root.Chars[guid] = nil
    self:MarkDirty()
end

function State:Meta()
    return self.Root.Meta
end

function State:Guids()
    return Util.SortedKeys(self:Chars())
end

function State:MarkDirty()
    self.Dirty = true
    if not self.FlushQueued then
        self.FlushQueued = true
        self.Defer(function()
            self.FlushQueued = false
            self:Flush()
        end)
    end
end

-- Writes the whole table to the mod variable (sub-table writes do not mark a variable as changed).
function State:Flush()
    if not self.Dirty or not self.Root then
        return
    end
    local ok, err = pcall(self.Storage.Write, self.Root)
    if ok then
        self.Dirty = false
    elseif self.Log then
        self.Log.Error("could not save state: " .. tostring(err))
    end
end

return State
