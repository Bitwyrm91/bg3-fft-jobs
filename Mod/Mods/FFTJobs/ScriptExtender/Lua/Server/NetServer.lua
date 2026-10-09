-- Server side of the Job Board: one request channel (client asks, server answers with the new view)
-- and one message channel (server tells the client to open the window).
local Util = Ext.Require("Shared/Util.lua")
local View = Ext.Require("Server/View.lua")

local NetServer = {}

NetServer.RequestChannel = "FFTJ_Board"
NetServer.OpenChannel = "FFTJ_Open"

-- Pure request handler: {Op, Char, Job, Ability, Slot} -> {Ok, Message, View}
function NetServer.Handle(svc, req)
    req = type(req) == "table" and req or {}
    local guid = Util.Guid(req.Char)
    local ok, msg = true, nil
    local op = req.Op
    if op == nil or op == "View" then
        ok = true
    elseif op == "SetPrimary" then
        ok, msg = svc:SetPrimary(guid, req.Job)
    elseif op == "SetSecondary" then
        local job = req.Job
        if job == "" then
            job = nil
        end
        ok, msg = svc:SetSecondary(guid, job)
    elseif op == "Learn" then
        ok, msg = svc:Learn(guid, req.Ability)
    elseif op == "Equip" then
        ok, msg = svc:Equip(guid, req.Ability)
    elseif op == "Unequip" then
        ok, msg = svc:Unequip(guid, req.Slot)
    else
        ok, msg = false, "Unknown request " .. tostring(op)
    end
    return { Ok = ok, Message = msg, View = View.Build(svc, guid) }
end

-- net = Ext.Net (NetChannel API, SE v22+)
function NetServer.Register(svc, net, modUuid, log)
    if not (net and net.CreateChannel) then
        log.Warn("Ext.Net.CreateChannel is missing (Script Extender too old?): the Job Board window is off, use !fft_ commands")
        return false
    end
    local request = net.CreateChannel(modUuid, NetServer.RequestChannel)
    local open = net.CreateChannel(modUuid, NetServer.OpenChannel)
    request:SetRequestHandler(function(data, user)
        local reply
        log.Safe("Job Board request", function()
            reply = NetServer.Handle(svc, data)
        end)
        return reply or { Ok = false, Message = "Server error, see the SE console" }
    end)
    svc.OnOpenBoard = function(guid)
        open:Broadcast({ Char = guid, View = View.Build(svc, guid) })
    end
    return true
end

return NetServer
