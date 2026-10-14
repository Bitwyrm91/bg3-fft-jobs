-- Client side of the job menus in BG3's own UI (tools/menu_gen.py): every Learn entry's tooltip has one line per
-- job (its ExtraDescription string) that this file rewrites with the controlled character's unspent JP. The server
-- sends the party's JP when it changes (Service:PushMenuJP); a character switch is noticed on a throttled tick.
-- Unverified in game: Ext.Loca.UpdateTranslatedString and the ClientControl component (both used through pcall).
local JobMenu = {}

JobMenu.Channel = "FFTJ_MenuJP" -- same name as NetServer.MenuJPChannel
JobMenu.CheckMs = 500

-- The character this client controls (bare lower-case UUID), or nil.
function JobMenu.Controlled()
    local ok, list = pcall(Ext.Entity.GetAllEntitiesWithComponent, "ClientControl")
    if not ok or type(list) ~= "table" then
        return nil
    end
    for _, e in ipairs(list) do
        local uuid = e.Uuid and e.Uuid.EntityUuid
        if uuid then
            return string.lower(uuid)
        end
    end
    return nil
end

-- Pure: the text of each job's JP line for one character entry ({Name, JP = {job = unspent}}).
function JobMenu.Lines(menu, jobs, entry)
    local out = {}
    for jobId, handle in pairs(menu.HaveHandle) do
        local jp = entry and entry.JP and entry.JP[jobId]
        local name = jobs[jobId] and jobs[jobId].Name or jobId
        if jp then
            out[handle] = string.format("%s has %s %s JP to spend.", entry.Name ~= "" and entry.Name or "You", jp, name)
        end
    end
    return out
end

function JobMenu.Setup(modUuid, log)
    if not (Ext.Net and Ext.Net.CreateChannel and Ext.Loca and Ext.Loca.UpdateTranslatedString) then
        log.Warn("job menus: Ext.Net or Ext.Loca.UpdateTranslatedString missing; Learn tooltips show no JP")
        return nil
    end
    local data = Ext.Require("Shared/GeneratedData.lua")
    if not data.JobMenu then
        return nil
    end
    local state = { Chars = nil, Shown = nil, Next = 0, Dirty = false }
    local function apply()
        local guid = JobMenu.Controlled()
        if not state.Chars or not guid then
            return
        end
        if guid == state.Shown and not state.Dirty then
            return
        end
        state.Shown, state.Dirty = guid, false
        for handle, text in pairs(JobMenu.Lines(data.JobMenu, data.Jobs, state.Chars[guid])) do
            local ok, err = pcall(Ext.Loca.UpdateTranslatedString, handle, text)
            if not ok then
                log.Warn("job menus: UpdateTranslatedString failed: " .. tostring(err))
                return
            end
        end
    end
    local channel = Ext.Net.CreateChannel(modUuid, JobMenu.Channel)
    channel:SetHandler(function(payload)
        log.Safe("job menu JP", function()
            if type(payload) == "table" and type(payload.Chars) == "table" then
                state.Chars, state.Dirty = payload.Chars, true
                apply()
            end
        end)
    end)
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Utils.MonotonicTime()
        if now < state.Next then
            return
        end
        state.Next = now + JobMenu.CheckMs
        log.Safe("job menu tick", apply)
    end)
    return state
end

return JobMenu
