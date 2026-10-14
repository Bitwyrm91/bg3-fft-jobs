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

local function findFirst(Mocks, window, prefix)
    for _, b in ipairs(buttons(Mocks, window)) do
        if string.sub(b.Label, 1, #prefix) == prefix then
            return b
        end
    end
    return nil
end

-- Job groups start closed: a tile not on show is looked for again with every group opened.
local function findButton(Mocks, window, prefix)
    local b = findFirst(Mocks, window, prefix)
    if b or not prefix:find("##tile") then
        return b
    end
    local toggle = findFirst(Mocks, window, "[+] ")
    while toggle do
        toggle.OnClick(toggle)
        toggle = findFirst(Mocks, window, "[+] ")
    end
    return findFirst(Mocks, window, prefix)
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
    -- every TIC job is built now: simulate one that isn't (the data copy belongs to this test's world)
    svc.Data.Jobs.Arithmetician.Implemented = false
    local _, View = setup()
    local v = View.Build(svc, T.SHART)
    T.eq(#v.Chars, 3)
    T.eq(v.Chars[1].Name, "Astarion", "sorted by name")
    T.eq(v.Selected, T.SHART)
    local jobs = v.Char.Jobs
    T.eq(#jobs, #svc.Data.JobOrder, "every FFT job, the ones not built yet included")
    T.eq(jobs[17].Id, "Arithmetician")
    T.falsy(jobs[17].Built)
    T.eq(jobs[17].Requirements, "White Mage Lv5, Black Mage Lv5, Time Mage Lv4, Mystic Lv4")
    T.eq(jobs[17].Missing, "White Mage Lv5 (has Lv1), Black Mage Lv5 (has Lv1), Time Mage Lv4 (has Lv1), Mystic Lv4 (has Lv1)")
    T.truthy(jobs[1].Built)
    T.eq(jobs[1].Id, "Squire")
    T.eq(jobs[5].Id, "WhiteMage")
    T.falsy(jobs[5].Unlocked)
    T.eq(jobs[5].Requirements, "Chemist Lv2")
    T.eq(jobs[2].NextAt, 200)
    T.eq(#v.Char.Abilities.Chemist, 22) -- 13 FFT + 9 custom (Mixup, Burns, Fulminate, Saturation, Caustic, Unstable, Strange Fluid, Gelatinous Goo, Quick Toss)
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
    -- every TIC job is built now: simulate one that isn't (the data copy belongs to this test's world)
    svc.Data.Jobs.Arithmetician.Implemented = false
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
    T.contains(text, "Mastered! Perk: +5 maximum hit points.")
    T.contains(text, "A job someone in the party unlocked shows for everyone")
    T.contains(text, "Learned support and movement abilities of your job work without a slot")
    T.contains(text, "Always on (your job)")
    T.falsy(findButton(Mocks, win, "Equip##equipJPBoost"), "no Equip button for an always-on ability")
    local knight = findButton(Mocks, win, "Knight Lv1##tileKnight")
    T.truthy(knight and knight.TooltipWidget, "the Knight tile has a tooltip")
    local tip = texts(Mocks, knight.TooltipWidget)
    T.contains(tip, "heavy armour, shields")
    T.contains(tip, "Constitution saving throws")
    local soon = findButton(Mocks, win, "Arithmetician (soon)##tileArithmetician")
    T.truthy(soon, "jobs not built yet are on the grid")
    soon.OnClick(soon)
    T.contains(texts(Mocks, win), "Coming in a later update. Unlock: White Mage Lv5, Black Mage Lv5, Time Mage Lv4, Mystic Lv4.")
end

function S.board_has_fft_colours_and_job_emblems(w, T, Mocks)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    T.truthy(win.StyleColors and win.StyleColors.WindowBg, "the window gets FFT's blue")
    local tile = findButton(Mocks, win, "Squire Lv1##tileSquire") -- opens the job groups
    local emblem = Mocks.FindWidgets(win, function(x)
        return x.Kind == "ImageButton" and x.Label == "##emblemSquire"
    end)[1]
    T.truthy(emblem, "the Squire tile shows its emblem")
    T.truthy(tile.StyleColors and tile.StyleColors.Button, "tiles are coloured by state")
    T.truthy(tile.SameLine, "the label sits next to the emblem")
end

function S.job_groups_are_dropdowns_that_start_closed(w, T, Mocks)
    T.boot(w)
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    T.falsy(findFirst(Mocks, win, "Squire Lv1##tileSquire"), "no tiles until a group is opened")
    T.contains(texts(Mocks, win), "Squire - ", "your job's details still show")
    local jobs = findFirst(Mocks, win, "[+] Jobs (")
    T.truthy(jobs, "the Jobs group has a closed toggle")
    T.truthy(findFirst(Mocks, win, "[+] Special jobs"), "special jobs are closed too")
    jobs.OnClick(jobs)
    T.truthy(findFirst(Mocks, win, "Squire Lv1##tileSquire"), "opening Jobs shows its tiles")
    T.falsy(findFirst(Mocks, win, "Cleric"), "special jobs stay closed")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local close = findFirst(Mocks, win, "[-] Jobs (")
    T.truthy(close, "the open state survives reopening the board")
    close.OnClick(close)
    T.falsy(findFirst(Mocks, win, "Squire Lv1##tileSquire"), "closing hides the tiles again")
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
    T.contains(text, "Squire, job level 1 - 0 JP to spend")
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
    T.contains(texts(Mocks, win), "Learned")
    T.contains(w.prints, "Job Board: Tav learned Counter Tackle", "board clicks are logged")
    local equip = findButton(Mocks, win, "Equip##equipCounterTackle")
    T.truthy(equip, "the row now offers Equip")
    equip.OnClick(equip)
    T.eq(svc.State:Get(T.TAV).Reaction, "CounterTackle")
    T.truthy(w.chars[T.TAV].passives.FFTJ_CounterTackle)
    local tile = findButton(Mocks, win, "Knight Lv1##tileKnight")
    T.truthy(tile, "Knight unlocked by 600 Squire JP")
    tile.OnClick(tile)
    T.contains(texts(Mocks, win), "Knight - Arts of War")
    local setJob = findButton(Mocks, win, "Set job##jobKnight")
    T.truthy(setJob, "the Knight tile has a Set job button")
    setJob.OnClick(setJob)
    T.eq(svc.State:Get(T.TAV).Primary, "Knight")
    T.contains(texts(Mocks, win), "Knight, job level 1")
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
    T.contains(texts(Mocks, win), "Chemist, job level 1")
    local tile = findButton(Mocks, win, "White Mage##tileWhiteMage")
    tile.OnClick(tile)
    T.contains(texts(Mocks, win), "White Mage - White Magicks")
    T.contains(texts(Mocks, win), "Locked: needs Chemist Lv2 (has Lv1).")
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

function S.arithmeticks_picker_on_the_board(w, T, Mocks)
    local svc = T.boot(w)
    local _, View = setup()
    local tav = svc.State:Get(T.TAV)
    T.eq(#View.Build(svc, T.TAV).Char.Arith.Magicks, 0)
    tav.Jobs.BlackMage = { Earned = 0, Unspent = 0, Learned = { Fire = true, Fira = true } }
    tav.Jobs.Arithmetician = { Earned = 0, Unspent = 0, Learned = { TargetLevel = true } }
    local arith = View.Build(svc, T.TAV).Char.Arith
    T.eq(arith.Magicks[1].Name, "Fire")
    T.truthy(arith.Magicks[1].Loaded, "the first one while none is chosen")
    T.truthy(svc:SetArith(T.TAV, "Fira"))
    arith = View.Build(svc, T.TAV).Char.Arith
    T.falsy(arith.Magicks[1].Loaded)
    T.truthy(arith.Magicks[2].Loaded)
    T.eq(arith.Numbers[1].Name, "Target Level")
end

-- "(N new)" left the tiles and group buttons (user, 2026-10-14: it looked clickable); the count stays in the tile
-- tooltip and on the Party page.
function S.learnable_counts_only_in_tooltips_and_party_page(w, T, Mocks)
    local svc = T.boot(w)
    local _, View = setup()
    svc:AddManualJP(T.TAV, 600, "Squire")
    local v = View.Build(svc, T.TAV)
    local squire = v.Char.Jobs[1]
    T.eq(squire.Id, "Squire")
    T.truthy(squire.NewCount > 0, "600 Squire JP buys something")
    T.eq(v.Char.Jobs[2].NewCount, 0, "no Chemist JP, nothing new")
    local tav
    for _, ch in ipairs(v.Chars) do
        if ch.Guid == T.TAV then
            tav = ch
        end
    end
    T.truthy(tav.NewCount >= squire.NewCount, "the party line counts every job")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local group = findFirst(Mocks, win, "[+] Jobs (")
    T.falsy(group.Label:find("new", 1, true), "no count on the group button: " .. group.Label)
    group.OnClick(group)
    local tile = findFirst(Mocks, win, "Squire Lv")
    T.falsy(tile.Label:find("new", 1, true), "no count on the tile: " .. tile.Label)
    T.contains(texts(Mocks, tile.TooltipWidget), squire.NewCount .. " abilities you can learn now.")
end

-- One line per tile (user, 2026-10-14): emblem, name + level, Set job / Set subclass, JP to spend. The job panel
-- below keeps the description, mastery perk and abilities; next level and equipment moved into the tile tooltip.
function S.tiles_carry_jp_and_job_buttons(w, T, Mocks)
    local svc = T.boot(w)
    local _, View = setup()
    svc:AddManualJP(T.TAV, 600, "Squire")
    local squire = View.Build(svc, T.TAV).Char.Jobs[1]
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local tile = findButton(Mocks, win, "Squire Lv" .. squire.Level .. "##tileSquire")
    T.truthy(tile, "Squire tile")
    local cell = tile.Parent
    local function inCell(c, pred)
        return Mocks.FindWidgets(c, pred)[1]
    end
    -- Tav's job: a "Your job" tag instead of the buttons, then the JP, all on the tile's line
    local tag = inCell(cell, function(x)
        return x.Kind == "Text" and x.Label == "Your job"
    end)
    T.truthy(tag and tag.SameLine, "Your job tag on the Squire tile")
    T.falsy(findFirst(Mocks, win, "Set job##jobSquire"), "no Set job on the current job")
    local jp = inCell(cell, function(x)
        return x.Kind == "Text" and x.Label == string.format("%d JP", squire.Unspent)
    end)
    T.truthy(jp and jp.SameLine, "the JP to spend sits on the tile's line")
    local tip = texts(Mocks, tile.TooltipWidget)
    T.contains(tip, string.format("Level %d at %d JP earned (%d now).", squire.Level + 1, squire.NextAt, squire.Earned))
    T.contains(tip, "Equipment while it is your job: ")
    -- the job panel: no level/JP line, no buttons, no equipment line; description and mastery perk stay
    local shown = texts(Mocks, win)
    T.falsy(shown:find("JP earned", 1, true), "next level only in the tooltip")
    T.falsy(shown:find("Equipment while it is your job", 1, true), "equipment only in the tooltip")
    T.contains(shown, "Mastery perk: ")
    T.falsy(findFirst(Mocks, win, "Make job"), "the old panel buttons are gone")
    -- another unlocked job: both buttons and its JP; a locked one: neither
    local chemist = findFirst(Mocks, win, "Set subclass##secChemist")
    T.truthy(chemist and chemist.SameLine, "Set subclass on the Chemist tile")
    T.truthy(findFirst(Mocks, win, "Set job##jobChemist"), "Set job on the Chemist tile")
    T.falsy(findFirst(Mocks, win, "Set job##jobWhiteMage"), "no buttons on a locked tile")
    chemist.OnClick(chemist)
    T.eq(svc.State:Get(T.TAV).Secondary, "Chemist")
    shown = texts(Mocks, win)
    local sub = View.Build(svc, T.TAV).Char.Secondary
    T.contains(shown, "Tav: subclass " .. sub.Skillset .. " (Chemist)", "the click's message says subclass")
    T.contains(shown, "Subclass: " .. sub.Skillset .. " (Chemist)", "the header slot says subclass")
    T.falsy(findFirst(Mocks, win, "Set subclass##secChemist"), "the subclass tile shows a tag instead")
    T.truthy(Mocks.FindWidgets(win, function(x)
        return x.Kind == "Text" and x.Label == "Your subclass"
    end)[1], "Your subclass tag")
    local setJob = findFirst(Mocks, win, "Set job##jobChemist")
    setJob.OnClick(setJob)
    T.eq(svc.State:Get(T.TAV).Primary, "Chemist")
    -- every tile button has its own id
    local seen = {}
    for _, b in ipairs(buttons(Mocks, win)) do
        T.falsy(seen[b.Label], "duplicate button id " .. b.Label)
        seen[b.Label] = true
    end
end

function S.passives_page_equips_learned_passives_of_any_job(w, T, Mocks)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 600, "Squire")
    for _, id in ipairs({ "CounterTackle", "EvasiveStance", "EquipAxes" }) do
        T.truthy(svc:Learn(T.TAV, id))
    end
    T.truthy(svc:SetPrimary(T.TAV, "Chemist"), "Squire's supports need a slot once Squire is not the job")
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local tab = findFirst(Mocks, win, "Passives##tabPassives")
    T.truthy(tab, "a Passives page button")
    tab.OnClick(tab)
    local shown = texts(Mocks, win)
    T.contains(shown, "Passives you have learned")
    T.contains(shown, "Reactions (1)")
    T.contains(shown, "Support (2)")
    T.contains(shown, "Movement (0)")
    T.contains(shown, "Evasive Stance")
    T.falsy(findFirst(Mocks, win, "[+] Jobs ("), "no job grid on this page")
    local equip = findFirst(Mocks, win, "Equip##equipEvasiveStance")
    T.truthy(equip)
    equip.OnClick(equip)
    T.eq(svc.State:Get(T.TAV).Passive1, "EvasiveStance")
    T.contains(texts(Mocks, win), "Passives you have learned", "the page stays open after equipping")
    equip = findFirst(Mocks, win, "Equip##equipCounterTackle")
    equip.OnClick(equip)
    T.eq(svc.State:Get(T.TAV).Reaction, "CounterTackle")
    T.truthy(findFirst(Mocks, win, "Unequip##unequipEvasiveStance"), "equipped rows offer Unequip")
    equip = findFirst(Mocks, win, "Equip##equipEquipAxes")
    equip.OnClick(equip)
    T.eq(svc.State:Get(T.TAV).Passive2, "EquipAxes")
    local seen = {}
    for _, b in ipairs(buttons(Mocks, win)) do
        T.falsy(seen[b.Label], "duplicate button id " .. b.Label)
        seen[b.Label] = true
    end
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    T.contains(texts(Mocks, win), "Passives you have learned", "the board reopens on the same page")
end

function S.party_page_lists_everyone_and_opens_a_character(w, T, Mocks)
    local svc = T.boot(w)
    svc:AddManualJP(T.TAV, 600, "Squire")
    T.truthy(svc:Learn(T.TAV, "CounterTackle"))
    T.truthy(svc:Equip(T.TAV, "CounterTackle"))
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local win = w.windows[1]
    local tab = findFirst(Mocks, win, "Party##tabParty")
    tab.OnClick(tab)
    local shown = texts(Mocks, win)
    T.contains(shown, "Chemist Lv1", "Shadowheart's job")
    T.contains(shown, "Counter Tackle", "Tav's reaction")
    T.contains(shown, "New = abilities")
    local sh = findFirst(Mocks, win, "Shadowheart##party")
    T.truthy(sh, "a button per character")
    sh.OnClick(sh)
    shown = texts(Mocks, win)
    T.contains(shown, "Chemist, job level 1", "Shadowheart is selected")
    T.truthy(findFirst(Mocks, win, "[+] Jobs ("), "and her Jobs page is open")
end

return S
