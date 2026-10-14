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

-- Poisoned and Acid also deal damage each turn (Server/Effects.lua, config Abilities.PoisonTickDie / AcidTickDie):
-- say so in BG3's own status tooltips (vanilla description handles; unverified in game).
local STATUS_TEXT = {
    h0e3666feg49ceg4aebg85feg62e178e4462c = " Also takes 1d4 Poison damage at the start of each turn.",
    h24742bb9g049fg4c09gb68eg4be61b2657df = " Also takes 1d4 Acid damage at the start of each turn.",
}
local function patchStatusText()
    for handle, extra in pairs(STATUS_TEXT) do
        Log.Safe("status text", function()
            local text = Ext.Loca.GetTranslatedString(handle)
            if text and text ~= "" and not text:find(extra, 1, true) then
                Ext.Loca.UpdateTranslatedString(handle, text .. extra)
            end
        end)
    end
end
if Ext.Loca and Ext.Loca.UpdateTranslatedString then
    patchStatusText()
    Ext.Events.SessionLoaded:Subscribe(patchStatusText)
end

Log.Info("client side loaded; open the Job Board with its spell (server side loads with a save)")
