-- The Job Board window (SE IMGUI, client side). It only displays the view the server sends and forwards
-- button clicks as requests; all rules run on the server.
local Util = Ext.Require("Shared/Util.lua")

local JobBoard = {}
JobBoard.__index = JobBoard

JobBoard.RequestChannel = "FFTJ_Board"
JobBoard.OpenChannel = "FFTJ_Open"

-- Fell Seal slots: one reaction slot, two free passive slots (support or movement abilities).
local SLOTS = { "Reaction", "Passive1", "Passive2" }
local SLOT_LABELS = { Reaction = "Reaction", Passive1 = "Passive 1", Passive2 = "Passive 2" }

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
                self.Message = (reply.Ok == false and "Not done: " or "") .. reply.Message
            end
            self:Render(reply.View)
        end)
    end)
end

local function button(parent, label, id, sameLine, onClick)
    local b = parent:AddButton(label .. "##" .. id)
    b.SameLine = sameLine and true or false
    b.OnClick = function()
        onClick()
    end
    return b
end

-- IMGUI opens a tooltip just right of the mouse position, sized for a small cursor; BG3's large cursor then covers
-- the first word (user's screenshot, 2026-10-12). The indent starts the text clear of the cursor.
local TOOLTIP_INDENT = string.rep(" ", 7)

local function addTooltip(widget, text)
    pcall(function()
        widget:Tooltip():AddText(TOOLTIP_INDENT .. text)
    end)
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

    root:AddText("Party:")
    for i, c in ipairs(view.Chars or {}) do
        local label = c.Name .. " (" .. c.Job .. ")"
        if c.Guid == view.Selected then
            label = "> " .. label
        end
        button(root, label, "char" .. i, true, function()
            self.SelectedJob = nil
            self.Message = nil
            self:Send("View", { Char = c.Guid })
        end)
    end
    if view.Disabled then
        root:AddText("The job system is paused (type !fft_enable in the SE console).")
    end
    if self.Message then
        root:AddText(self.Message)
    end
    local c = view.Char
    if not c then
        root:AddText(view.Message or "No party member is tracked yet.")
        return
    end

    root:AddSeparatorText(c.Name)
    root:AddText(string.format("Job: %s, level %d. %s JP to spend (%s earned).%s", c.Primary.Name, c.Primary.Level,
        Util.Num(c.Primary.Unspent), Util.Num(c.Primary.Earned), c.JPBoost and " JP Boost on." or ""))
    local slotParts = { "Secondary: " .. (c.Secondary and (c.Secondary.Skillset .. " (" .. c.Secondary.Name .. ")") or "-") }
    for _, slot in ipairs(SLOTS) do
        slotParts[#slotParts + 1] = SLOT_LABELS[slot] .. ": " .. (c[slot] and c[slot].Name or "-")
    end
    root:AddText(table.concat(slotParts, "   "))
    if c.InCombat then
        root:AddText("In combat: job, ability and slot changes wait until the fight ends.")
    end
    if c.Secondary then
        button(root, "Clear secondary", "clearsec", false, function()
            self:Send("SetSecondary", { Job = "" })
        end)
    end
    for i, slot in ipairs(SLOTS) do
        if c[slot] then
            button(root, "Unequip " .. string.lower(SLOT_LABELS[slot]), "unequip" .. slot, i > 1 or c.Secondary ~= nil, function()
                self:Send("Unequip", { Slot = slot })
            end)
        end
    end

    root:AddSeparatorText("Jobs")
    root:AddText("A job someone in the party unlocked shows for everyone, but each character needs its own job levels "
        .. "to learn from it or take it. Hover a job for its equipment and mastery perk.")
    local jobs = root:AddTable("FFTJ_Jobs", 5)
    jobs.ShowHeader = true
    for _, h in ipairs({ "Job", "Level", "JP (spend / earned)", "Status", "" }) do
        jobs:AddColumn(h)
    end
    for _, j in ipairs(c.Jobs) do
        local row = jobs:AddRow()
        local name = j.Name
        if j.IsPrimary then
            name = name .. " (job)"
        elseif j.IsSecondary then
            name = name .. " (secondary)"
        end
        local nameText = row:AddCell():AddText(name)
        local info = {}
        if j.Equip then
            info[#info + 1] = "Equipment while it is your job: " .. j.Equip .. "."
        end
        if j.Mastery then
            info[#info + 1] = "Mastery perk (all abilities learned, kept for good): " .. j.Mastery
        end
        if #info > 0 then
            addTooltip(nameText, table.concat(info, "\n" .. TOOLTIP_INDENT))
        end
        row:AddCell():AddText(j.Unlocked and tostring(j.Level) or "-")
        row:AddCell():AddText(Util.Num(j.Unspent) .. " / " .. Util.Num(j.Earned)
            .. (j.NextAt and ("  (Lv" .. (j.Level + 1) .. " at " .. Util.Num(j.NextAt) .. ")") or ""))
        local status
        if not j.Unlocked and j.PartyUnlocked then
            status = "Unlocked by the party; needs " .. (j.Missing or j.Requirements)
        elseif not j.Unlocked then
            status = "Locked: needs " .. (j.Missing or j.Requirements)
        elseif j.Mastered then
            status = j.MasteryPerk and ("Mastered: " .. j.Mastery) or "Mastered"
        else
            status = string.format("%d/%d learned", j.LearnedCount, j.Total)
        end
        row:AddCell():AddText(status)
        local cell = row:AddCell()
        button(cell, "Abilities", "abil" .. j.Id, false, function()
            self.SelectedJob = j.Id
            self:Render(self.View)
        end)
        if j.Unlocked and not j.IsPrimary then
            button(cell, "Set job", "job" .. j.Id, true, function()
                self:Send("SetPrimary", { Job = j.Id })
            end)
            if not j.IsSecondary then
                button(cell, "Secondary", "sec" .. j.Id, true, function()
                    self:Send("SetSecondary", { Job = j.Id })
                end)
            end
        end
    end

    local jobId = self.SelectedJob or c.Primary.Id
    local jobName = jobId
    for _, j in ipairs(c.Jobs) do
        if j.Id == jobId then
            jobName = j.Name .. " - " .. j.Skillset .. " (" .. Util.Num(j.Unspent) .. " JP to spend)"
        end
    end
    root:AddSeparatorText("Abilities: " .. jobName)
    local help = "Learned actions are usable while their job is the job or the secondary. A reaction goes in the "
        .. "reaction slot; support and movement abilities go in either of the two passive slots (most are passives, "
        .. "not hotbar spells)."
    if c.AlwaysOnTypes and #c.AlwaysOnTypes > 0 then
        help = help .. " Learned " .. string.lower(table.concat(c.AlwaysOnTypes, " and ")) .. " abilities of your "
            .. "job work without a slot, so the slots stay free for other jobs' abilities."
    end
    root:AddText(help)
    local abilities = root:AddTable("FFTJ_Abilities", 5)
    abilities.ShowHeader = true
    for _, h in ipairs({ "Ability", "Type", "JP", "Status", "" }) do
        abilities:AddColumn(h)
    end
    for _, a in ipairs((c.Abilities or {})[jobId] or {}) do
        local row = abilities:AddRow()
        local nameText = row:AddCell():AddText(a.Name)
        addTooltip(nameText, a.Description)
        row:AddCell():AddText(a.Type)
        row:AddCell():AddText(Util.Num(a.Cost))
        local status
        if a.Equipped and a.AlwaysOn then
            status = "Learned, in " .. a.SlotLabel .. " (works without the slot while this is your job)"
        elseif a.Equipped then
            status = "Learned, in " .. a.SlotLabel
        elseif a.AlwaysOn then
            status = "Learned, always on while this is your job"
        elseif a.Learned and a.Type == "Action" then
            status = a.Active and "Learned, in the spells" or "Learned: make this job the job or secondary to use it"
        elseif a.Learned then
            status = "Learned: equip it to use it"
        elseif a.CanLearn then
            status = "Can learn"
        else
            status = a.Reason or "-"
        end
        local statusText = row:AddCell():AddText(status)
        addTooltip(statusText, a.Description)
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
    root:AddText("Hover an ability for what it does in BG3. Preset: " .. tostring(view.Preset)
        .. ", JP multiplier x" .. Util.Num(view.Multiplier or 1) .. ".")
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
