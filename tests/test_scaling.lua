-- 1.0.0.56: Poisoned/Acid tick damage (everyone), character-creation placeholders, highest-ability scaling (build).
local S = {}

local function read(Mocks, file)
    local f = assert(io.open(Mocks.Root .. "/Mod/Public/FFTJobs/Stats/Generated/Data/" .. file, "rb"))
    local s = f:read("a")
    f:close()
    return (s:gsub("\r", ""))
end

local function entry(text, name)
    return text:match('new entry "' .. name:gsub("%p", "%%%0") .. '"\n(.-)\n\n') or ""
end

function S.poisoned_and_acid_deal_damage_at_turn_start(w, T)
    T.boot(w)
    local Effects = Ext.Require("Server/Effects.lua")
    Effects.Roll = function(n)
        return n
    end
    local hp = w.chars[T.TAV].hp
    w.chars[T.TAV].statuses.POISONED = true
    w.chars[T.TAV].statuses.ACID = true
    w.fire("TurnStarted", "S_Player_" .. T.TAV)
    T.eq(w.chars[T.TAV].hp, hp - 8, "1d4 poison + 1d4 acid, highest roll")
    w.chars[T.TAV].statuses.POISONED = nil
    w.chars[T.TAV].statuses.ACID = nil
    w.chars[T.TAV].statuses.POTION_OF_POISON = true -- built on POISONED in vanilla: no tick
    w.fire("TurnStarted", "S_Player_" .. T.TAV)
    T.eq(w.chars[T.TAV].hp, hp - 8)
end

function S.ticks_follow_the_config(w, T)
    T.boot(w, { extra = { Abilities = { PoisonTickDie = 0 } } })
    local hp = w.chars[T.TAV].hp
    w.chars[T.TAV].statuses.POISONED = true
    w.fire("TurnStarted", "S_Player_" .. T.TAV)
    T.eq(w.chars[T.TAV].hp, hp, "0 = off")
end

function S.character_creation_placeholders_are_not_tracked(w, T)
    T.party(w)
    w.newChar("55555555-5555-4555-8555-555555555555", { name = "Dummy", level = 1, xp = 0, class = "Fighter", party = false })
    local svc = T.boot(w, { noParty = true, level = "SYS_CC_I" })
    T.eq(#svc.State:Guids(), 0, "nothing tracked in character creation")
    w.fire("LevelGameplayStarted", "TUT_Avernus_C", 0)
    w.tick()
    T.truthy(svc.State:Get(T.TAV))
    T.falsy(svc.State:Get("55555555-5555-4555-8555-555555555555"), "a Dummy outside the party stays out")
end

function S.leftover_placeholders_are_forgotten_and_fft_forget_works(w, T)
    local svc = T.boot(w)
    local dummy = "55555555-5555-4555-8555-555555555555"
    w.newChar(dummy, { name = "Dummy", level = 1, xp = 0, class = "Fighter", party = false })
    local Rules = Ext.Require("Server/Rules.lua")
    svc.State:Set(dummy, Rules.NewChar(svc.Data, svc:Cfg(), "Squire")) -- tracked by an older version
    svc.State:Get(dummy).Name = "Dummy"
    svc:StartGameplay()
    T.falsy(svc.State:Get(dummy), "forgotten on the next load")
    T.truthy(svc.State:Meta().Forgotten[dummy])
    T.contains(table.concat(w.console("fft_forget", "astarion"), " "), "No longer tracked: Astarion")
    T.falsy(svc.State:Get(T.ASTA))
    svc:DiscoverParty()
    T.falsy(svc.State:Get(T.ASTA), "a forgotten character is not tracked again")
end

function S.job_skills_add_the_highest_modifier_items_stay_flat(w, T, Mocks)
    local text = read(Mocks, "Spell_FFTJ.txt")
    local best = "max(max(max(StrengthModifier,DexterityModifier),max(ConstitutionModifier,IntelligenceModifier)),max(WisdomModifier,CharismaModifier))"
    T.contains(entry(text, "Projectile_FFTJ_Fire"), "DealDamage(1d8+" .. best .. ",Fire")
    T.contains(entry(text, "Target_FFTJ_Cure"), "RegainHitPoints(1d8+3+" .. best .. ")")
    T.contains(entry(text, "Target_FFTJ_Potion"), 'RegainHitPoints(1d4+2)"', "Chemist items: flat")
    T.falsy(entry(text, "Target_FFTJ_HiPotion"):find("max(", 1, true), "Chemist items: flat")
    T.falsy(entry(text, "Target_FFTJ_Rush"):find(best, 1, true), "weapon damage keeps the weapon's ability")
    T.contains(entry(text, "Projectile_FFTJ_ChemicalMixup"), "IsSpell", "flasks take Metamagic (Twinned)")
end

return S
