-- The Soul Collector (docs/PHASE2.md items 9-19, docs/SOUL_COLLECTOR_MAP.md). Soul Brand puts FFTJ_SOUL_BRAND on a
-- creature for 1 turn; if it dies while branded (by anyone's hand), the party devours its soul: the soul type (from
-- the creature's template, stats id and name, Data.Souls[].Match) gains one soul in the party's Soul Codex
-- (Meta.Souls, copied into every character by Rules.SyncParty). Rules.DesiredGrants then grants the type's two forms
-- at the tier the souls reach (1, 3, 5) to every character with Soul Incarnation in use. Enemies of a devoured type
-- get the FFTJ_SOUL_KNOWN marker when they enter a fight. The job opens with the Soul Codex (a badge without a boss).
local Souls = {}

Souls.BRAND = "FFTJ_SOUL_BRAND"
Souls.KNOWN = "FFTJ_SOUL_KNOWN"
Souls.BADGE = "SoulCodex"
Souls.FORGET_MS = 1500 -- a brand removed this long before Died still counts (the order of the two events is unknown)

-- The soul type of a creature, from its lower-case keys (template name, stats id, display name), or nil.
function Souls.TypeOf(data, keys)
    if not keys or keys == "" then
        return nil
    end
    for _, id in ipairs(data.SoulOrder or {}) do
        local s = data.Souls[id]
        local hit = false
        for _, p in ipairs(s.Match) do
            if keys:find(p) then
                hit = true
                break
            end
        end
        for _, p in ipairs(s.Exclude or {}) do
            if hit and keys:find(p) then
                hit = false
            end
        end
        if hit then
            return id
        end
    end
    return nil
end

-- The tier a number of souls reaches: 1, 3 or 5 (nil for none).
function Souls.Tier(count)
    count = count or 0
    if count >= 5 then
        return 5
    elseif count >= 3 then
        return 3
    elseif count >= 1 then
        return 1
    end
    return nil
end

local function codex(svc)
    local meta = svc.State:Meta()
    meta.Souls = meta.Souls or {}
    return meta.Souls
end

function Souls.OnStatusApplied(svc, target, status, causee)
    if status == Souls.BRAND and target then
        svc.SoulBranded[target] = { By = causee, Gen = (svc.SoulBranded[target] and svc.SoulBranded[target].Gen or 0) + 1 }
    end
end

function Souls.OnStatusRemoved(svc, target, status)
    local b = target and svc.SoulBranded[target]
    if status ~= Souls.BRAND or not b then
        return
    end
    local gen = b.Gen
    svc.WaitFor(Souls.FORGET_MS, function()
        local now = svc.SoulBranded[target]
        if now and now.Gen == gen and not svc.Game:IsDead(target) then
            svc.SoulBranded[target] = nil
        end
    end)
end

function Souls.OnDied(svc, guid)
    local b = guid and svc.SoulBranded[guid]
    if not b then
        return
    end
    svc.SoulBranded[guid] = nil
    Souls.Devour(svc, guid, b.By)
end

-- The party devours a creature's soul. Returns the soul type id (nil when no form answers to it).
function Souls.Devour(svc, guid, by)
    local keys = svc.Game:CreatureKeys(guid)
    local typeId = Souls.TypeOf(svc.Data, keys)
    local who = (by and svc.State:Get(by)) and by or svc.Game:HostCharacter()
    local whoName = who and svc.State:Get(who) and svc.State:Get(who).Name or "The party"
    if not typeId then
        svc.Log.Info("soul without a form: " .. tostring(keys))
        if who then
            svc:Notify(who, whoName .. " devoured a soul, but no form answers to it yet.")
        end
        return nil
    end
    local souls = codex(svc)
    local before = Souls.Tier(souls[typeId])
    souls[typeId] = (souls[typeId] or 0) + 1
    svc.State:MarkDirty()
    svc:SyncParty()
    svc:ReconcileAll()
    local s = svc.Data.Souls[typeId]
    local n = souls[typeId]
    local msg = string.format("%s devoured a %s soul (%d in the Soul Codex).", whoName, s.Name, n)
    local tier = Souls.Tier(n)
    if not before then
        msg = msg .. string.format(" New forms: %s and %s.", s.Forms.B.Name, s.Forms.F.Name)
    elseif tier ~= before then
        msg = msg .. string.format(" Its forms grow stronger (%d souls).", tier)
    end
    svc.Log.Info(string.format("soul devoured: %s (%s) -> %s x%d", guid, tostring(keys), typeId, n))
    if who then
        svc:Notify(who, msg)
    end
    return typeId
end

-- A creature entered a fight: the marker when the party already devoured its soul type.
function Souls.OnEnteredCombat(svc, guid)
    if not guid or svc.State:Get(guid) or svc.Game:IsPartyMember(guid) then
        return
    end
    local souls = svc.State:Meta().Souls
    if not souls or next(souls) == nil then
        return
    end
    local typeId = Souls.TypeOf(svc.Data, svc.Game:CreatureKeys(guid))
    if typeId and souls[typeId] then
        svc.Game:ApplyStatus(guid, Souls.KNOWN, -1)
    end
end

-- !fft_soul add: testing; adds souls of a type without a kill. Returns ok, message.
function Souls.Add(svc, typeId, count)
    local s = svc.Data.Souls and svc.Data.Souls[typeId]
    if not s then
        return false, "Unknown soul type " .. tostring(typeId)
    end
    local souls = codex(svc)
    souls[typeId] = (souls[typeId] or 0) + (count or 1)
    svc.State:MarkDirty()
    svc:SyncParty()
    svc:ReconcileAll()
    return true, string.format("Soul Codex: %s x%d", s.Name, souls[typeId])
end

-- The type id for user input ("goblin", "Giant Eagle").
function Souls.Find(data, text)
    local n = string.lower((text or ""):gsub("[%s%-_']", ""))
    for _, id in ipairs(data.SoulOrder or {}) do
        local s = data.Souls[id]
        if string.lower(id) == n or string.lower((s.Name:gsub("[%s%-_']", ""))) == n then
            return id
        end
    end
    return nil
end

-- The Soul Codex (PHASE2.md item 10): beside "Us", the intellect devourer in the nautiloid's lab. For now it is a
-- notification and the Job Board, like the boss badges (an item later, with the art): the party gets it when a party
-- member talks with Us or Us joins; a party that reaches the shore without it (or a save made later) finds it in the
-- camp's traveller's chest.
Souls.US = "40bd6b82-2728-410a-bb8a-a805f98556a1" -- S_TUT_Lab_IntellectDevourer
Souls.CODEX_US = "Beside the brain in the jar lies a codex of stolen souls."
Souls.CODEX_CAMP = "A codex of stolen souls turned up in your camp's traveller's chest."

local function hasCodex(svc)
    local badges = svc.State:Meta().Badges
    return badges ~= nil and badges[Souls.BADGE] == true
end

function Souls.GiveCodex(svc, reason)
    if not svc.Ready or hasCodex(svc) or not (svc.Data.Badges and svc.Data.Badges[Souls.BADGE]) then
        return false
    end
    svc.Log.Info("Soul Codex found: " .. reason)
    svc:AddBadge(Souls.BADGE, nil, reason)
    return true
end

-- Osiris DialogActorJoined: Us and a party member in the same dialog.
function Souls.OnDialogActor(svc, instance, guid)
    if not instance or not guid or hasCodex(svc) then
        return
    end
    svc.SoulDialogs = svc.SoulDialogs or {}
    local d = svc.SoulDialogs[instance] or {}
    svc.SoulDialogs[instance] = d
    if guid == Souls.US then
        d.Us = true
    elseif svc.State:Get(guid) then
        d.Party = true
    end
    if d.Us and d.Party then
        Souls.GiveCodex(svc, Souls.CODEX_US)
    end
end

function Souls.OnDialogEnded(svc, instance)
    if svc.SoulDialogs then
        svc.SoulDialogs[instance] = nil
    end
end

function Souls.OnJoined(svc, guid)
    if guid == Souls.US then
        Souls.GiveCodex(svc, Souls.CODEX_US)
    end
end

-- A level started: past the nautiloid (Data.LevelActs act 1 or later) without the codex, it is in the camp chest.
function Souls.OnLevel(svc, level)
    local act = level and svc.Data.LevelActs and svc.Data.LevelActs[level]
    if act and act >= 1 then
        Souls.GiveCodex(svc, Souls.CODEX_CAMP)
    end
end

-- One line per devoured type for !fft_soul list.
function Souls.Lines(svc)
    local out = {}
    local souls = svc.State:IsLoaded() and svc.State:Meta().Souls or {}
    for _, id in ipairs(svc.Data.SoulOrder or {}) do
        if souls[id] then
            local s = svc.Data.Souls[id]
            out[#out + 1] = string.format("%s x%d: %s / %s", s.Name, souls[id], s.Forms.B.Name, s.Forms.F.Name)
        end
    end
    return out
end

return Souls
