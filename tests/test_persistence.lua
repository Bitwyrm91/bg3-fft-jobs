-- Save/load: the "State" mod variable round trip (the mock serializes Vars to JSON like the SE does).
local S = {}

local function snapshot(svc, guid)
    local c = svc.State:Get(guid)
    local jobs = {}
    for id, js in pairs(c.Jobs) do
        local learned = {}
        for a in pairs(js.Learned) do
            learned[#learned + 1] = a
        end
        table.sort(learned)
        jobs[#jobs + 1] = string.format("%s:%s/%s/%s", id, js.Earned, js.Unspent, table.concat(learned, "+"))
    end
    table.sort(jobs)
    local unlocked = {}
    for id in pairs(c.Unlocked) do
        unlocked[#unlocked + 1] = id
    end
    table.sort(unlocked)
    local granted = {}
    for kind, set in pairs(c.Granted) do
        for id in pairs(set) do
            granted[#granted + 1] = kind .. ":" .. id
        end
    end
    table.sort(granted)
    return table.concat({
        c.Primary, tostring(c.Secondary), tostring(c.Reaction), tostring(c.Support), tostring(c.Movement),
        table.concat(jobs, ","), table.concat(unlocked, ","), table.concat(granted, ","), tostring(c.LastXP),
        tostring(c.Stats.Actions), tostring(c.Stats.JP.Action), tostring(c.Stats.JP.Manual),
    }, " | ")
end

function S.round_trip_save_and_load(w, T, Mocks)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 900, "Squire")
    svc:AddManualJP(T.TAV, 300, "Chemist")
    T.truthy(svc:Learn(T.TAV, "Focus"))
    T.truthy(svc:Learn(T.TAV, "CounterTackle"))
    T.truthy(svc:Equip(T.TAV, "CounterTackle"))
    T.truthy(svc:Learn(T.TAV, "Potion"))
    T.truthy(svc:SetPrimary(T.TAV, "Knight"))
    T.truthy(svc:SetSecondary(T.TAV, "Chemist"))
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.endCombat(w, "c1", { T.TAV })
    w.chars[T.TAV].xp = 1234
    w.runTimers()
    w.tick()
    local before = snapshot(svc, T.TAV)
    local saved = w.modVars.State
    T.truthy(saved and #saved > 100, "state written to the mod variable")

    -- a new Lua session loading that save
    local w2 = Mocks.Install()
    T.party(w2)
    w2.chars[T.TAV].xp = 1234
    for kind, field in pairs({ spells = "spells", passives = "passives" }) do
        for id in pairs(w.chars[T.TAV][field]) do
            w2.chars[T.TAV][kind][id] = true
        end
    end
    w2.modVars.State = saved
    local svc2 = T.boot(w2, { noParty = true })
    T.eq(snapshot(svc2, T.TAV), before)
    T.eq(svc2.State:Get(T.TAV).Name, "Tav")
    T.eq(#svc2.State:Guids(), 3)
end

function S.writes_are_coalesced_once_per_tick(w, T)
    local svc = T.boot(w)
    local writes = 0
    local storage = svc.State.Storage
    local original = storage.Write
    storage.Write = function(root)
        writes = writes + 1
        original(root)
    end
    svc:AddManualJP(T.TAV, 10, "Squire")
    svc:AddManualJP(T.TAV, 10, "Squire")
    svc:AddManualJP(T.SHART, 10, "Chemist")
    T.eq(writes, 0, "nothing written until the tick ends")
    w.tick()
    T.eq(writes, 1)
end

function S.empty_state_never_overwrites_a_save(w, T, Mocks)
    T.party(w)
    w.modVars.State = Mocks.Json.encode({
        Schema = 1, Meta = { Disabled = false },
        Chars = { [T.TAV] = { Name = "Tav", Primary = "Squire", Unlocked = { Squire = true, Chemist = true },
            Jobs = { Squire = { Earned = 500, Unspent = 500, Frac = 0, Learned = {} } } } },
    })
    local saved = w.modVars.State
    w.files["FFTJobs/config.json"] = T.pinnedConfigJson(Mocks.Json)
    local svc = w.bootServer()
    w.chars[T.TAV].inCombat = true
    T.cast(w, T.TAV, "Target_MainHandAttack")
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    w.tick()
    T.eq(w.modVars.State, saved, "untouched before SessionLoaded")
    w.sessionLoaded()
    w.tick()
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 500)
    T.truthy(svc.State:Get(T.TAV).Unlocked.Knight, "unlocks are re-checked on load")
end

function S.old_saves_with_missing_fields_still_work(w, T, Mocks)
    T.party(w)
    w.modVars.State = Mocks.Json.encode({
        Schema = 1,
        Chars = { [T.TAV] = { Name = "Tav", Primary = "Squire", Unlocked = { Squire = true },
            Jobs = { Squire = { Earned = 10 } } } },
    })
    local svc = T.boot(w, { noParty = true })
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 23)
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Unspent, 13)
end

-- 1.0.0.66: the Archer became the Fell Seal Ranger; a save with Aim skills learned gets their JP back once.
function S.old_archer_skills_are_refunded_on_load(w, T, Mocks)
    T.party(w)
    w.modVars.State = Mocks.Json.encode({
        Schema = 1, Meta = { Disabled = false },
        Chars = { [T.TAV] = { Name = "Tav", Primary = "Archer", Passive1 = "EquipCrossbows",
            Unlocked = { Squire = true, Chemist = true, Archer = true },
            Jobs = { Squire = { Earned = 300, Unspent = 0, Frac = 0, Learned = {} },
                Archer = { Earned = 2000, Unspent = 40, Frac = 0,
                    Learned = { Aim1 = true, Aim2 = true, EquipCrossbows = true } } } } },
    })
    local svc = T.boot(w, { noParty = true })
    local char = svc.State:Get(T.TAV)
    T.eq(char.Jobs.Archer.Unspent, 40 + 100 + 150, "Aim +1 and Aim +2 refunded")
    T.eq(char.Jobs.Archer.Earned, 2000, "job level kept")
    T.truthy(char.Jobs.Archer.Learned.EquipBows, "Equip Crossbows became Equip Bows")
    T.truthy(char.Jobs.Archer.Learned.RootingShot, "the Ranger's starting skill")
    T.eq(char.Passive1, "EquipBows", "still slotted")
    T.contains(w.notifications, "Tav: 250 JP back in Ranger for skills it no longer has; now knows Equip Bows.")
    local n = #w.notifications
    w.fire("LevelGameplayStarted", "WLD_Main_A", 0)
    w.tick()
    for i = n + 1, #w.notifications do
        T.falsy(string.find(w.notifications[i], "JP back", 1, true), "told once")
    end
end

function S.mod_variable_registered_on_both_sides(w, T)
    T.boot(w)
    T.eq(#w.registeredVars, 2)
    local a, b = w.registeredVars[1], w.registeredVars[2]
    T.eq(a.side, "server")
    T.eq(b.side, "client")
    T.eq(a.name, "State")
    T.eq(a.uuid, "3db7be3e-9387-4678-b172-044acc7ff0c2")
    for k, v in pairs(a.opts) do
        T.eq(b.opts[k], v, "same option " .. k .. " on both sides")
    end
    T.eq(a.opts.Persistent, true)
end

return S
