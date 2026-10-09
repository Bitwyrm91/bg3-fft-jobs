-- FFT Job System (BG3 Script Extender mod): server bootstrap.
-- ModuleUUID is only valid while the mod loads, so it is captured here.
local MOD_UUID = ModuleUUID or "3db7be3e-9387-4678-b172-044acc7ff0c2"

-- Save-game persistence; registered at bootstrap on both sides with the same settings (SE docs, Persistence).
Ext.Vars.RegisterModVariable(MOD_UUID, "State", {
    Server = true,
    Client = false,
    WriteableOnServer = true,
    WriteableOnClient = false,
    Persistent = true,
    SyncToClient = false,
    SyncToServer = false,
})

local Data = Ext.Require("Shared/GeneratedData.lua")
local Log = Ext.Require("Shared/Log.lua")
local Config = Ext.Require("Server/Config.lua")
local State = Ext.Require("Server/State.lua")
local Game = Ext.Require("Server/Game.lua")
local Telemetry = Ext.Require("Server/Telemetry.lua")
local Service = Ext.Require("Server/Service.lua")
local Events = Ext.Require("Server/Events.lua")
local Commands = Ext.Require("Server/Commands.lua")
local NetServer = Ext.Require("Server/NetServer.lua")

local files = {
    Load = function(path)
        return Ext.IO.LoadFile(path)
    end,
    Save = function(path, text)
        return Ext.IO.SaveFile(path, text)
    end,
}

local json = {
    Parse = function(text)
        return Ext.Json.Parse(text)
    end,
    Stringify = function(value, pretty)
        return Ext.Json.Stringify(value, { Beautify = pretty and true or false })
    end,
}

local storage = {
    Read = function()
        return Ext.Vars.GetModVariables(MOD_UUID).State
    end,
    Write = function(root)
        Ext.Vars.GetModVariables(MOD_UUID).State = root
    end,
}

local config = Config.New(Data, files, json, Log)
local service = Service.New({
    Data = Data,
    Config = config,
    State = State.New(storage, function(fn)
        Ext.OnNextTick(fn)
    end, Log),
    Game = Game.New(Log),
    Telemetry = Telemetry.New(files, json, function()
        return config:Effective()
    end, Log),
    Log = Log,
    Clock = function()
        local ok, t = pcall(Ext.Timer.ClockTime)
        return ok and t or nil
    end,
    WaitFor = function(ms, fn)
        Ext.Timer.WaitFor(ms, fn)
    end,
})

Events.Register(service, Log)
Commands.Register(service, Log)
NetServer.Register(service, Ext.Net, MOD_UUID, Log)

-- For poking at it from the SE console: Mods.FFTJobs.FFTJ.Service
FFTJ = { Service = service, Data = Data }

Log.Info("server side loaded (version " .. Data.ModVersion .. "); type !fft_help in the SE console")
