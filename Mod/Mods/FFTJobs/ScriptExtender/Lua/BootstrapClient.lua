-- FFT Job System: client bootstrap (the Job Board window).
local MOD_UUID = ModuleUUID or "3db7be3e-9387-4678-b172-044acc7ff0c2"

-- Same registration as the server (the SE docs recommend registering on both sides with the same settings).
Ext.Vars.RegisterModVariable(MOD_UUID, "State", {
    Server = true,
    Client = false,
    WriteableOnServer = true,
    WriteableOnClient = false,
    Persistent = true,
    SyncToClient = false,
    SyncToServer = false,
})

local Log = Ext.Require("Shared/Log.lua")
local JobBoard = Ext.Require("Client/JobBoard.lua")
local JobMenu = Ext.Require("Client/JobMenu.lua")

FFTJ = { Board = JobBoard.Setup(MOD_UUID, Log), Menu = JobMenu.Setup(MOD_UUID, Log) }

Log.Info("client side loaded; open the Job Board with its spell (server side loads with a save)")
