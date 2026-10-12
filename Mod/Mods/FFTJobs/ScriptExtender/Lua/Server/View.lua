-- Builds the plain table the Job Board window renders (sent to the client over a NetChannel).
local Util = Ext.Require("Shared/Util.lua")
local Rules = Ext.Require("Server/Rules.lua")

local View = {}

local function abilityRef(data, id)
    local ab = id and data.Abilities[id]
    return ab and { Id = ab.Id, Name = ab.Name } or nil
end

function View.Char(svc, guid)
    local data = svc.Data
    local cfg = svc:Cfg()
    local char = svc.State:Get(guid)
    local th = cfg.JobLevels.Thresholds
    local inCombat = svc.Game:IsInCombat(guid)
    local primaryJob = data.Jobs[char.Primary]
    local pjs = char.Jobs[char.Primary] or {}
    local v = {
        Guid = guid,
        Name = char.Name,
        Primary = {
            Id = char.Primary, Name = primaryJob.Name, Skillset = primaryJob.Skillset,
            Level = Rules.JobLevel(pjs.Earned or 0, th), Unspent = pjs.Unspent or 0, Earned = pjs.Earned or 0,
        },
        Secondary = char.Secondary and data.Jobs[char.Secondary] and {
            Id = char.Secondary, Name = data.Jobs[char.Secondary].Name, Skillset = data.Jobs[char.Secondary].Skillset,
        } or nil,
        Reaction = abilityRef(data, char.Reaction),
        Passive1 = abilityRef(data, char.Passive1),
        Passive2 = abilityRef(data, char.Passive2),
        PassiveFree = char.Passive1 == nil or char.Passive2 == nil,
        JPBoost = Rules.HasJPBoost(data, char, cfg),
        AlwaysOnTypes = Util.DeepCopy(cfg.Rules.MainJobAlwaysOn or {}),
        InCombat = inCombat,
        Locked = {
            Job = cfg.Rules.ChangeJobOutOfCombatOnly and inCombat,
            Learn = cfg.Rules.LearnOutOfCombatOnly and inCombat,
            Slots = cfg.Rules.SlotsOutOfCombatOnly and inCombat,
        },
        Jobs = {},
        Abilities = {},
    }
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Implemented then
            local js = char.Jobs[jobId] or {}
            local earned = js.Earned or 0
            local unlocked = Rules.IsUnlocked(char, jobId)
            v.Jobs[#v.Jobs + 1] = {
                Id = jobId, Name = job.Name, Skillset = job.Skillset, Unlocked = unlocked,
                Level = Rules.JobLevel(earned, th), Earned = earned, Unspent = js.Unspent or 0,
                NextAt = Rules.NextThreshold(earned, th),
                Mastered = Rules.IsMastered(data, char, jobId),
                LearnedCount = Rules.LearnedCount(data, char, jobId),
                Total = #data.AbilitiesByJob[jobId],
                IsPrimary = char.Primary == jobId, IsSecondary = char.Secondary == jobId,
                Requirements = Rules.RequirementText(data, jobId),
                -- unlocked by someone in the party: shown to everyone, but this character needs its own levels
                PartyUnlocked = Rules.IsPartyUnlocked(svc.State:Meta(), jobId),
                Missing = not unlocked and Rules.MissingText(data, cfg, char, jobId) or nil,
                Equip = job.Equip ~= "" and job.Equip or nil,
                Mastery = job.Mastery and job.Mastery.Description or nil,
                MasteryPerk = Rules.HasMasteryPerk(data, cfg, char, jobId),
            }
            local list = {}
            for _, aid in ipairs(data.AbilitiesByJob[jobId]) do
                local ab = data.Abilities[aid]
                local learned = Rules.IsLearned(char, aid)
                local canLearn, reason = Rules.CanLearn(data, char, aid)
                local slot = ab.Type ~= "Action" and Rules.SlotOf(char, aid) or nil
                local equipped = slot ~= nil
                local alwaysOn = Rules.IsAlwaysOn(data, cfg, char, aid)
                list[#list + 1] = {
                    Id = aid, Name = ab.Name, Type = ab.Type, Cost = ab.Cost, Description = ab.Description,
                    Learned = learned, CanLearn = canLearn, Reason = (not canLearn and not learned) and reason or nil,
                    Equipped = equipped, Slot = slot, SlotLabel = slot and Rules.SlotLabels[slot] or nil,
                    AlwaysOn = alwaysOn,
                    -- granted right now: actions of the primary/secondary job, equipped reaction/support/movement,
                    -- the main job's always-on ones
                    Active = learned and (equipped or alwaysOn or (ab.Type == "Action"
                        and (char.Primary == jobId or char.Secondary == jobId))),
                }
            end
            v.Abilities[jobId] = list
        end
    end
    return v
end

function View.Build(svc, selected)
    local view = {
        Chars = {},
        Preset = svc.Config.Preset,
        Multiplier = svc:Cfg().JP.GlobalMultiplier,
        Disabled = svc:IsDisabled(),
    }
    if not svc.Ready then
        view.Message = "The job system has not loaded yet"
        return view
    end
    for _, guid in ipairs(svc.State:Guids()) do
        local char = svc.State:Get(guid)
        view.Chars[#view.Chars + 1] = { Guid = guid, Name = char.Name or guid, Job = svc.Data.Jobs[char.Primary].Name }
    end
    table.sort(view.Chars, function(a, b)
        return Util.Normalize(a.Name) < Util.Normalize(b.Name)
    end)
    if not (selected and svc.State:Get(selected)) then
        selected = view.Chars[1] and view.Chars[1].Guid
    end
    view.Selected = selected
    if selected then
        view.Char = View.Char(svc, selected)
    end
    return view
end

return View
