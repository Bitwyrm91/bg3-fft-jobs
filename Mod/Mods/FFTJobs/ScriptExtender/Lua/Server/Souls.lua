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

-- The soul type of a creature: a boss's own soul by its character GUID (Data.SoulByGuid), else from its lower-case
-- keys (template name, stats id, display name); nil when no form answers to it.
function Souls.TypeOf(data, keys, guid)
    local boss = guid and data.SoulByGuid and data.SoulByGuid[guid]
    if boss then
        return boss
    end
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
    local typeId = Souls.TypeOf(svc.Data, keys, guid)
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
    local article = s.Name:find("^[AEIOU]") and "an" or "a"
    local msg = string.format("%s devoured %s %s soul (%d in the Soul Codex).", whoName, article, s.Name, n)
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
    local typeId = Souls.TypeOf(svc.Data, svc.Game:CreatureKeys(guid), guid)
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

-- The Soul Codex (PHASE2.md item 10; the user, 2026-10-13: "put it in a chest and let it be accessible right away
-- without further restriction"): a real item. When gameplay starts on a level and the party has no codex yet (a new
-- game on the nautiloid, or an older save), a chest appears beside the host character with the codex inside, once
-- per level. Taking the codex (a party member gets it: TemplateAddedTo) gives the SoulCodex badge, which opens the
-- Soul Collector for the whole party. If no chest can be made, the badge comes at once: the job is never out of reach.
Souls.CODEX_CHEST = "A chest beside you holds the Soul Codex."
Souls.CODEX_TAKEN = "You took the Soul Codex, a book of stolen souls."
Souls.CODEX_FALLBACK = "A codex of stolen souls turned up in your pack."
Souls.CHEST_OFFSET = 1.5

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

-- The chest with the codex beside the host character (once per level while the party has no codex).
function Souls.PlaceCodex(svc, level)
    local codex = svc.Data.SoulCodex
    local meta = svc.State:Meta()
    if not svc.Ready or not codex or hasCodex(svc) or (meta.CodexChest and meta.CodexLevel == level) then
        return false
    end
    local host = svc.Game:HostCharacter()
    if not host then
        return false
    end
    local chest = svc.Game:SpawnNear(codex.Chest, host, Souls.CHEST_OFFSET)
    if not chest then
        svc.Log.Warn("could not place the Soul Codex chest; the codex is given at once")
        return Souls.GiveCodex(svc, Souls.CODEX_FALLBACK)
    end
    svc.Game:TemplateAddTo(codex.Item, chest, 1)
    meta.CodexChest = chest
    meta.CodexLevel = level
    svc.State:MarkDirty()
    svc.Log.Info(string.format("Soul Codex chest placed: %s (%s)", chest, tostring(level)))
    svc:Notify(host, Souls.CODEX_CHEST)
    return true
end

-- Osiris TemplateAddedTo: the codex went into a party member's inventory.
function Souls.OnTemplateAdded(svc, template, holder)
    local codex = svc.Data.SoulCodex
    if codex and template == codex.Item and holder and (svc.State:Get(holder) or svc.Game:IsPartyMember(holder)) then
        Souls.GiveCodex(svc, Souls.CODEX_TAKEN)
    end
end

-- Gameplay started on a level.
function Souls.OnLevel(svc, level)
    Souls.PlaceCodex(svc, level)
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
