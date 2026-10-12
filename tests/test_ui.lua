-- Job Board: server request handler, view model, and the IMGUI window (mock widgets, clicked by the test).
local S = {}

local function setup()
    return Ext.Require("Server/NetServer.lua"), Ext.Require("Server/View.lua")
end

local function buttons(Mocks, window)
    return Mocks.FindWidgets(window, function(x)
        return x.Kind == "Button"
    end)
end

local function findButton(Mocks, window, prefix)
    for _, b in ipairs(buttons(Mocks, window)) do
        if string.sub(b.Label, 1, #prefix) == prefix then
            return b
        end
    end
    return nil
end

local function texts(Mocks, window)
    local out = {}
    for _, t in ipairs(Mocks.FindWidgets(window, function(x)
        return x.Kind == "Text" or x.Kind == "SeparatorText"
    end)) do
        out[#out + 1] = t.Label
    end
    return table.concat(out, "\n")
end

function S.request_handler_ops(w, T)
    local svc = T.boot(w)
    local NetServer = setup()
    local r = NetServer.Handle(svc, { Op = "View", Char = T.TAV })
    T.truthy(r.Ok)
    T.eq(r.View.Char.Primary.Name, "Squire")
    r = NetServer.Handle(svc, { Op = "Learn", Char = T.TAV, Ability = "Focus" })
    T.falsy(r.Ok)
    T.contains(r.Message, "needs 300 JP")
    svc:AddManualJP(T.TAV, 600, "Squire")
    r = NetServer.Handle(svc, { Op = "Learn", Char = T.TAV, Ability = "Focus" })
    T.truthy(r.Ok, r.Message)
    r = NetServer.Handle(svc, { Op = "Learn", Char = T.TAV, Ability = "CounterTackle" })
    r = NetServer.Handle(svc, { Op = "Equip", Char = T.TAV, Ability = "CounterTackle" })
    T.truthy(r.Ok)
    T.eq(r.View.Char.Reaction.Name, "Counter Tackle")
    r = NetServer.Handle(svc, { Op = "SetPrimary", Char = T.TAV, Job = "Archer" })
    T.truthy(r.Ok)
    r = NetServer.Handle(svc, { Op = "SetSecondary", Char = T.TAV, Job = "Squire" })
    T.truthy(r.Ok)
    T.eq(r.View.Char.Secondary.Skillset, "Fundaments")
    r = NetServer.Handle(svc, { Op = "SetSecondary", Char = T.TAV, Job = "" })
    T.truthy(r.Ok)
    T.eq(r.View.Char.Secondary, nil)
    r = NetServer.Handle(svc, { Op = "Unequip", Char = T.TAV, Slot = "Reaction" })
    T.truthy(r.Ok)
    r = NetServer.Handle(svc, { Op = "Explode", Char = T.TAV })
    T.falsy(r.Ok)
    r = NetServer.Handle(svc, nil)
    T.truthy(r.View, "a malformed request still gets a view")
end

function S.view_model_content(w, T)
    local svc = T.boot(w)
    local _, View = setup()
    local v = View.Build(svc, T.SHART)
    T.eq(#v.Chars, 3)
    T.eq(v.Chars[1].Name, "Astarion", "sorted by name")
    T.eq(v.Selected, T.SHART)
    local jobs = v.Char.Jobs
    T.eq(#jobs, 6)
    T.eq(jobs[1].Id, "Squire")
    T.eq(jobs[5].Id, "WhiteMage")
    T.falsy(jobs[5].Unlocked)
    T.eq(jobs[5].Requirements, "Chemist Lv2")
    T.eq(jobs[2].NextAt, 200)
    T.eq(#v.Char.Abilities.Chemist, 13)
    T.eq(v.Char.Abilities.Chemist[1].Name, "Potion")
    T.falsy(v.Char.Abilities.Chemist[1].CanLearn)
    T.falsy(v.Char.Locked.Job)
    w.chars[T.SHART].inCombat = true
    v = View.Build(svc, T.SHART)
    T.truthy(v.Char.Locked.Job and v.Char.Locked.Learn and v.Char.Locked.Slots)
    T.eq(View.Build(svc, "nobody").Selected, v.Chars[1].Guid, "unknown selection falls back to the first")
end

function S.view_marks_abilities_in_use(w, T)
    local svc = T.boot(w)
    local _, View = setup()
    svc:AddManualJP(T.SHART, 600, "Squire")
    T.truthy(svc:Learn(T.SHART, "Focus"))
    T.truthy(svc:Learn(T.SHART, "CounterTackle"))
    local function ab(id)
        for _, a in ipairs(View.Build(svc, T.SHART).Char.Abilities.Squire) do
            if a.Id == id then
                return a
            end
        end
    end
    T.falsy(ab("Focus").Active, "Squire is neither Shadowheart's job nor her secondary")
    T.falsy(ab("CounterTackle").Active, "learned but not equipped")
    T.falsy(ab("Rush").Active, "not learned")
    T.truthy(svc:SetSecondary(T.SHART, "Squire"))
    T.truthy(svc:Equip(T.SHART, "CounterTackle"))
    T.truthy(ab("Focus").Active)
    T.truthy(ab("CounterTackle").Active)
end

function S.view_shows_fell_seal_rules(w, T, Mocks)
    local svc = T.boot(w)
    local _, View = setup()
    svc:AddManualJP(T.TAV, 5000, "Squire")
    T.truthy(svc:Learn(T.TAV, "JPBoost"))
    local view = View.Build(svc, T.TAV).Char
    T.eq(view.Passive1, nil)
    T.truthy(view.PassiveFree)
    T.eq(table.concat(view.AlwaysOnTypes, ","), "Support,Movement")
    local jpBoost
    for _, a in ipairs(view.Abilities.Squire) do
        if a.Id == "JPBoost" then
            jpBoost = a
        end
    end
    T.truthy(jpBoost.AlwaysOn and jpBoost.Active, "the main job's support is on without a slot")
    for _, aid in ipairs(svc.Data.AbilitiesByJob.Squire) do
        svc:Learn(T.TAV, aid)
    end
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local text = texts(Mocks, win)
    T.contains(text, "Mastered: +5 maximum hit points.")
    T.contains(text, "A job someone in the party unlocked shows for everyone")
    T.contains(text, "Learned support and movement abilities of your job work without a slot")
    T.contains(text, "Learned, always on while this is your job")
    T.falsy(findButton(Mocks, win, "Equip##equipJPBoost"), "no Equip button for an always-on ability")
    local knight = Mocks.FindWidgets(win, function(x)
        return x.Kind == "Text" and x.Label == "Knight" and x.TooltipWidget ~= nil
    end)[1]
    T.truthy(knight, "the Knight row has a tooltip")
    T.contains(knight.TooltipWidget.Children[1].Label, "heavy armour, shields")
    T.contains(knight.TooltipWidget.Children[1].Label, "Constitution saving throws")
end

function S.tooltips_start_clear_of_the_cursor(w, T, Mocks)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local names = Mocks.FindWidgets(w.windows[1], function(x)
        return x.Kind == "Text" and x.Label == "Focus" and x.TooltipWidget ~= nil
    end)
    T.truthy(names[1], "the Focus row has a tooltip")
    local tip = names[1].TooltipWidget.Children[1].Label
    T.truthy(tip:match("^      +%S"), "indented past BG3's large cursor: [" .. tip .. "]")
    T.contains(tip, "+1 to attack rolls")
end

function S.job_board_spell_opens_window_without_jp(w, T, Mocks)
    local svc = T.boot(w)
    T.startCombat(w, "c1", { T.TAV })
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    T.eq(#w.windows, 1)
    local win = w.windows[1]
    T.truthy(win.Open)
    T.truthy(win.Closeable)
    local text = texts(Mocks, win)
    T.contains(text, "Job: Squire, level 1")
    T.contains(text, "In combat")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Earned, 0, "opening the board earns no JP")
end

function S.clicking_learn_and_equip(w, T, Mocks)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local learn = findButton(Mocks, win, "Learn##learnCounterTackle")
    T.truthy(learn, "Learn button for Counter Tackle")
    learn.OnClick(learn)
    T.truthy(svc.State:Get(T.TAV).Jobs.Squire.Learned.CounterTackle)
    T.contains(texts(Mocks, win), "Tav learned Counter Tackle")
    T.contains(texts(Mocks, win), "Learned: equip it to use it")
    T.contains(w.prints, "Job Board: Tav learned Counter Tackle", "board clicks are logged")
    local equip = findButton(Mocks, win, "Equip##equipCounterTackle")
    T.truthy(equip, "the row now offers Equip")
    equip.OnClick(equip)
    T.eq(svc.State:Get(T.TAV).Reaction, "CounterTackle")
    T.truthy(w.chars[T.TAV].passives.FFTJ_CounterTackle)
    local setJob = findButton(Mocks, win, "Set job##jobKnight")
    T.truthy(setJob, "Knight unlocked by 600 Squire JP")
    setJob.OnClick(setJob)
    T.eq(svc.State:Get(T.TAV).Primary, "Knight")
    T.contains(texts(Mocks, win), "Abilities: Knight")
end

function S.switching_character_and_job_tabs(w, T, Mocks)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local sh
    for _, b in ipairs(buttons(Mocks, win)) do
        if b.Label:find("^Shadowheart") then
            sh = b
        end
    end
    T.truthy(sh)
    sh.OnClick(sh)
    T.contains(texts(Mocks, win), "Job: Chemist")
    local abil = findButton(Mocks, win, "Abilities##abilWhiteMage")
    abil.OnClick(abil)
    T.contains(texts(Mocks, win), "Abilities: White Mage")
end

function S.button_ids_are_unique(w, T, Mocks)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 3000, "Squire")
    svc:AddManualJP(T.TAV, 3000, "Chemist")
    svc:SetSecondary(T.TAV, "Chemist")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local seen = {}
    for _, b in ipairs(buttons(Mocks, w.windows[1])) do
        T.falsy(seen[b.Label], "duplicate button id " .. b.Label)
        seen[b.Label] = true
    end
    T.truthy(next(seen))
end

function S.rerender_destroys_old_widgets(w, T, Mocks)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    T.eq(#w.windows, 1, "one window, reused")
    T.eq(#win.Children, 1, "only the current content group remains")
end

return S
