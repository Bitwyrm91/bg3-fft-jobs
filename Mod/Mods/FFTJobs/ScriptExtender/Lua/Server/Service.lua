-- The engine: turns game events into JP, applies player choices, keeps grants in sync, writes telemetry.
local Util = Ext.Require("Shared/Util.lua")
local Rules = Ext.Require("Server/Rules.lua")
local Grants = Ext.Require("Server/Grants.lua")
local Effects = Ext.Require("Server/Effects.lua")
local Bosses = Ext.Require("Server/Bosses.lua")
local Souls = Ext.Require("Server/Souls.lua")

local Service = {}
Service.__index = Service

-- deps: Data, Config, State, Game, Telemetry, Log, Clock() -> string, WaitFor(ms, fn)
function Service.New(deps)
    local self = setmetatable({}, Service)
    for k, v in pairs(deps) do
        self[k] = v
    end
    self.Ready = false
    self.GameplayStarted = false
    self.Combats = {} -- combatId -> {Id, Start, Rounds, Chars = {[guid] = {Actions, JP = {source = n}, XPStart}}}
    self.CharCombat = {} -- guid -> combatId of the fight it entered
    self.Orphans = {} -- guid -> true: acted in combat without an EnteredCombat (e.g. a save loaded mid-fight)
    self.TurnCasts = {} -- guid -> casts counted this turn
    self.NotTrackable = {} -- guid -> true: checked, not a party member (NPCs cast spells and enter combat too)
    self.PollGeneration = 0
    self.PoachMarks = {} -- creature guid -> the poacher who hit it this turn (Effects.lua)
    self.EchoSeq = 0 -- counts echoable job abilities used by the party (Mime)
    self.LastEcho = nil -- {Spell = echo twin, Ability, By = guid, Seq}
    self.EchoSeen = {} -- Mime guid -> EchoSeq when its last turn ended
    self.OnOpenBoard = nil -- set by NetServer
    self.SoulBranded = {} -- creature guid -> {By = brander, Gen}: Soul Brand on it (Souls.lua)
    return self
end

function Service:Cfg()
    return self.Config:Effective()
end

function Service:IsDisabled()
    return self.State:IsLoaded() and self.State:Meta().Disabled == true
end

-- While Quiet (JP Training), notifications only go to the console.
function Service:Notify(guid, text)
    self.Log.Info(text)
    if not self.Quiet then
        self.Game:Notify(guid, text)
    end
end

---------------------------------------------------------------- lifecycle

-- After a save is loaded (or a new game set up). Saved state is only read from here on.
function Service:OnSessionLoaded()
    local _, msg = self.Config:Load()
    self.Log.Info(msg)
    self.Log.Debug = self:Cfg().Debug
    if self.State:IsLoaded() then
        self.State:Flush()
    end
    self.State:Load()
    self.Ready = true
    local cfg = self:Cfg()
    for _, char in pairs(self.State:Chars()) do
        if #Rules.CheckUnlocks(self.Data, cfg, char) > 0 then
            self.State:MarkDirty()
        end
    end
    self:SyncParty()
    self.Telemetry:Write({
        t = "session", clock = self.Clock(), version = self.Data.ModVersion, preset = self.Config.Preset,
        mult = cfg.JP.GlobalMultiplier, chars = Util.Count(self.State:Chars()),
    })
    if self.GameplayStarted then
        self:StartGameplay()
    end
end

-- Osiris LevelGameplayStarted: the story is running, Osiris calls are safe.
function Service:OnLevelGameplayStarted(level)
    self.Level = level
    self.GameplayStarted = true
    if self.Ready then
        self:StartGameplay()
    end
end

-- After `reset` in the SE console the Lua state is rebuilt in the middle of a game.
function Service:OnResetCompleted()
    self.GameplayStarted = true
    self:OnSessionLoaded()
end

function Service:StartGameplay()
    self.NotTrackable = {}
    self:DiscoverParty()
    self:ReconcileAll(true)
    self:PollXP()
    self:StartXPPoll()
    -- boss badges: bosses the story counts as defeated (also before the mod was installed), then the act rule
    Bosses.CheckDefeated(self)
    Bosses.OnLevel(self, self.Level or self.Game:CurrentLevel())
end

---------------------------------------------------------------- characters

function Service:GetChar(guid)
    return guid and self.State:Get(guid)
end

function Service:StartingJob(guid)
    local rules = self:Cfg().Rules
    local class = self.Game:ClassName(guid)
    local job = (class and rules.StartingJob.ByClass[class]) or rules.StartingJob.Default
    local def = self.Data.Jobs[job]
    if not (def and def.Implemented) then
        job = rules.StartingUnlocked[1] or "Squire"
    end
    return job
end

-- Returns the character's state, creating it for a party member seen for the first time.
function Service:EnsureChar(guid)
    if not self.Ready or type(guid) ~= "string" then
        return nil
    end
    local char = self.State:Get(guid)
    if char then
        return char
    end
    if self.NotTrackable[guid] then
        return nil
    end
    if not self.Game:IsTrackable(guid) then
        self.NotTrackable[guid] = true
        return nil
    end
    local startJob = self:StartingJob(guid)
    char = Rules.NewChar(self.Data, self:Cfg(), startJob)
    char.Name = self.Game:DisplayName(guid)
    char.LastXP = self.Game:TotalXP(guid)
    self.State:Set(guid, char)
    self.Log.Info(string.format("now tracking %s (starting job %s)", char.Name, self.Data.Jobs[startJob].Name))
    self:SyncParty() -- a new member gets the party's badges
    self:Reconcile(guid, false)
    return char
end

-- The party's shared state (Rules.SyncParty): badges reach every tracked character, and jobs anyone unlocked show
-- as unlocked by the party on every Job Board. Returns the job ids new to the party.
function Service:SyncParty()
    local known = Rules.SyncParty(self.Data, self.State:Chars(), self.State:Meta())
    self.State:MarkDirty()
    return known
end

-- Where an ability of this type goes: "the reaction slot" or "a passive slot".
local function slotHint(abilityType)
    return abilityType == "Reaction" and "the reaction slot" or "a passive slot"
end

function Service:DiscoverParty()
    for _, guid in ipairs(self.Game:PartyMembers()) do
        local char = self:EnsureChar(guid)
        if char then
            local name = self.Game:DisplayName(guid)
            if name and name ~= char.Name then
                char.Name = name
                self.State:MarkDirty()
            end
        end
    end
end

function Service:Reconcile(guid, repair)
    local char = self.State:Get(guid)
    if not char then
        return
    end
    local desired
    if self:IsDisabled() then
        desired = { Spells = {}, Passives = {}, Statuses = {} }
    else
        desired = Rules.DesiredGrants(self.Data, char, self:Cfg())
    end
    local changed, added, removed = Grants.Apply(self.Game, guid, char, desired, repair)
    if changed then
        self.State:MarkDirty()
        -- logged, so a playtest log shows what each choice gave the character
        local parts = {}
        if #added > 0 then
            parts[#parts + 1] = "added " .. table.concat(added, ", ")
        end
        if #removed > 0 then
            parts[#parts + 1] = "removed " .. table.concat(removed, ", ")
        end
        self.Log.Info(string.format("%s: %s", char.Name or guid, table.concat(parts, "; ")))
    end
end

-- Learned action abilities of a job (usable while it is the primary or secondary job).
function Service:LearnedActions(char, jobId)
    local n = 0
    for _, aid in ipairs(self.Data.AbilitiesByJob[jobId] or {}) do
        if self.Data.Abilities[aid].Type == "Action" and Rules.IsLearned(char, aid) then
            n = n + 1
        end
    end
    return n
end

local function usableText(n)
    if n == 0 then
        return ""
    end
    return string.format(", %d learned action%s usable", n, n == 1 and "" or "s")
end

-- Debugging (!fft_grants): what the jobs should grant right now, and whether the game reports it on the character.
function Service:DescribeGrants(guid)
    local char = self.State:Get(guid)
    local data = self.Data
    local lines = { string.format("%s: job %s, secondary %s", char.Name, data.Jobs[char.Primary].Name,
        char.Secondary and data.Jobs[char.Secondary].Name or "-") }
    local desired = self:IsDisabled() and { Spells = {}, Passives = {}, Statuses = {} }
        or Rules.DesiredGrants(data, char, self:Cfg())
    for _, kind in ipairs(Grants.Kinds) do
        for _, id in ipairs(Util.SortedKeys(desired[kind])) do
            local owned = char.Granted[kind] and char.Granted[kind][id]
            lines[#lines + 1] = string.format("  %s %s: %s%s", kind, id,
                self.Game:Has(kind, guid, id) and "in game" or "MISSING in game",
                owned and "" or " (not added by the mod)")
        end
    end
    return lines
end

function Service:ReconcileAll(repair)
    for _, guid in ipairs(self.State:Guids()) do
        self:Reconcile(guid, repair)
    end
end

---------------------------------------------------------------- JP

local function bump(stats, source, amount)
    stats.JP[source] = (stats.JP[source] or 0) + amount
end

-- Adds JP and handles level-up/unlock notifications. Returns the Rules.AddJP result (nil if not tracked).
function Service:AddJP(guid, jobId, amount, source, combatId)
    local char = self.State:Get(guid)
    if not char or self:IsDisabled() then
        return nil
    end
    local cfg = self:Cfg()
    local res = Rules.AddJP(self.Data, cfg, char, jobId, amount)
    local job = self.Data.Jobs[jobId]
    if res.Added > 0 then
        bump(char.Stats, source, res.Added)
        bump(char.SinceRest, source, res.Added)
        local rec = combatId and self.Combats[combatId]
        local c = rec and rec.Chars[guid]
        if c then
            c.JP[source] = (c.JP[source] or 0) + res.Added
        end
        self.State:MarkDirty()
        if cfg.Notifications.JPGain then
            self.Log.Info(string.format("%s +%s JP %s (%s)", char.Name, Util.Num(res.Added), job.Name, source))
        end
    end
    if res.LevelAfter > res.LevelBefore and cfg.Notifications.LevelUp then
        self:Notify(guid, string.format("%s: %s is now job level %d", char.Name, job.Name, res.LevelAfter))
    end
    for _, unlocked in ipairs(res.Unlocked) do
        if cfg.Notifications.Unlock then
            self:Notify(guid, string.format("%s unlocked the %s job!", char.Name, self.Data.Jobs[unlocked].Name))
        end
    end
    if #res.Unlocked > 0 then
        self:SyncParty()
    end
    if job and job.Implemented then
        self:ShareJP(guid, char, jobId, amount, source, combatId)
    end
    return res
end

-- Shared learning: part of a JP gain also goes into the character's other jobs (Rules.SharedTargets). The shared
-- JP is counted as source "Shared", which does not share again.
function Service:ShareJP(guid, char, fromJob, amount, source, combatId)
    local cfg = self:Cfg()
    local share = Rules.SharedJP(cfg.JP, amount, source)
    if share <= 0 then
        return
    end
    local fightJobs
    if cfg.JP.Shared.Scope == "FightJobs" then
        fightJobs = self:FightJobs(combatId)
    end
    for _, target in ipairs(Rules.SharedTargets(self.Data, cfg, char, fromJob, fightJobs)) do
        self:AddJP(guid, target, share, "Shared", combatId)
    end
end

-- The jobs used in combat: the primary jobs of a running fight's participants; outside a fight, those of the
-- party's latest fight (saved, empty before the first fight).
function Service:FightJobs(combatId)
    local set = {}
    local rec = combatId and self.Combats[combatId]
    if rec then
        for guid in pairs(rec.Chars) do
            local char = self.State:Get(guid)
            if char then
                set[char.Primary] = true
            end
        end
        return set
    end
    for _, jobId in ipairs(self.State:Meta().LastFightJobs or {}) do
        set[jobId] = true
    end
    return set
end

function Service:IsExcluded(spell)
    local a = self:Cfg().JP.Action
    for _, s in ipairs(a.ExcludeSpells) do
        if s == spell then
            return true
        end
    end
    for _, p in ipairs(a.ExcludePrefixes) do
        if p ~= "" and string.sub(spell, 1, #p) == p then
            return true
        end
    end
    return false
end

-- 1 for an action, BonusActionWeight for a bonus action, 0 for reactions (FFT: reactions earn no JP).
function Service:ActionWeight(spell)
    local a = self:Cfg().JP.Action
    local kind = self.Game:SpellCostKind(spell)
    if kind == "action" then
        return 1
    elseif kind == "bonus" then
        return a.BonusActionWeight
    elseif kind == "reaction" then
        return 0
    elseif kind == "free" then
        return a.RequireActionCost and 0 or 1
    end
    return 1 -- stats unreadable: count it rather than lose JP
end

-- Tracked characters in the same fight (alive), sorted.
function Service:FightMates(guid, combatId)
    local mates = {}
    local rec = combatId and self.Combats[combatId]
    if rec then
        for other in pairs(rec.Chars) do
            if other ~= guid and self.State:Get(other) and not self.Game:IsDead(other) then
                mates[#mates + 1] = other
            end
        end
    else
        for _, other in ipairs(self.State:Guids()) do
            if other ~= guid and self.Game:IsInCombat(other) and not self.Game:IsDead(other) then
                mates[#mates + 1] = other
            end
        end
    end
    table.sort(mates)
    return mates
end

-- Osiris CastedSpell: action JP for the caster, spillover for the others in the fight.
function Service:OnCastedSpell(caster, spell)
    if not self.Ready or self:IsDisabled() then
        return
    end
    local guid = Util.Guid(caster)
    if spell == self.Data.JobBoardSpell then
        self:OpenBoard(guid)
        return
    end
    if spell == self.Data.TrainingSpell then
        if not self:Cfg().Test.Tools then
            self.Log.Info("JP Training is turned off (Test.Tools = false)")
            return
        end
        local ok, msg = self:TrainParty(guid)
        if not ok then
            self.Log.Warn("JP Training: " .. msg)
        end
        return
    end
    local char = self.State:Get(guid) or self:EnsureChar(guid)
    if not char then
        return
    end
    self:TrackEcho(guid, char, spell)
    Effects.OnCastedSpell(self, guid, spell)
    if string.sub(spell, -6) == "_Arith" then
        return -- Arithmeticks' own casts: the rule shout already counted
    end
    local rule = self.Data.ArithRules and self.Data.ArithRules[spell]
    if rule then
        self:CastArithmeticks(guid, char, rule)
    end
    local cfg = self:Cfg()
    local jp = cfg.JP
    local inCombat = self.Game:IsInCombat(guid)
    if not inCombat and not jp.Action.CountOutOfCombat then
        return
    end
    if self:IsExcluded(spell) then
        return
    end
    local weight = self:ActionWeight(spell)
    if weight <= 0 then
        return
    end
    if jp.Action.MaxPerTurn > 0 then
        local n = self.TurnCasts[guid] or 0
        if n >= jp.Action.MaxPerTurn then
            return
        end
        self.TurnCasts[guid] = n + 1
    end
    local combatId = self.CharCombat[guid]
    if inCombat and not combatId then
        self.Orphans[guid] = true
    end
    local jobId = char.Primary
    local own, spill = Rules.ActionJP(jp, Rules.GetJobLevel(cfg, char, jobId), self.Game:CharLevel(guid), weight,
        Rules.HasJPBoost(self.Data, char, self:Cfg()))
    char.Stats.Actions = char.Stats.Actions + 1
    char.SinceRest.Actions = char.SinceRest.Actions + 1
    local rec = combatId and self.Combats[combatId]
    if rec and rec.Chars[guid] then
        rec.Chars[guid].Actions = rec.Chars[guid].Actions + 1
    end
    self:AddJP(guid, jobId, own, "Action", combatId)
    if spill > 0 then
        for _, other in ipairs(self:FightMates(guid, combatId)) do
            local oc = self.State:Get(other)
            if not jp.Spillover.RequireUnlocked or Rules.IsUnlocked(oc, jobId) then
                self:AddJP(other, jobId, spill, "Spill", self.CharCombat[other])
            end
        end
    end
end

---------------------------------------------------------------- combat

function Service:CombatRecord(combatId)
    local rec = self.Combats[combatId]
    if not rec then
        rec = { Id = combatId, Start = self.Clock(), Rounds = 0, Chars = {} }
        self.Combats[combatId] = rec
    end
    return rec
end

function Service:OnCombatStarted(combatId)
    if self.Ready then
        self:CombatRecord(combatId)
    end
end

function Service:OnCombatRoundStarted(combatId, round)
    if self.Ready then
        local rec = self:CombatRecord(combatId)
        if type(round) == "number" and round > rec.Rounds then
            rec.Rounds = round
        end
    end
end

function Service:OnEnteredCombat(object, combatId)
    if not self.Ready or self:IsDisabled() then
        return
    end
    local guid = Util.Guid(object)
    Bosses.OnEnteredCombat(self, guid)
    Souls.OnEnteredCombat(self, guid)
    local char = self.State:Get(guid) or self:EnsureChar(guid)
    if not char then
        return
    end
    local rec = self:CombatRecord(combatId)
    if not rec.Chars[guid] then
        rec.Chars[guid] = { Actions = 0, JP = {}, XPStart = self.Game:TotalXP(guid) }
    end
    self.CharCombat[guid] = combatId
    self.Orphans[guid] = nil
end

function Service:OnTurnStarted(object)
    local guid = Util.Guid(object)
    self.TurnCasts[guid or ""] = 0
    self:OfferEcho(guid)
    self:Accrue(guid)
end

-- Accrue EXP / Accrue JP (Arithmetician movement abilities): a little XP or JP at each turn start in a fight.
function Service:Accrue(guid)
    local char = guid and self.State:Get(guid)
    if not (char and self.Ready and not self:IsDisabled() and self.Game:IsInCombat(guid)) then
        return
    end
    local cfg = self:Cfg()
    if Rules.EquippedEffect(self.Data, char, "AccrueEXP", cfg) then
        self.Game:AddExplorationXP(guid, cfg.Abilities.AccrueEXPPerLevel * self.Game:CharLevel(guid))
    end
    if Rules.EquippedEffect(self.Data, char, "AccrueJP", cfg) then
        self:AddJP(guid, char.Primary, cfg.Abilities.AccrueJPPerTurn, "Accrue", self.CharCombat[guid])
    end
end

function Service:OnTurnEnded(object)
    local guid = Util.Guid(object)
    local char = guid and self.State:Get(guid)
    if not self:IsMime(char) then
        return
    end
    self.EchoSeen[guid] = self.EchoSeq
    if char.Echo then
        char.Echo = nil
        self:Reconcile(guid)
    end
end

---------------------------------------------------------------- Arithmetician: Arithmeticks

-- The user's design: the Arithmetician loads one learned magick and one number on the Job Board; a rule shout then
-- casts the magick's free "_Arith" twin (tools/build.py) at every creature in the fight, friend or foe, whose number
-- fits. FFT's CT / EXP / Elevation become BG3 numbers a player can see: hit points, maximum hit points, distance.
Service.ArithNumbers = { TargetCT = "HP", TargetLevel = "Level", TargetEXP = "MaxHP", TargetElevation = "Distance" }
Service.ArithReach = 30 -- metres: "the fight" around the Arithmetician

local function isPrime(n)
    if n < 2 then
        return false
    end
    for d = 2, math.floor(math.sqrt(n)) do
        if n % d == 0 then
            return false
        end
    end
    return true
end

function Service.ArithFits(rule, n)
    n = math.floor(tonumber(n) or -1)
    if rule == "Prime" then
        return isPrime(n)
    end
    local k = tonumber(rule)
    return k ~= nil and n >= k and n % k == 0
end

-- The learned magicks and numbers this character can load, in Job Board order.
function Service:ArithChoices(char)
    local magicks, numbers = {}, {}
    for _, aid in ipairs(self.Data.AbilityOrder) do
        if Rules.IsLearned(char, aid) then
            if self.Data.ArithMagicks[aid] then
                magicks[#magicks + 1] = aid
            elseif Service.ArithNumbers[aid] then
                numbers[#numbers + 1] = aid
            end
        end
    end
    return magicks, numbers
end

function Service:SetArith(guid, abilityId)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local ab = self.Data.Abilities[abilityId or ""]
    local kind = ab and (self.Data.ArithMagicks[abilityId] and "Magick" or (Service.ArithNumbers[abilityId] and "Number"))
    if not kind then
        return false, "Not an Arithmeticks magick or number: " .. tostring(abilityId)
    end
    if not Rules.IsLearned(char, abilityId) then
        return false, ab.Name .. " is not learned yet"
    end
    char.Arith = char.Arith or {}
    char.Arith[kind] = abilityId
    self.State:MarkDirty()
    return true, "Arithmeticks: " .. ab.Name .. " loaded"
end

function Service:ArithNumber(kind, caster, target)
    if kind == "Level" then
        return self.Game:CharLevel(target)
    elseif kind == "HP" then
        return self.Game:Hitpoints(target)
    elseif kind == "MaxHP" then
        return self.Game:MaxHitpoints(target)
    end
    local d = self.Game:Distance(caster, target)
    return d and math.floor(d)
end

function Service:CastArithmeticks(guid, char, rule)
    local arith = char.Arith or {}
    local magicks, numbers = self:ArithChoices(char)
    local magick = arith.Magick and Rules.IsLearned(char, arith.Magick) and arith.Magick or magicks[1]
    local number = arith.Number and Rules.IsLearned(char, arith.Number) and arith.Number or numbers[1]
    if not (magick and number) then
        self:Notify(guid, "Arithmeticks need a learned magick and a learned number (Target Level, ...); load them on the Job Board.")
        return
    end
    if not self.Game:IsInCombat(guid) then
        self:Notify(guid, "Arithmeticks work in a fight.")
        return
    end
    local kind = Service.ArithNumbers[number]
    local twin = self.Data.ArithMagicks[magick]
    local names = {}
    for _, target in ipairs(self.Game:AllCharacters()) do
        local d = self.Game:Distance(guid, target)
        if d and d <= Service.ArithReach and self.Game:IsInCombat(target) and not self.Game:IsDead(target)
            and Service.ArithFits(rule, self:ArithNumber(kind, guid, target)) then
            self.Game:UseSpell(guid, twin, target)
            names[#names + 1] = self.Game:DisplayName(target) or target
        end
    end
    local what = string.format("%s, %s (%s)", self.Data.Abilities[magick].Name, self.Data.Abilities[number].Name,
        rule == "Prime" and "prime" or ("multiple of " .. rule))
    if #names == 0 then
        self:Notify(guid, "Arithmeticks " .. what .. ": no creature fits.")
    else
        self:Notify(guid, "Arithmeticks " .. what .. ": " .. table.concat(names, ", ") .. ".")
    end
end

---------------------------------------------------------------- Mime: Echo

-- The user's design: on its turn a Mime can repeat the last job ability an ally used since the Mime's previous turn,
-- without that ability's cooldown. Every job action spell has an "_Echo" twin without a cooldown (tools/build.py,
-- Data.Echo); the Mime gets the right twin for its turn (char.Echo, read by Rules.DesiredGrants).
function Service:IsMime(char)
    local job = self.Data.Jobs.Mime
    return char ~= nil and char.Primary == "Mime" and job ~= nil and job.Implemented == true
end

function Service:TrackEcho(guid, char, spell)
    if char.Echo and spell == char.Echo then
        char.Echo = nil -- one echo per turn
        self:Reconcile(guid)
        return
    end
    local echo = self.Data.Echo and self.Data.Echo[spell]
    if echo and self.Game:IsInCombat(guid) then
        self.EchoSeq = self.EchoSeq + 1
        self.LastEcho = { Spell = echo.Spell, Ability = echo.Ability, By = guid, Seq = self.EchoSeq }
    end
end

function Service:OfferEcho(guid)
    local char = guid and self.State:Get(guid)
    local last = self.LastEcho
    if not (self.Ready and not self:IsDisabled() and self:IsMime(char) and last and last.By ~= guid
            and last.Seq > (self.EchoSeen[guid] or 0) and self.Game:IsInCombat(guid)) then
        return
    end
    char.Echo = last.Spell
    self:Reconcile(guid)
    local ab = self.Data.Abilities[last.Ability]
    self:Notify(guid, string.format("Echo ready: %s (this turn only, no cooldown).", ab and ab.Name or last.Ability))
end

function Service:ClearEchoes()
    self.LastEcho = nil
    for _, guid in ipairs(self.State:Guids()) do
        local char = self.State:Get(guid)
        if char.Echo then
            char.Echo = nil
            self:Reconcile(guid)
        end
    end
end

-- Osiris CombatEnded: victory JP for participants still alive, camp share for everyone else, telemetry.
function Service:OnCombatEnded(combatId)
    if not self.Ready then
        return
    end
    self:ClearEchoes()
    Bosses.CheckDefeated(self) -- a boss knocked out or made to surrender in this fight
    local rec = self.Combats[combatId]
    local participants = {}
    if rec then
        for guid, c in pairs(rec.Chars) do
            participants[guid] = c
        end
    end
    for guid in pairs(self.Orphans) do
        if not self.Game:IsInCombat(guid) then
            participants[guid] = participants[guid] or { Actions = 0, JP = {} }
            self.Orphans[guid] = nil
        end
    end
    for guid, cid in pairs(self.CharCombat) do
        if cid == combatId then
            self.CharCombat[guid] = nil
        end
    end
    if next(participants) == nil or self:IsDisabled() then
        self.Combats[combatId] = nil
        return
    end
    self.Combats[combatId] = { Id = combatId, Chars = participants } -- so victory JP is counted in the record
    self.State:Meta().LastFightJobs = Util.SortedKeys(self:FightJobs(combatId))
    local cfg = self:Cfg()
    local jp = cfg.JP
    local guids = Util.SortedKeys(participants)
    local ownSum, ownCount = 0, 0
    for _, guid in ipairs(guids) do
        local char = self.State:Get(guid)
        if char then
            if not self.Game:IsDead(guid) then
                self:AddJP(guid, char.Primary,
                    Rules.VictoryJP(jp, self.Game:CharLevel(guid), Rules.HasJPBoost(self.Data, char, self:Cfg())), "Victory", combatId)
            end
            char.Stats.Combats = char.Stats.Combats + 1
            char.SinceRest.Combats = char.SinceRest.Combats + 1
            local c = participants[guid]
            ownSum = ownSum + (c.JP.Action or 0) + (c.JP.Victory or 0)
            ownCount = ownCount + 1
        end
    end
    self.Combats[combatId] = nil
    local camp = {}
    local campJP = Rules.CampJP(jp, ownCount > 0 and ownSum / ownCount or 0)
    if campJP > 0 then
        for _, guid in ipairs(self.State:Guids()) do
            if not participants[guid] then
                local char = self.State:Get(guid)
                local res = self:AddJP(guid, char.Primary, campJP, "Camp", nil)
                camp[guid] = { name = char.Name, job = char.Primary, jp = res and res.Added or 0 }
            end
        end
    end
    self:PollXP()
    self.State:MarkDirty()
    local chars = {}
    for _, guid in ipairs(guids) do
        local char = self.State:Get(guid)
        local c = participants[guid]
        if char then
            local xpNow = self.Game:TotalXP(guid)
            local gained = (type(xpNow) == "number" and type(c.XPStart) == "number") and (xpNow - c.XPStart) or 0
            if gained > 0 and Rules.EquippedEffect(self.Data, char, "EXPBoost", cfg) then
                self.Game:AddExplorationXP(guid, math.floor(gained * cfg.Abilities.EXPBoostShare))
            end
            chars[guid] = {
                name = char.Name, job = char.Primary, jobLv = Rules.GetJobLevel(cfg, char, char.Primary),
                lvl = self.Game:CharLevel(guid), actions = c.Actions or 0, jp = c.JP,
                xp = (type(xpNow) == "number" and type(c.XPStart) == "number") and (xpNow - c.XPStart) or nil,
            }
        end
    end
    self.Telemetry:Write({
        t = "combat", id = combatId, start = rec and rec.Start, finish = self.Clock(), rounds = rec and rec.Rounds or 0,
        preset = self.Config.Preset, mult = jp.GlobalMultiplier, chars = chars, camp = camp,
    })
end

---------------------------------------------------------------- XP, rests, level-ups

-- XP share: Osiris has no XP event, so TotalExperience is compared with the last reading.
function Service:PollXP()
    if not self.Ready or self:IsDisabled() then
        return
    end
    local jp = self:Cfg().JP
    for _, guid in ipairs(self.State:Guids()) do
        local char = self.State:Get(guid)
        local xp = self.Game:TotalXP(guid)
        if type(xp) == "number" then
            if type(char.LastXP) ~= "number" or xp < char.LastXP then
                char.LastXP = xp
                self.State:MarkDirty()
            elseif xp > char.LastXP then
                local delta = xp - char.LastXP
                char.LastXP = xp
                char.Stats.XP = char.Stats.XP + delta
                char.SinceRest.XP = char.SinceRest.XP + delta
                self:AddJP(guid, char.Primary, Rules.XPJP(jp, delta, Rules.HasJPBoost(self.Data, char, self:Cfg())), "XP",
                    self.CharCombat[guid])
                self.State:MarkDirty()
            end
        end
    end
end

function Service:StartXPPoll()
    self.PollGeneration = self.PollGeneration + 1
    local generation = self.PollGeneration
    local function tick()
        if generation ~= self.PollGeneration then
            return
        end
        self.Log.Safe("XP poll", self.PollXP, self)
        self.WaitFor(math.max(250, self:Cfg().XPPollMs), tick)
    end
    self.WaitFor(math.max(250, self:Cfg().XPPollMs), tick)
end

function Service:OnLongRestFinished()
    if not self.Ready or self:IsDisabled() then
        return
    end
    self:PollXP()
    local jp = self:Cfg().JP
    local chars = {}
    for _, guid in ipairs(self.State:Guids()) do
        local char = self.State:Get(guid)
        self:AddJP(guid, char.Primary, Rules.RestJP(jp, Rules.HasJPBoost(self.Data, char, self:Cfg())), "Rest", nil)
        local s = char.SinceRest
        chars[guid] = {
            name = char.Name, job = char.Primary, lvl = self.Game:CharLevel(guid), xp = s.XP,
            actions = s.Actions, combats = s.Combats, jp = s.JP,
        }
        char.SinceRest = Rules.NewStats()
    end
    self.State:MarkDirty()
    self.Telemetry:Write({ t = "rest", clock = self.Clock(), preset = self.Config.Preset, mult = jp.GlobalMultiplier, chars = chars })
    self:ReconcileAll(true)
end

function Service:OnLeveledUp(character)
    if not self.Ready then
        return
    end
    self:PollXP()
    self:Reconcile(Util.Guid(character), true)
end

---------------------------------------------------------------- job ability effects (Effects.lua)

-- Osiris StatusApplied fires for every status in the game: only this mod's markers go further.
function Service:OnStatusApplied(object, status, causee)
    if not self.Ready or self:IsDisabled() then
        return
    end
    if status == Souls.BRAND then
        Souls.OnStatusApplied(self, Util.Guid(object), status, Util.Guid(causee))
        return
    end
    if not Effects.Handles(status) then
        return
    end
    Effects.OnStatusApplied(self, Util.Guid(object), status, Util.Guid(causee))
end

function Service:OnStatusRemoved(object, status)
    if self.Ready and status == Souls.BRAND then
        Souls.OnStatusRemoved(self, Util.Guid(object), status)
    end
end

function Service:OnAttackedBy(defender, attackerOwner, attacker, damageType, damageAmount)
    if self.Ready and not self:IsDisabled() then
        Effects.OnAttackedBy(self, Util.Guid(defender), damageAmount)
    end
end

function Service:OnKilledBy(defender, attackOwner, attacker)
    if self.Ready and not self:IsDisabled() then
        Effects.OnKilledBy(self, Util.Guid(defender))
        self:CountKill(Util.Guid(defender), Util.Guid(attackOwner), Util.Guid(attacker))
    end
end

-- A party member defeated a creature outside the party (the owner counts for its summons): one more kill toward
-- unlocks that need them (War of the Lions' Dark Knight: 20).
function Service:CountKill(defender, attackOwner, attacker)
    if not defender or self.State:Get(defender) or self.Game:IsPartyMember(defender) then
        return
    end
    local killer = (attackOwner and self.State:Get(attackOwner)) and attackOwner or attacker
    local char = killer and self.State:Get(killer)
    if not char then
        return
    end
    char.Kills = (char.Kills or 0) + 1
    self.State:MarkDirty()
    self:CheckUnlocksNow(killer, char)
end

-- Unlocks what a character's requirements now allow (after a kill or a mastery: JP gains check in Rules.AddJP) and
-- announces it. Returns the newly unlocked job ids.
function Service:CheckUnlocksNow(guid, char)
    local unlocked = Rules.CheckUnlocks(self.Data, self:Cfg(), char)
    for _, jobId in ipairs(unlocked) do
        if self:Cfg().Notifications.Unlock then
            self:Notify(guid, string.format("%s unlocked the %s job!", char.Name, self.Data.Jobs[jobId].Name))
        end
    end
    if #unlocked > 0 then
        self.State:MarkDirty()
        self:SyncParty()
    end
    return unlocked
end

function Service:OnCharacterJoinedParty(character)
    if not self.Ready then
        return
    end
    local guid = Util.Guid(character)
    self.NotTrackable[guid] = nil -- a recruited NPC
    if self:EnsureChar(guid) then
        self:Reconcile(guid, true)
    end
    Bosses.OnJoined(self, guid) -- a boss who joins hands over its badge (Minthara)
end

-- Boss badges (Bosses.lua): a boss died; who meets whom in dialogs.
function Service:OnDied(character)
    Bosses.OnDied(self, Util.Guid(character))
    if self.Ready and not self:IsDisabled() then
        Souls.OnDied(self, Util.Guid(character))
    end
end

function Service:OnDialogActorJoined(dialog, instance, actor)
    Bosses.OnDialogActor(self, instance, Util.Guid(actor))
end

function Service:OnDialogEnded(dialog, instance)
    Bosses.OnDialogEnded(self, instance)
end

---------------------------------------------------------------- player choices (Job Board, console)

function Service:CheckChar(guid)
    if not self.Ready then
        return nil, "The job system has not loaded yet"
    end
    local char = guid and self.State:Get(guid)
    if not char then
        return nil, "Not a tracked party member"
    end
    return char
end

function Service:CombatBlock(guid, ruleKey, what)
    if self:Cfg().Rules[ruleKey] and self.Game:IsInCombat(guid) then
        return "Can't " .. what .. " during combat"
    end
    return nil
end

function Service:SetPrimary(guid, jobId)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local block = self:CombatBlock(guid, "ChangeJobOutOfCombatOnly", "change jobs")
    if block then
        return false, block
    end
    local ok, e = Rules.SetPrimary(self.Data, char, jobId)
    if not ok then
        return false, e
    end
    self.State:MarkDirty()
    self:Reconcile(guid, false)
    return true, string.format("%s is now a %s%s", char.Name, self.Data.Jobs[jobId].Name,
        usableText(self:LearnedActions(char, jobId)))
end

function Service:SetSecondary(guid, jobId)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local block = self:CombatBlock(guid, "SlotsOutOfCombatOnly", "change the secondary skill set")
    if block then
        return false, block
    end
    local ok, e = Rules.SetSecondary(self.Data, char, jobId)
    if not ok then
        return false, e
    end
    self.State:MarkDirty()
    self:Reconcile(guid, false)
    if jobId == nil then
        return true, char.Name .. ": secondary skill set cleared"
    end
    local job = self.Data.Jobs[jobId]
    return true, string.format("%s: secondary skill set %s (%s)%s", char.Name, job.Skillset, job.Name,
        usableText(self:LearnedActions(char, jobId)))
end

function Service:Learn(guid, abilityId)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local block = self:CombatBlock(guid, "LearnOutOfCombatOnly", "learn abilities")
    if block then
        return false, block
    end
    local ok, e, info = Rules.Learn(self.Data, char, abilityId)
    if not ok then
        return false, e
    end
    self.State:MarkDirty()
    self:Reconcile(guid, false)
    local ab = self.Data.Abilities[abilityId]
    local job = self.Data.Jobs[ab.Job]
    local cfg = self:Cfg()
    -- whole sentences, joined with spaces (a perk text ends with its own full stop)
    local parts = { string.format("%s learned %s (%s).", char.Name, ab.Name, job.Name) }
    if ab.Type ~= "Action" and Rules.IsAlwaysOn(self.Data, cfg, char, abilityId) then
        parts[#parts + 1] = string.format("It works without a slot while %s is the job; with other jobs, equip it in %s.",
            job.Name, slotHint(ab.Type))
    elseif ab.Type ~= "Action" then
        parts[#parts + 1] = string.format("Equip it in %s to use it.", slotHint(ab.Type))
    elseif ab.Job == char.Primary or ab.Job == char.Secondary then
        parts[#parts + 1] = string.format("Added to %s's spells.", char.Name)
    else
        parts[#parts + 1] = string.format("To use it, make %s %s's job or secondary.", job.Name, char.Name)
    end
    if info.Mastered then
        local perk = Rules.HasMasteryPerk(self.Data, cfg, char, ab.Job) and job.Mastery.Description or nil
        parts[#parts + 1] = job.Name .. " mastered!" .. (perk and (" Mastery perk, kept for good: " .. perk) or "")
        if cfg.Notifications.Mastered then
            self:Notify(guid, string.format("%s mastered %s!%s", char.Name, job.Name, perk and (" " .. perk) or ""))
        end
        self:CheckUnlocksNow(guid, char) -- jobs that need this one mastered (Dark Knight)
    end
    return true, table.concat(parts, " ")
end

-- slot (optional): "reaction", "1" or "2" (Rules.SlotName); otherwise the first free slot of the right kind.
function Service:Equip(guid, abilityId, slot)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local block = self:CombatBlock(guid, "SlotsOutOfCombatOnly", "change abilities")
    if block then
        return false, block
    end
    local ok, e, s = Rules.Equip(self.Data, char, abilityId, slot)
    if not ok then
        return false, e
    end
    self.State:MarkDirty()
    self:Reconcile(guid, false)
    return true, string.format("%s: %s slot = %s", char.Name, Rules.SlotLabels[s], self.Data.Abilities[abilityId].Name)
end

function Service:Unequip(guid, slot)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local block = self:CombatBlock(guid, "SlotsOutOfCombatOnly", "change abilities")
    if block then
        return false, block
    end
    local ok, e, s = Rules.Unequip(char, slot)
    if not ok then
        return false, e
    end
    self.State:MarkDirty()
    self:Reconcile(guid, false)
    return true, string.format("%s: %s slot cleared", char.Name, Rules.SlotLabels[s])
end

function Service:AddManualJP(guid, amount, jobId)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    jobId = jobId or char.Primary
    if type(amount) ~= "number" or amount <= 0 then
        return false, "Amount must be a positive number"
    end
    local res = self:AddJP(guid, jobId, amount, "Manual", nil)
    if not res then
        return false, "JP is paused (!fft_enable to resume)"
    end
    local js = char.Jobs[jobId]
    return true, string.format("%s +%s JP in %s (now %s to spend, job level %d)", char.Name, Util.Num(res.Added),
        self.Data.Jobs[jobId].Name, Util.Num(js.Unspent), res.LevelAfter)
end

function Service:UnlockAll(guid)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    Rules.UnlockAll(self.Data, char)
    self.State:MarkDirty()
    self:SyncParty()
    return true, char.Name .. ": every implemented job unlocked"
end

-- The party found a badge (from a boss: Bosses.lua, with a reason sentence first; !fft_badge for testing).
-- Returns ok, message.
function Service:AddBadge(badgeId, finder, reason)
    if not self.Ready then
        return false, "The job system has not loaded yet"
    end
    local cfg = self:Cfg()
    local ok, err, info = Rules.AddBadge(self.Data, cfg, self.State:Chars(), self.State:Meta(), badgeId)
    if not ok then
        return false, err
    end
    self.State:MarkDirty()
    local name = Rules.BadgeName(self.Data, badgeId)
    if info.Already then
        return true, "The party already has the " .. name
    end
    local parts = { "The party found the " .. name }
    local names, order = {}, {}
    for _, p in ipairs(info.Unlocked) do
        if not names[p.Job] then
            names[p.Job] = {}
            order[#order + 1] = p.Job
        end
        local list = names[p.Job]
        list[#list + 1] = self.State:Get(p.Guid).Name or p.Guid
    end
    for _, jobId in ipairs(order) do
        parts[#parts + 1] = string.format("%s unlocked the %s job", table.concat(names[jobId], ", "),
            self.Data.Jobs[jobId].Name)
    end
    local msg = table.concat(parts, ". ") .. "!"
    if reason then
        msg = reason .. " " .. msg
    end
    local target = finder or self.Game:HostCharacter()
    if target and cfg.Notifications.Unlock then
        self:Notify(target, msg)
    else
        self.Log.Info(msg)
    end
    return true, msg
end

-- Testing tool (JP Training spell, !fft_train): every party member gets amount JP (default Test.JPPerCast) in each
-- job unlocked before the call; jobs it unlocks get JP from the next call. Level-up and unlock notices only go to
-- the console; caster (optional) gets one summary notification. Returns ok, message.
function Service:TrainParty(caster, amount)
    if not self.Ready then
        return false, "The job system has not loaded yet"
    end
    if self:IsDisabled() then
        return false, "JP is paused (!fft_enable to resume)"
    end
    amount = amount or self:Cfg().Test.JPPerCast
    if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
        return false, "Amount must be a positive number"
    end
    self:DiscoverParty()
    local guids = self.State:Guids()
    -- the jobs are listed for everyone first: with party-wide unlocks, a job unlocked during this cast reaches the
    -- others at once, and it should get JP from the next cast for them too
    local plan = {}
    for _, guid in ipairs(guids) do
        local char = self.State:Get(guid)
        local jobs = {}
        for _, jobId in ipairs(self.Data.JobOrder) do
            if self.Data.Jobs[jobId].Implemented and Rules.IsUnlocked(char, jobId) then
                jobs[#jobs + 1] = jobId
            end
        end
        plan[guid] = jobs
    end
    local unlocks = 0
    self.Quiet = true
    local ok, err = pcall(function()
        for _, guid in ipairs(guids) do
            for _, jobId in ipairs(plan[guid]) do
                local res = self:AddJP(guid, jobId, amount, "Test", nil)
                unlocks = unlocks + (res and #res.Unlocked or 0)
            end
        end
    end)
    self.Quiet = false
    if not ok then
        error(err, 0)
    end
    local msg = string.format("JP Training: +%s JP in every unlocked job for %d party member%s", Util.Num(amount),
        #guids, #guids == 1 and "" or "s")
    if unlocks > 0 then
        msg = msg .. string.format(", %d new job%s unlocked", unlocks, unlocks == 1 and "" or "s")
    end
    if caster then
        self:Notify(caster, msg)
    end
    return true, msg
end

function Service:ResetChar(guid)
    local char, err = self:CheckChar(guid)
    if not char then
        return false, err
    end
    local name = char.Name
    Grants.RemoveAll(self.Game, guid, char)
    self.State:Remove(guid)
    local fresh = self:EnsureChar(guid)
    if not fresh then
        return true, name .. " reset (no longer tracked)"
    end
    return true, string.format("%s reset to a fresh %s", name, self.Data.Jobs[fresh.Primary].Name)
end

-- Uninstall helper: removes every granted spell/passive/status and pauses the system until enabled again.
function Service:SetDisabled(disabled)
    if not self.Ready then
        return false, "The job system has not loaded yet"
    end
    self.State:Meta().Disabled = disabled and true or false
    self.State:MarkDirty()
    self:ReconcileAll(false)
    self.State:Flush()
    if disabled then
        return true, "Removed everything the job system granted and paused it. Save now; then the mod can be removed. "
            .. "!fft_enable turns it back on."
    end
    return true, "Job system enabled again"
end

function Service:OpenBoard(guid)
    if self.OnOpenBoard then
        self.OnOpenBoard(guid)
        return true, "Job Board opened"
    end
    return false, "The Job Board window is not available (client side not loaded)"
end

---------------------------------------------------------------- lookups and text

-- who: nil/"host"/"me", a GUID, or (part of) a party member's name.
function Service:ResolveWho(who)
    if not self.Ready then
        return nil, "The job system has not loaded yet"
    end
    local w = who and Util.Trim(who) or ""
    if w == "" or string.lower(w) == "host" or string.lower(w) == "me" then
        local host = self.Game:HostCharacter()
        if host and (self.State:Get(host) or self:EnsureChar(host)) then
            return host
        end
        return nil, "No host character found"
    end
    local g = Util.Guid(w)
    if g and self.State:Get(g) then
        return g
    end
    local n = Util.Normalize(w)
    local prefix
    for _, guid in ipairs(self.State:Guids()) do
        local name = Util.Normalize(self.State:Get(guid).Name)
        if name == n then
            return guid
        end
        if not prefix and n ~= "" and string.find(name, n, 1, true) == 1 then
            prefix = guid
        end
    end
    if prefix then
        return prefix
    end
    return nil, "No party member called " .. w .. " (see !fft_party)"
end

local function slotText(data, char, slot)
    local id = char[slot]
    return id and data.Abilities[id] and data.Abilities[id].Name or "-"
end

function Service:SummaryLine(guid)
    local char = self.State:Get(guid)
    local cfg = self:Cfg()
    local data = self.Data
    local js = char.Jobs[char.Primary] or {}
    local secondary = char.Secondary and data.Jobs[char.Secondary] and data.Jobs[char.Secondary].Skillset or "-"
    return string.format("%s: %s Lv%d (%s JP to spend) | Secondary %s | Reaction %s | Passive 1 %s | Passive 2 %s",
        char.Name, data.Jobs[char.Primary].Name, Rules.GetJobLevel(cfg, char, char.Primary), Util.Num(js.Unspent or 0),
        secondary, slotText(data, char, "Reaction"), slotText(data, char, "Passive1"), slotText(data, char, "Passive2"))
end

function Service:Describe(guid)
    local char = self.State:Get(guid)
    local cfg = self:Cfg()
    local data = self.Data
    local lines = { self:SummaryLine(guid) }
    for _, jobId in ipairs(data.JobOrder) do
        local job = data.Jobs[jobId]
        if job.Implemented then
            local js = char.Jobs[jobId]
            local earned = js and js.Earned or 0
            local unlocked = Rules.IsUnlocked(char, jobId)
            local next = Rules.NextThreshold(earned, cfg.JobLevels.Thresholds)
            local learned = {}
            for _, aid in ipairs(data.AbilitiesByJob[jobId]) do
                if Rules.IsLearned(char, aid) then
                    learned[#learned + 1] = data.Abilities[aid].Name
                end
            end
            local status
            if not unlocked then
                status = "locked (needs " .. Rules.RequirementText(data, jobId) .. ")"
            elseif Rules.IsMastered(data, char, jobId, cfg) then
                status = "MASTERED" .. (Rules.HasMasteryPerk(data, cfg, char, jobId)
                    and (" (perk: " .. job.Mastery.Description .. ")") or "")
            else
                status = string.format("%d/%d learned", #learned, #data.AbilitiesByJob[jobId])
            end
            lines[#lines + 1] = string.format("  %-11s Lv%d  %s JP to spend, %s earned%s  %s%s", job.Name,
                Rules.JobLevel(earned, cfg.JobLevels.Thresholds), Util.Num(js and js.Unspent or 0), Util.Num(earned),
                next and (" (next level at " .. Util.Num(next) .. ")") or "", status,
                #learned > 0 and (": " .. table.concat(learned, ", ")) or "")
        end
    end
    local badges = {}
    for _, id in ipairs(data.BadgeOrder or {}) do
        if Rules.HasBadge(char, id) then
            badges[#badges + 1] = Rules.BadgeName(data, id)
        end
    end
    if #badges > 0 then
        lines[#lines + 1] = "  Badges: " .. table.concat(badges, ", ")
    end
    return lines
end

return Service
