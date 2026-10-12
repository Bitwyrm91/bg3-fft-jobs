-- Hooks the engine to Osiris events and SE engine events. Every handler is protected, so an error in one
-- event is logged and never breaks the game's own scripts.

local Events = {}

-- {Osiris event, arity, Service method}; arities from the story header (DESIGN.md section 4).
Events.Osiris = {
    { "CastedSpell", 5, "OnCastedSpell" },
    { "EnteredCombat", 2, "OnEnteredCombat" },
    { "CombatStarted", 1, "OnCombatStarted" },
    { "CombatRoundStarted", 2, "OnCombatRoundStarted" },
    { "CombatEnded", 1, "OnCombatEnded" },
    { "TurnStarted", 1, "OnTurnStarted" },
    { "LongRestFinished", 0, "OnLongRestFinished" },
    { "LeveledUp", 1, "OnLeveledUp" },
    { "CharacterJoinedParty", 1, "OnCharacterJoinedParty" },
    { "LevelGameplayStarted", 2, "OnLevelGameplayStarted" },
    -- job ability effects (Effects.lua); arities from LaughingLeader's generated Osi.Events.lua (2026-10-12)
    { "StatusApplied", 4, "OnStatusApplied" },
    { "AttackedBy", 7, "OnAttackedBy" },
    { "KilledBy", 4, "OnKilledBy" },
}

function Events.Register(svc, log)
    for _, e in ipairs(Events.Osiris) do
        local name, arity, method = e[1], e[2], e[3]
        Ext.Osiris.RegisterListener(name, arity, "after", function(...)
            log.Safe(name, svc[method], svc, ...)
        end)
    end
    Ext.Events.SessionLoaded:Subscribe(function()
        log.Safe("SessionLoaded", svc.OnSessionLoaded, svc)
    end)
    Ext.Events.ResetCompleted:Subscribe(function()
        log.Safe("ResetCompleted", svc.OnResetCompleted, svc)
    end)
end

return Events
