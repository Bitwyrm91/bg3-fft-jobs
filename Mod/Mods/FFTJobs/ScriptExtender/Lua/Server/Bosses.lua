-- Boss badges (special jobs, docs/SPECIAL_JOBS.md). Each badge belongs to a BG3 boss (Data.Badges[id].Characters,
-- level character GUIDs from the vanilla data) and the party gets it once:
--   * when the game counts the boss as defeated: Osiris DB_Defeated (dead, knocked out, surrendered, petrified,
--     banished, ...), read after every fight and when a save loads, so bosses beaten before the mod was installed
--     count too; Died gives it at once;
--   * when the boss joins the party (Minthara hands hers over);
--   * when the party moves on to a later act after meeting the boss (fought it, or it spoke with a party member) and
--     leaving it alive: the user's rule, spared bosses still give their badge. Spared "always": met or not (Zhalk).
-- Config: Badges.FromBosses (all of it), Badges.SparedBosses (the act rule).
local Bosses = {}

function Bosses.BadgeOf(data, guid)
    return guid ~= nil and data.BossBadge ~= nil and data.BossBadge[guid] or nil
end

local function cfgOn(svc, key)
    local b = svc:Cfg().Badges
    return b == nil or b[key] ~= false
end

local function active(svc)
    return svc.Ready and not svc:IsDisabled() and cfgOn(svc, "FromBosses")
end

local function found(svc, badgeId)
    local badges = svc.State:Meta().Badges
    return badges ~= nil and badges[badgeId] == true
end

local REASONS = {
    Defeated = "%s is defeated.",
    Joined = "%s joined the party.",
    Spared = "%s was spared.",
}

-- Gives a boss's badge once; how = Defeated, Joined or Spared. Returns true when the badge is new.
function Bosses.Give(svc, badgeId, how)
    local badge = svc.Data.Badges[badgeId]
    if not badge or found(svc, badgeId) then
        return false
    end
    local reason = (how == "Spared" and (badge.SparedText or "") ~= "") and badge.SparedText
        or string.format(REASONS[how], badge.Boss)
    svc.Log.Info(string.format("boss badge %s: %s (%s)", badgeId, badge.Boss, how))
    svc:AddBadge(badgeId, nil, reason)
    return true
end

-- Osiris Died: one of a boss's characters died.
function Bosses.OnDied(svc, guid)
    local badgeId = Bosses.BadgeOf(svc.Data, guid)
    if badgeId and active(svc) then
        Bosses.Give(svc, badgeId, "Defeated")
    end
end

-- Osiris CharacterJoinedParty: a boss joined the party.
function Bosses.OnJoined(svc, guid)
    local badgeId = Bosses.BadgeOf(svc.Data, guid)
    if badgeId and active(svc) then
        Bosses.Give(svc, badgeId, "Joined")
    end
end

-- Every missing boss badge whose boss the game counts as defeated. Returns the badge ids given.
function Bosses.CheckDefeated(svc)
    local given = {}
    if not active(svc) then
        return given
    end
    local defeated -- read only while some boss badge is missing
    for _, badgeId in ipairs(svc.Data.BadgeOrder or {}) do
        local badge = svc.Data.Badges[badgeId]
        if badge.Characters and not found(svc, badgeId) then
            defeated = defeated or svc.Game:DefeatedSet()
            for _, g in ipairs(badge.Characters) do
                if defeated[g] then
                    Bosses.Give(svc, badgeId, "Defeated")
                    given[#given + 1] = badgeId
                    break
                end
            end
        end
    end
    return given
end

function Bosses.Met(svc, badgeId)
    if found(svc, badgeId) then
        return
    end
    local meta = svc.State:Meta()
    meta.BossMet = meta.BossMet or {}
    if not meta.BossMet[badgeId] then
        meta.BossMet[badgeId] = true
        svc.State:MarkDirty()
        svc.Log.Info("the party met " .. svc.Data.Badges[badgeId].Boss)
    end
end

-- Osiris EnteredCombat: a boss in a fight has met the party.
function Bosses.OnEnteredCombat(svc, guid)
    local badgeId = Bosses.BadgeOf(svc.Data, guid)
    if badgeId and active(svc) then
        Bosses.Met(svc, badgeId)
    end
end

-- Osiris DialogActorJoined: who is in each dialog; a boss and a party member in the same one have met.
function Bosses.OnDialogActor(svc, instance, guid)
    if guid == nil or instance == nil or not active(svc) then
        return
    end
    svc.DialogActors = svc.DialogActors or {}
    local actors = svc.DialogActors[instance] or {}
    svc.DialogActors[instance] = actors
    actors[guid] = true
    local party, bosses = false, {}
    for g in pairs(actors) do
        local badgeId = Bosses.BadgeOf(svc.Data, g)
        if badgeId then
            bosses[#bosses + 1] = badgeId
        elseif svc.State:Get(g) then
            party = true
        end
    end
    if party then
        for _, badgeId in ipairs(bosses) do
            Bosses.Met(svc, badgeId)
        end
    end
end

function Bosses.OnDialogEnded(svc, instance)
    if svc.DialogActors then
        svc.DialogActors[instance] = nil
    end
end

-- A level started (Data.LevelActs gives its act). On reaching a later act than before, the bosses of the earlier acts
-- the party met and left alive give their badges ("always": met or not). The first act seen on a save (the mod
-- installed mid-game) only sets the act: nobody saw the party meet the earlier bosses ("always" still counts).
function Bosses.OnLevel(svc, level)
    local act = level and svc.Data.LevelActs and svc.Data.LevelActs[level]
    if act == nil or not active(svc) then
        return
    end
    local meta = svc.State:Meta()
    local before = meta.Act
    if before ~= nil and act <= before then
        return
    end
    meta.Act = act
    svc.State:MarkDirty()
    svc.Log.Info(string.format("act %d reached (%s)", act, level))
    if not cfgOn(svc, "SparedBosses") then
        return
    end
    Bosses.CheckDefeated(svc) -- the defeated ones first, with their own reason
    for _, badgeId in ipairs(svc.Data.BadgeOrder or {}) do
        local badge = svc.Data.Badges[badgeId]
        if badge.Characters and badge.Act < act and not found(svc, badgeId) then
            local met = before ~= nil and meta.BossMet ~= nil and meta.BossMet[badgeId] == true
            if badge.Spared == "always" or (badge.Spared == "met" and met) then
                Bosses.Give(svc, badgeId, "Spared")
            end
        end
    end
end

-- One line per boss badge for !fft_badge list: "Cleric Badge: True Soul Gut (Act 1), found".
function Bosses.Lines(svc)
    local out = {}
    local meta = svc.State:IsLoaded() and svc.State:Meta() or {}
    for _, badgeId in ipairs(svc.Data.BadgeOrder or {}) do
        local b = svc.Data.Badges[badgeId]
        local state = (meta.Badges and meta.Badges[badgeId]) and "found"
            or ((meta.BossMet and meta.BossMet[badgeId]) and "met" or "not yet")
        if b.Boss then
            out[#out + 1] = string.format("  %s: %s, from %s (%s), %s", badgeId, b.Name, b.Boss,
                b.Act == 0 and "prologue" or ("Act " .. b.Act), state)
        else
            out[#out + 1] = string.format("  %s: %s, %s", badgeId, b.Description, state)
        end
    end
    return out
end

return Bosses
