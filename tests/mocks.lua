-- Mock Script Extender (Ext) and Osiris (Osi) for running the mod's Lua outside the game (Lua 5.4).
-- Install() builds a fresh fake world and fresh module cache for every test.
local Mocks = {}

local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]tests[/\\]mocks%.lua$")) or "."
Mocks.Root = ROOT
Mocks.LuaDir = ROOT .. "/Mod/Mods/FFTJobs/ScriptExtender/Lua/"
Mocks.ModUUID = "3db7be3e-9387-4678-b172-044acc7ff0c2"

local json = dofile(ROOT .. "/tests/lib/json.lua")
Mocks.Json = json

local function subscribable(world, name)
    local ev = { handlers = {} }
    function ev:Subscribe(fn)
        self.handlers[#self.handlers + 1] = fn
        return #self.handlers
    end
    function ev:Unsubscribe(i)
        self.handlers[i] = nil
    end
    world.events[name] = ev
    return ev
end

-- Characters: guid -> {name, level, xp, class, player, summon, party, inCombat, dead, spells{}, passives{}, statuses{},
-- equipment{slot = item guid}, inventory{item guids}, gold, boss, hp, maxHp}
function Mocks.NewChar(world, guid, fields)
    local c = {
        name = "Char", level = 1, xp = 0, class = "Fighter", player = true, summon = false, party = true,
        inCombat = false, dead = false, spells = {}, passives = {}, statuses = {},
        equipment = {}, inventory = {}, gold = 0, boss = false, hp = 20, maxHp = 20,
    }
    for k, v in pairs(fields or {}) do
        c[k] = v
    end
    world.chars[guid] = c
    world.loca["h_" .. guid] = c.name
    return c
end

local function newChannel(world, name)
    local ch = { name = name, sent = {} }
    function ch:SetRequestHandler(fn)
        self.requestHandler = fn
    end
    function ch:SetHandler(fn)
        self.handler = fn
    end
    function ch:Broadcast(data)
        self.sent[#self.sent + 1] = data
        local peer = world.clientChannels[name]
        if peer and peer.handler then
            peer.handler(json.decode(json.encode(data)), nil)
        end
    end
    function ch:SendToClient(data, user)
        self.sentTo = self.sentTo or {}
        self.sentTo[#self.sentTo + 1] = { data = data, user = user }
        self:Broadcast(data)
    end
    function ch:RequestToServer(data, cb)
        local server = world.serverChannels[name]
        local reply = server.requestHandler(json.decode(json.encode(data)), 1)
        cb(json.decode(json.encode(reply)))
    end
    return ch
end

-- A minimal IMGUI: records the widget tree so tests can find and click buttons.
local function newWidget(kind, label)
    local w = { Kind = kind, Label = label, Children = {}, Visible = true }
    local mt = {}
    mt.__index = function(self, key)
        if key:sub(1, 3) == "Add" then
            return function(parent, lbl, ...)
                local child = newWidget(key:sub(4), lbl)
                child.Parent = parent
                parent.Children[#parent.Children + 1] = child
                return child
            end
        end
        return nil
    end
    setmetatable(w, mt)
    function w:Destroy()
        self.Destroyed = true
        if self.Parent then
            for i, c in ipairs(self.Parent.Children) do
                if c == self then
                    table.remove(self.Parent.Children, i)
                    break
                end
            end
        end
    end
    function w:Tooltip()
        local t = newWidget("Tooltip", nil)
        self.TooltipWidget = t
        return t
    end
    function w:SetStyleColor(name, color)
        self.StyleColors = self.StyleColors or {}
        self.StyleColors[name] = color
    end
    w.SetColor = w.SetStyleColor -- SE v33's name
    function w:SetStyle(name, a, b)
        self.StyleVars = self.StyleVars or {}
        self.StyleVars[name] = { a, b }
    end
    function w:SetStyleVar(name, a, b)
        self.StyleVars = self.StyleVars or {}
        self.StyleVars[name] = { a, b }
    end
    function w:SetSize(size, cond)
        self.Size = size
    end
    return w
end

function Mocks.FindWidgets(root, pred, out)
    out = out or {}
    for _, c in ipairs(root.Children or {}) do
        if pred(c) then
            out[#out + 1] = c
        end
        Mocks.FindWidgets(c, pred, out)
    end
    return out
end

function Mocks.Install()
    local world = {
        chars = {}, files = {}, prints = {}, notifications = {}, timers = {}, ticks = {}, listeners = {}, usedSpells = {},
        events = {}, commands = {}, stats = {}, loca = {}, modVars = {}, classUuids = {},
        serverChannels = {}, clientChannels = {}, windows = {}, host = nil, osiCalls = {}, side = "server",
        items = {}, itemStats = {}, notified = {},
        controlled = nil, -- the client's ClientControl character
        defeated = {}, -- guid -> true: the story's DB_Defeated (boss badges)
        level = nil, -- Osi.GetRegion of the host
    }
    local cache = {}

    local modVarsProxy = setmetatable({}, {
        __index = function(_, key)
            local s = world.modVars[key]
            return s and json.decode(s) or nil
        end,
        __newindex = function(_, key, value)
            world.modVars[key] = json.encode(value) -- the SE serializes Vars to JSON on write
        end,
    })

    _G.ModuleUUID = Mocks.ModUUID
    _G.Mods = { FFTJobs = {} }
    _G.FFTJ = nil
    _G.Ext = {
        Require = function(path)
            local key = world.side .. ":" .. path
            if cache[key] == nil then
                local chunk = assert(loadfile(Mocks.LuaDir .. path))
                cache[key] = chunk() or true
            end
            return cache[key]
        end,
        Utils = {
            Print = function(...)
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[#parts + 1] = tostring((select(i, ...)))
                end
                world.prints[#world.prints + 1] = table.concat(parts, " ")
            end,
        },
        Json = {
            Parse = function(s)
                return json.decode(s)
            end,
            Stringify = function(v, opts)
                return json.encode(v)
            end,
        },
        IO = {
            LoadFile = function(p)
                return world.files[p]
            end,
            SaveFile = function(p, t)
                world.files[p] = t
                return true
            end,
        },
        Vars = {
            RegisterModVariable = function(uuid, name, opts)
                world.registeredVars = world.registeredVars or {}
                world.registeredVars[#world.registeredVars + 1] = { uuid = uuid, name = name, opts = opts, side = world.side }
            end,
            GetModVariables = function(uuid)
                assert(uuid == Mocks.ModUUID, "unexpected mod uuid " .. tostring(uuid))
                return modVarsProxy
            end,
        },
        Osiris = {
            RegisterListener = function(name, arity, when, fn)
                assert(when == "after" or when == "before", "bad listener timing")
                world.listeners[name] = { arity = arity, fn = fn }
            end,
        },
        Events = {},
        RegisterConsoleCommand = function(name, fn)
            world.commands[name] = fn
        end,
        Timer = {
            WaitFor = function(ms, fn)
                world.timers[#world.timers + 1] = { ms = ms, fn = fn }
                return #world.timers
            end,
            ClockTime = function()
                return "2026-10-09 12:00:00"
            end,
        },
        OnNextTick = function(fn)
            world.ticks[#world.ticks + 1] = fn
        end,
        Entity = {
            Get = function(guid)
                local item = world.items[guid]
                if item then
                    return { Data = { StatsId = item.stats } }
                end
                local c = world.chars[guid]
                if not c then
                    return nil
                end
                return {
                    Health = { Hp = c.hp, MaxHp = c.maxHp },
                    Experience = { TotalExperience = c.xp },
                    Classes = { Classes = { { ClassUUID = "class-" .. c.class } } },
                    DisplayName = { Name = { Get = function()
                        return c.name
                    end } },
                    PartyMember = c.party and {} or nil,
                    Uuid = { EntityUuid = guid },
                    Data = { StatsId = c.stats },
                    -- SE layout: indexed by AbilityId, None first (c.abilities = {Strength = n, ...})
                    Stats = c.abilities and { Abilities = { 0, c.abilities.Strength, c.abilities.Dexterity,
                        c.abilities.Constitution, c.abilities.Intelligence, c.abilities.Wisdom, c.abilities.Charisma } } or nil,
                }
            end,
            GetAllEntitiesWithComponent = function(name)
                local out = {}
                if name == "ServerCharacter" then
                    for guid in pairs(world.chars) do
                        out[#out + 1] = { Uuid = { EntityUuid = guid } }
                    end
                end
                if name == "ClientControl" and world.controlled then
                    out[#out + 1] = { Uuid = { EntityUuid = world.controlled } }
                end
                if name == "PartyMember" then
                    for guid, c in pairs(world.chars) do
                        if c.party then
                            out[#out + 1] = { Uuid = { EntityUuid = guid } }
                        end
                    end
                end
                return out
            end,
        },
        Stats = {
            Get = function(id)
                if world.itemStats[id] then
                    return world.itemStats[id]
                end
                local costs = world.stats[id]
                return costs and { UseCosts = costs } or nil
            end,
        },
        StaticData = {
            Get = function(uuid, kind)
                assert(kind == "ClassDescription")
                local name = string.match(uuid, "^class%-(.+)$")
                return name and { Name = name } or nil
            end,
        },
        Loca = {
            GetTranslatedString = function(h)
                return world.loca[h] or ""
            end,
        },
        Net = {
            CreateChannel = function(uuid, name)
                assert(uuid == Mocks.ModUUID)
                local ch = newChannel(world, name)
                if world.side == "server" then
                    world.serverChannels[name] = ch
                else
                    world.clientChannels[name] = ch
                end
                return ch
            end,
        },
        IMGUI = {
            NewWindow = function(title)
                local w = newWidget("Window", title)
                world.windows[#world.windows + 1] = w
                return w
            end,
        },
    }
    subscribable(world, "SessionLoaded")
    subscribable(world, "ResetCompleted")
    Ext.Events.SessionLoaded = world.events.SessionLoaded
    Ext.Events.ResetCompleted = world.events.ResetCompleted

    local function rec(name, ...)
        world.osiCalls[#world.osiCalls + 1] = { name, ... }
    end
    local function char(guid)
        local c = world.chars[guid]
        assert(c, "Osi call on unknown character " .. tostring(guid))
        return c
    end
    local function b(v)
        return v and 1 or 0
    end
    _G.Osi = {
        AddSpell = function(g, s, notify, container)
            rec("AddSpell", g, s)
            char(g).spells[s] = true
        end,
        RemoveSpell = function(g, s, container)
            rec("RemoveSpell", g, s)
            char(g).spells[s] = nil
        end,
        HasSpell = function(g, s)
            return b(char(g).spells[s])
        end,
        AddPassive = function(g, p)
            rec("AddPassive", g, p)
            char(g).passives[p] = true
        end,
        RemovePassive = function(g, p)
            rec("RemovePassive", g, p)
            char(g).passives[p] = nil
        end,
        HasPassive = function(g, p)
            return b(char(g).passives[p])
        end,
        ApplyStatus = function(g, s, duration, force, source)
            rec("ApplyStatus", g, s, duration)
            char(g).statuses[s] = true
            char(g).statusTurns = char(g).statusTurns or {}
            char(g).statusTurns[s] = (duration and duration > 0) and math.floor(duration / 6) or -1
        end,
        GetStatusTurns = function(g, s)
            return (char(g).statusTurns or {})[s] or -1
        end,
        IsEnemy = function(x, y)
            return b(char(x).party ~= char(y).party)
        end,
        IsAlly = function(x, y)
            return b(char(x).party == char(y).party)
        end,
        RemoveStatus = function(g, s)
            rec("RemoveStatus", g, s)
            char(g).statuses[s] = nil
        end,
        HasActiveStatus = function(g, s)
            return b(char(g).statuses[s])
        end,
        GetHostCharacter = function()
            return world.host and ("S_Player_" .. world.host)
        end,
        IsInCombat = function(g)
            return b(char(g).inCombat)
        end,
        IsDead = function(g)
            return b(char(g).dead)
        end,
        IsSummon = function(g)
            local c = world.chars[g]
            return b(c and c.summon)
        end,
        IsPlayer = function(g)
            local c = world.chars[g]
            return b(c and c.player)
        end,
        IsPartyMember = function(g, includeNotControllable)
            local c = world.chars[g]
            return b(c and c.party)
        end,
        GetLevel = function(g)
            return char(g).level
        end,
        GetDisplayName = function(g)
            return "h_" .. g
        end,
        GetTemplate = function(g)
            local c = world.chars[g]
            return c and c.template
        end,
        ShowNotification = function(g, text)
            world.notifications[#world.notifications + 1] = text
            world.notified[#world.notified + 1] = { char = g, text = text }
        end,
        -- multiplayer: c.user = the player a character belongs to (nil = unknown, as in single player tests)
        GetReservedUserID = function(g)
            return char(g).user
        end,
        GetEquippedItem = function(g, slot)
            return char(g).equipment[slot]
        end,
        Drop = function(item)
            rec("Drop", item)
            world.items[item].dropped = true
        end,
        Unequip = function(g, item)
            rec("Unequip", g, item)
            for slot, it in pairs(char(g).equipment) do
                if it == item then
                    char(g).equipment[slot] = nil
                end
            end
        end,
        ToInventory = function(item, g, amount, notify, clearOwner)
            rec("ToInventory", item, g)
            local inv = char(g).inventory
            inv[#inv + 1] = item
        end,
        IsStoryItem = function(item)
            return b(world.items[item] and world.items[item].story)
        end,
        AddGold = function(g, amount)
            rec("AddGold", g, amount)
            char(g).gold = char(g).gold + amount
        end,
        AddExplorationExperience = function(g, amount)
            rec("AddExplorationExperience", g, amount)
            char(g).xp = char(g).xp + amount
        end,
        IsBoss = function(g)
            return b(char(g).boss)
        end,
        ApplyDamage = function(g, amount, damageType, source)
            rec("ApplyDamage", g, amount, damageType, source)
            char(g).hp = char(g).hp - amount
        end,
        GetPosition = function(g)
            local c = char(g)
            return c.x or 0, c.y or 0, c.z or 0
        end,
        FindValidPosition = function(x, y, z, radius, obj, flag)
            return x, y, z
        end,
        CreateAt = function(template, x, y, z, temporary, playSpawn, event)
            rec("CreateAt", template, x, y, z)
            if world.failCreateAt then
                error("CreateAt failed")
            end
            world.spawnSeq = (world.spawnSeq or 0) + 1
            local guid = string.format("00000000-0000-0000-0000-%012d", world.spawnSeq)
            world.items[guid] = { name = "Spawned", template = template, story = false }
            return "Spawned_" .. guid
        end,
        TemplateAddTo = function(template, holder, count, notify)
            rec("TemplateAddTo", template, holder, count)
        end,
        GetHitpoints = function(g)
            return char(g).hp
        end,
        GetMaxHitpoints = function(g)
            return char(g).maxHp
        end,
        SetHitpoints = function(g, hp)
            rec("SetHitpoints", g, hp)
            char(g).hp = hp
        end,
        EndTurn = function(g)
            rec("EndTurn", g)
        end,
        -- summons and summoned items (Peddler traps): world.owners[guid] = the summoner's GUID
        GetOwner = function(g)
            return world.owners and world.owners[g]
        end,
        UseSpell = function(caster, spell, target)
            rec("UseSpell", caster, spell, target)
            world.usedSpells[#world.usedSpells + 1] = { caster, spell, target }
        end,
        GetRegion = function(g)
            return world.level
        end,
        -- rows carry the story name before the GUID, like the game's
        DB_Defeated = {
            Get = function(self, filter)
                local rows = {}
                for guid in pairs(world.defeated) do
                    rows[#rows + 1] = { "S_Boss_" .. guid }
                end
                return rows
            end,
        },
        DB_Players = {
            Get = function(self, filter)
                local rows = {}
                for guid, c in pairs(world.chars) do
                    if c.player and not c.summon then
                        rows[#rows + 1] = { "Name_" .. guid }
                    end
                end
                return rows
            end,
        },
    }

    function world.fire(name, ...)
        local l = world.listeners[name]
        assert(l, "no listener for Osiris event " .. name)
        assert(select("#", ...) == l.arity, string.format("%s fired with %d args, listener arity %d", name, select("#", ...), l.arity))
        l.fn(...)
    end

    function world.sessionLoaded()
        for _, h in pairs(world.events.SessionLoaded.handlers) do
            h({})
        end
    end

    function world.tick()
        while #world.ticks > 0 do
            local fns = world.ticks
            world.ticks = {}
            for _, fn in ipairs(fns) do
                fn()
            end
        end
    end

    function world.runTimers()
        local ts = world.timers
        world.timers = {}
        for _, t in ipairs(ts) do
            t.fn()
        end
    end

    function world.console(name, ...)
        local fn = world.commands[name]
        assert(fn, "no console command " .. name)
        local before = #world.prints
        fn(name, ...)
        local out = {}
        for i = before + 1, #world.prints do
            out[#out + 1] = world.prints[i]
        end
        return out
    end

    function world.bootServer()
        world.side = "server"
        assert(loadfile(Mocks.LuaDir .. "BootstrapServer.lua"))()
        world.server = _G.FFTJ
        return _G.FFTJ.Service
    end

    function world.bootClient()
        world.side = "client"
        local server = _G.FFTJ
        assert(loadfile(Mocks.LuaDir .. "BootstrapClient.lua"))()
        world.client = _G.FFTJ
        _G.FFTJ = server
        world.side = "server"
        return world.client.Board
    end

    function world.newChar(guid, fields)
        return Mocks.NewChar(world, guid, fields)
    end

    -- Items: guid -> {name, stats (stats entry name), story}; equip one with world.chars[g].equipment[slot] = guid.
    function world.newItem(guid, fields)
        local item = { name = "Item", stats = nil, story = false }
        for k, v in pairs(fields or {}) do
            item[k] = v
        end
        world.items[guid] = item
        world.loca["h_" .. guid] = item.name
        return item
    end

    return world
end

return Mocks
