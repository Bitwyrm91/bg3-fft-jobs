-- The Job Board window (SE IMGUI, client side). It only displays the view the server sends and forwards
-- button clicks as requests; all rules run on the server.
-- Layout (the user's choice, 2026-10-12): the character, a grid of every FFT job as coloured tiles, and the
-- selected job's details and abilities below. Widget names from the SE's IMGUI objects (AddTable, AddIcon,
-- AddProgressBar, AddCollapsingHeader, SetStyleColor, TextWrapPos); styling calls are protected, so an SE
-- without one of them still shows the board.
local Util = Ext.Require("Shared/Util.lua")

local JobBoard = {}
JobBoard.__index = JobBoard

JobBoard.RequestChannel = "FFTJ_Board"
JobBoard.OpenChannel = "FFTJ_Open"

-- Fell Seal slots: one reaction slot, two free passive slots (support or movement abilities).
local SLOTS = { "Reaction", "Passive1", "Passive2" }
local SLOT_LABELS = { Reaction = "Reaction", Passive1 = "Passive 1", Passive2 = "Passive 2" }
local GRID_COLUMNS = 4
local WRAP = 760 -- px: long texts wrap here instead of running off the window
local TIP_WRAP = 460

-- Colours (RGBA 0..1). Tiles: mastered gold, the job blue, unlocked green, locked grey, not built yet dark.
local TILE = {
    Mastered = { 0.62, 0.47, 0.12, 1 },
    Job = { 0.20, 0.38, 0.70, 1 },
    Unlocked = { 0.18, 0.42, 0.22, 1 },
    Locked = { 0.30, 0.30, 0.30, 1 },
    Soon = { 0.13, 0.13, 0.13, 1 },
}
local TEXT = {
    Good = { 0.55, 0.88, 0.55, 1 },
    Note = { 0.95, 0.82, 0.45, 1 },
    Dim = { 0.62, 0.62, 0.62, 1 },
    Bad = { 0.95, 0.55, 0.50, 1 },
}

function JobBoard.New(imgui, request, log)
    local self = setmetatable({}, JobBoard)
    self.IMGUI = imgui
    self.Request = request
    self.Log = log
    self.Window = nil
    self.Content = nil
    self.View = nil
    self.SelectedJob = nil
    self.Message = nil
    return self
end

function JobBoard:EnsureWindow()
    if not self.Window then
        self.Window = self.IMGUI.NewWindow("FFT Job Board")
        self.Window.Closeable = true
        pcall(function()
            self.Window:SetSize({ 980, 800 }, "FirstUseEver")
        end)
    end
    return self.Window
end

function JobBoard:Open(view)
    self:EnsureWindow().Open = true
    self.Message = nil
    if view and self.View and view.Selected ~= self.View.Selected then
        self.SelectedJob = nil
    end
    self:Render(view)
end

-- Sends {Op, Char, ...} to the server; the reply carries the new view.
function JobBoard:Send(op, fields)
    local req = { Op = op, Char = self.View and self.View.Selected }
    for k, v in pairs(fields or {}) do
        req[k] = v
    end
    self.Request:RequestToServer(req, function(reply)
        self.Log.Safe("Job Board reply", function()
            if type(reply) ~= "table" then
                return
            end
            if reply.Message then
                self.Message = { Text = reply.Message, Ok = reply.Ok ~= false }
            end
            self:Render(reply.View)
        end)
    end)
end

local function style(widget, kind, color)
    pcall(function()
        widget:SetStyleColor(kind, color)
    end)
end

local function wrap(widget, px)
    pcall(function()
        widget.TextWrapPos = px
    end)
    return widget
end

local function text(parent, label, color, wrapAt)
    local t = parent:AddText(label)
    if color then
        style(t, "Text", color)
    end
    if wrapAt then
        wrap(t, wrapAt)
    end
    return t
end

local function button(parent, label, id, sameLine, onClick)
    local b = parent:AddButton(label .. "##" .. id)
    b.SameLine = sameLine and true or false
    b.OnClick = function()
        onClick()
    end
    return b
end

local function tint(b, color)
    style(b, "Button", color)
    style(b, "ButtonHovered", { color[1] + 0.12, color[2] + 0.12, color[3] + 0.12, 1 })
    style(b, "ButtonActive", { color[1] + 0.2, color[2] + 0.2, color[3] + 0.2, 1 })
end

-- IMGUI opens a tooltip just right of the mouse position, sized for a small cursor; BG3's large cursor then covers
-- the first word (user's screenshot, 2026-10-12). The indent starts the text clear of the cursor.
local TOOLTIP_INDENT = string.rep(" ", 7)

local function addTooltip(widget, lines)
    pcall(function()
        local tip = widget:Tooltip()
        for _, line in ipairs(type(lines) == "table" and lines or { lines }) do
            wrap(tip:AddText(TOOLTIP_INDENT .. line), TIP_WRAP)
        end
    end)
end

local function icon(parent, name, sameLine)
    if not name then
        return nil
    end
    local ok, w = pcall(function()
        return parent:AddIcon(name, { 32, 32 })
    end)
    if ok and w and sameLine then
        w.SameLine = true
    end
    return ok and w or nil
end

-- "Monk Lv8 *": name, level, a star when mastered.
local function tileLabel(j)
    if not j.Built then
        return j.Name .. " (soon)"
    end
    local label = j.Name .. (j.Unlocked and (" Lv" .. j.Level) or "")
    if j.Mastered then
        label = label .. " *"
    end
    return label
end

local function tileColor(j)
    if not j.Built then
        return TILE.Soon
    elseif j.IsPrimary then
        return TILE.Job
    elseif j.Mastered then
        return TILE.Mastered
    elseif j.Unlocked then
        return TILE.Unlocked
    end
    return TILE.Locked
end

local function tileTooltip(j)
    local lines = { j.Name .. (j.Skillset ~= "" and (" - " .. j.Skillset) or "") }
    if not j.Built then
        lines[#lines + 1] = "Coming in a later update. Unlock: " .. j.Requirements .. "."
        return lines
    end
    if j.IsPrimary then
        lines[#lines + 1] = "Your job."
    elseif j.IsSecondary then
        lines[#lines + 1] = "Your secondary skill set."
    end
    if not j.Unlocked then
        lines[#lines + 1] = (j.PartyUnlocked and "Unlocked by the party; you need " or "Locked: needs ")
            .. (j.Missing or j.Requirements) .. "."
    else
        lines[#lines + 1] = string.format("Level %d, %s JP to spend, %d/%d abilities learned.", j.Level,
            Util.Num(j.Unspent), j.LearnedCount, j.Total)
    end
    if j.Equip then
        lines[#lines + 1] = "Equipment while it is your job: " .. j.Equip .. "."
    end
    if j.Mastery then
        lines[#lines + 1] = (j.MasteryPerk and "Mastery perk (earned): " or "Mastery perk: ") .. j.Mastery
    end
    return lines
end

-- Status of an ability row: short text and its colour.
local function abilityStatus(a)
    if a.Equipped then
        return "In " .. string.lower(a.SlotLabel) .. (a.AlwaysOn and " (also always on)" or ""), TEXT.Good
    elseif a.AlwaysOn then
        return "Always on (your job)", TEXT.Good
    elseif a.Learned and a.Type == "Action" then
        if a.Active then
            return "In your spells", TEXT.Good
        end
        return "Learned: make the job your job or secondary", TEXT.Note
    elseif a.Learned then
        return "Learned: equip it", TEXT.Note
    elseif a.CanLearn then
        return "Can learn", nil
    end
    return a.ShortReason or a.Reason or "-", TEXT.Dim
end

function JobBoard:RenderHeader(root, view, c)
    for i, ch in ipairs(view.Chars or {}) do
        local b = button(root, ch.Name .. " (" .. ch.Job .. ")", "char" .. i, i > 1, function()
            self.SelectedJob = nil
            self.Message = nil
            self:Send("View", { Char = ch.Guid })
        end)
        if ch.Guid == view.Selected then
            tint(b, TILE.Job)
        end
    end
    if view.Disabled then
        text(root, "The job system is paused (type !fft_enable in the SE console).", TEXT.Bad)
    end
    if self.Message then
        text(root, self.Message.Text, self.Message.Ok and TEXT.Good or TEXT.Bad, WRAP)
    end
    if not c then
        return
    end
    root:AddSeparatorText(c.Name)
    text(root, string.format("%s, job level %d - %s JP to spend%s", c.Primary.Name, c.Primary.Level,
        Util.Num(c.Primary.Unspent), c.JPBoost and " (JP Boost on)" or ""))
    -- slots, each with a small clear button
    local first = true
    local function slot(label, value, id, onClear)
        local t = text(root, label .. ": " .. (value or "-"), value and nil or TEXT.Dim)
        t.SameLine = not first
        first = false
        if value then
            addTooltip(button(root, "x", id, true, onClear), "Clear this slot")
        end
    end
    slot("Secondary", c.Secondary and (c.Secondary.Skillset .. " (" .. c.Secondary.Name .. ")") or nil, "clearsec",
        function()
            self:Send("SetSecondary", { Job = "" })
        end)
    for _, s in ipairs(SLOTS) do
        slot(SLOT_LABELS[s], c[s] and c[s].Name or nil, "unequip" .. s, function()
            self:Send("Unequip", { Slot = s })
        end)
    end
    if c.InCombat then
        text(root, "In combat: job, ability and slot changes wait until the fight ends.", TEXT.Note)
    end
    local ok, help = pcall(function()
        return root:AddCollapsingHeader("How jobs work")
    end)
    if not ok or not help then
        help = root
    end
    text(help, "Pick a job tile to see its abilities. Learn abilities with that job's JP. Actions work while their job "
        .. "is your job or your secondary skill set. A reaction goes in the reaction slot; support and movement "
        .. "abilities go in either passive slot.", nil, WRAP)
    if c.AlwaysOnTypes and #c.AlwaysOnTypes > 0 then
        text(help, "Learned " .. string.lower(table.concat(c.AlwaysOnTypes, " and ")) .. " abilities of your job work "
            .. "without a slot, so the slots stay free for other jobs' abilities.", nil, WRAP)
    end
    text(help, "A job someone in the party unlocked shows for everyone, but each character needs its own job levels "
        .. "to learn from it or take it. Mastering a job (every ability learned) gives a small permanent perk.", nil,
        WRAP)
    text(help, "Tiles: blue = your job, gold = mastered (*), green = unlocked, grey = locked, dark = coming in a later "
        .. "update. Hover a tile or an ability for details.", nil, WRAP)
end

function JobBoard:RenderGrid(root, c)
    root:AddSeparatorText("Jobs")
    local grid = root:AddTable("FFTJ_Grid", GRID_COLUMNS)
    local row
    for i, j in ipairs(c.Jobs) do
        if (i - 1) % GRID_COLUMNS == 0 then
            row = grid:AddRow()
        end
        local cell = row:AddCell()
        local b = button(cell, tileLabel(j), "tile" .. j.Id, false, function()
            self.SelectedJob = j.Id
            self:Render(self.View)
        end)
        tint(b, tileColor(j))
        if j.Id == self.SelectedJob then
            style(b, "Text", { 1, 0.92, 0.55, 1 })
        end
        addTooltip(b, tileTooltip(j))
    end
end

function JobBoard:RenderJob(root, c, j)
    root:AddSeparatorText(j.Name .. (j.Skillset ~= "" and (" - " .. j.Skillset) or ""))
    if j.Description and j.Description ~= "" then
        text(root, j.Description, TEXT.Dim, WRAP)
    end
    if not j.Built then
        text(root, "Coming in a later update. Unlock: " .. j.Requirements .. ".", TEXT.Dim, WRAP)
        return
    end
    if not j.Unlocked then
        text(root, (j.PartyUnlocked and "Unlocked by the party; you need " or "Locked: needs ")
            .. (j.Missing or j.Requirements) .. ".", TEXT.Note, WRAP)
    else
        local status = string.format("Level %d - %s JP to spend", j.Level, Util.Num(j.Unspent))
        if j.IsPrimary then
            status = status .. " - your job"
        elseif j.IsSecondary then
            status = status .. " - your secondary"
        end
        text(root, status)
        pcall(function()
            local bar = root:AddProgressBar()
            bar.Value = j.Progress or 1
            bar.Overlay = j.NextAt and string.format("Level %d at %s JP earned (%s now)", j.Level + 1,
                Util.Num(j.NextAt), Util.Num(j.Earned)) or "Top level"
            bar.Size = { 520, 0 }
        end)
        if not j.IsPrimary then
            button(root, "Make job", "job" .. j.Id, false, function()
                self:Send("SetPrimary", { Job = j.Id })
            end)
            if not j.IsSecondary then
                button(root, "Make secondary", "sec" .. j.Id, true, function()
                    self:Send("SetSecondary", { Job = j.Id })
                end)
            end
        end
    end
    if j.Equip then
        text(root, "Equipment while it is your job: " .. j.Equip .. ".", nil, WRAP)
    end
    if j.Mastery then
        text(root, j.Mastered and ("Mastered! Perk: " .. j.Mastery) or ("Mastery perk: " .. j.Mastery),
            j.Mastered and TEXT.Good or TEXT.Dim, WRAP)
    end
    local abilities = root:AddTable("FFTJ_Abilities", 6)
    abilities.ShowHeader = true
    for _, h in ipairs({ "", "Ability", "Type", "JP", "Status", "" }) do
        abilities:AddColumn(h)
    end
    for _, a in ipairs((c.Abilities or {})[j.Id] or {}) do
        local row = abilities:AddRow()
        icon(row:AddCell(), a.Icon)
        local tip = { a.Description }
        if a.Fft then
            tip[#tip + 1] = "FFT: " .. a.Fft
        end
        local nameText = row:AddCell():AddText(a.Name)
        addTooltip(nameText, tip)
        row:AddCell():AddText(a.Type)
        row:AddCell():AddText(Util.Num(a.Cost))
        local status, color = abilityStatus(a)
        local statusText = text(row:AddCell(), status, color)
        addTooltip(statusText, a.Reason and { a.Reason } or tip)
        local cell = row:AddCell()
        if not a.Learned and a.CanLearn then
            button(cell, "Learn", "learn" .. a.Id, false, function()
                self:Send("Learn", { Ability = a.Id })
            end)
        elseif a.Learned and a.Type ~= "Action" and not a.Equipped and not a.AlwaysOn then
            if a.Type == "Reaction" or c.PassiveFree then
                button(cell, "Equip", "equip" .. a.Id, false, function()
                    self:Send("Equip", { Ability = a.Id })
                end)
            else
                -- both passive slots are full: pick the one to replace
                for n = 1, 2 do
                    button(cell, "Replace " .. n, "equip" .. n .. a.Id, n > 1, function()
                        self:Send("Equip", { Ability = a.Id, Slot = tostring(n) })
                    end)
                end
            end
        elseif a.Equipped then
            button(cell, "Unequip", "unequip" .. a.Id, false, function()
                self:Send("Unequip", { Slot = a.Slot })
            end)
        end
    end
end

function JobBoard:Render(view)
    if not view then
        return
    end
    self.View = view
    local window = self:EnsureWindow()
    if self.Content then
        self.Content:Destroy()
        self.Content = nil
    end
    local root = window:AddGroup("FFTJ_Content")
    self.Content = root
    local c = view.Char
    self:RenderHeader(root, view, c)
    if not c then
        root:AddText(view.Message or "No party member is tracked yet.")
        return
    end
    self:RenderGrid(root, c)
    local jobId = self.SelectedJob or c.Primary.Id
    for _, j in ipairs(c.Jobs) do
        if j.Id == jobId then
            self:RenderJob(root, c, j)
        end
    end
    text(root, "Preset " .. tostring(view.Preset) .. ", JP multiplier x" .. Util.Num(view.Multiplier or 1) .. ".",
        TEXT.Dim)
end

-- Creates the channels (same names as the server) and opens the window when the server says so.
function JobBoard.Setup(modUuid, log)
    if not (Ext.Net and Ext.Net.CreateChannel) then
        log.Warn("Ext.Net.CreateChannel is missing (Script Extender too old?): no Job Board window")
        return nil
    end
    if not Ext.IMGUI then
        log.Warn("Ext.IMGUI is missing: no Job Board window; use the !fft_ console commands")
        return nil
    end
    local request = Ext.Net.CreateChannel(modUuid, JobBoard.RequestChannel)
    local open = Ext.Net.CreateChannel(modUuid, JobBoard.OpenChannel)
    local board = JobBoard.New(Ext.IMGUI, request, log)
    open:SetHandler(function(data)
        log.Safe("Job Board open", function()
            board:Open(type(data) == "table" and data.View or nil)
        end)
    end)
    return board
end

return JobBoard
