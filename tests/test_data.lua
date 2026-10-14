-- Generated data vs. stats vs. localization, checked from Lua (the build also checks the first two).
local S = {}

-- Reads a text file with its line endings normalized: a Windows checkout with core.autocrlf=true has CRLF,
-- and a trailing "\r" would break the line patterns below.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("a")
    f:close()
    return (s:gsub("\r", ""))
end

local function statsEntries(Mocks)
    local entries = {}
    for _, file in ipairs({ "Spell_FFTJ.txt", "Passive_FFTJ.txt", "Status_FFTJ.txt", "Spell_FFTJ_Soul.txt",
        "Status_FFTJ_Soul.txt", "Spell_FFTJ_Upcast.txt", "Status_FFTJ_Upcast.txt" }) do
        local text = read(Mocks.Root .. "/Mod/Public/FFTJobs/Stats/Generated/Data/" .. file)
        local cur
        for line in text:gmatch("[^\n]+") do
            local name = line:match('^new entry "([^"]+)"')
            if name then
                cur = { name = name, data = {} }
                entries[name] = cur
            end
            local typ = line:match('^type "([^"]+)"')
            if typ and cur then
                cur.type = typ
            end
            local k, v = line:match('^data "([^"]+)" "(.*)"$')
            if k and cur then
                cur.data[k] = v
            end
        end
    end
    return entries
end

function S.every_grant_has_a_stats_entry_of_the_right_type(w, T, Mocks)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local entries = statsEntries(Mocks)
    local want = { Spells = "SpellData", Passives = "PassiveData", Statuses = "StatusData" }
    local function check(grants, owner)
        for kind, list in pairs(grants or {}) do
            for _, id in ipairs(list) do
                T.truthy(entries[id], owner .. " grants " .. id .. " which has no stats entry")
                T.eq(entries[id].type, want[kind], id)
            end
        end
    end
    for id, ab in pairs(Data.Abilities) do
        check(ab.Grants, id)
        for _, v in ipairs(ab.Variants or {}) do
            check(v.Grants, id .. " variant")
        end
    end
    for id, job in pairs(Data.Jobs) do
        if job.Implemented then
            check(job.Innate, id)
            check(job.Mastery and job.Mastery.Grants, id .. " mastery")
        end
    end
    T.eq(entries[Data.JobBoardSpell].type, "SpellData")
end

-- Fell Seal rules: every job has its main-job equipment (on its marker passive) and a mastery perk.
function S.every_job_has_equipment_and_a_mastery_perk(w, T, Mocks)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local entries = statsEntries(Mocks)
    for _, id in ipairs(Data.JobOrder) do
        local job = Data.Jobs[id]
        if job.Implemented and id == "Mime" then
            T.eq(job.Equip, "", "FFT's Mime equips nothing")
        elseif job.Implemented then
            T.truthy(job.Equip ~= "", id .. " has an equip list")
            local marker = entries[job.Innate.Passives[1]]
            T.contains(marker.data.Boosts or "", "Proficiency(", id .. " marker passive grants proficiencies")
        end
        if job.Implemented then
            T.truthy(job.Mastery and job.Mastery.Description ~= "", id .. " has a mastery perk")
            local perk = entries[job.Mastery.Grants.Passives[1]]
            T.truthy(perk.data.Boosts and perk.data.Boosts ~= "", id .. " mastery passive has boosts")
        end
    end
end

function S.every_localization_handle_exists(w, T, Mocks)
    local entries = statsEntries(Mocks)
    local xml = read(Mocks.Root .. "/Mod/Localization/English/FFTJobs.xml")
    local handles = {}
    for h in xml:gmatch('contentuid="([^"]+)"') do
        handles[h] = true
    end
    local n = 0
    for name, e in pairs(entries) do
        for _, key in ipairs({ "DisplayName", "Description" }) do
            local v = e.data[key]
            if v then
                local h = v:match("^(h[%x]+g[%x]+g[%x]+g[%x]+g[%x]+);1$")
                T.truthy(h, name .. "." .. key .. " is not a handle;version: " .. v)
                T.truthy(handles[h], name .. "." .. key .. " handle missing from FFTJobs.xml")
                n = n + 1
            end
        end
    end
    T.truthy(n >= 150, "handles checked: " .. n)
end

-- Our icons (FFTJ_Icon_<key>) must be in the generated atlas, and every atlas entry must have its picture.
function S.every_custom_icon_is_in_the_atlas(w, T, Mocks)
    local f = io.open(Mocks.Root .. "/Mod/Public/FFTJobs/GUI/Icons_FFTJobs.lsx", "rb")
    if not f then
        return -- no art yet: every entry keeps its borrowed vanilla icon
    end
    local lsx = f:read("a"):gsub("\r", "")
    f:close()
    local atlas, n = {}, 0
    for key in lsx:gmatch('id="MapKey" type="FixedString" value="FFTJ_Icon_([^"]+)"') do
        atlas[key] = true
        n = n + 1
        local pic = io.open(Mocks.Root .. "/art/icons/" .. key .. ".jpg", "rb")
            or io.open(Mocks.Root .. "/art/icons/" .. key .. ".png", "rb")
        T.truthy(pic, "atlas entry " .. key .. " has no art/icons picture")
        pic:close()
    end
    T.truthy(n > 0, "atlas lists no icons")
    local used = 0
    for name, e in pairs(statsEntries(Mocks)) do
        local key = (e.data.Icon or ""):match("^FFTJ_Icon_(.+)$")
        if key then
            T.truthy(atlas[key], name .. " uses icon FFTJ_Icon_" .. key .. ", which is not in the atlas")
            used = used + 1
        end
    end
    T.truthy(used > 0, "no stats entry uses a custom icon")
end

function S.mvp_covers_every_ability_type(w, T)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local types = {}
    for _, ab in pairs(Data.Abilities) do
        types[ab.Type] = (types[ab.Type] or 0) + 1
    end
    T.truthy(types.Action > 0 and types.Reaction > 0 and types.Support > 0 and types.Movement > 0)
end

function S.mastery_totals_and_unlocks_match_design(w, T)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    -- Archer = the Fell Seal Ranger since 1.0.0.66 (AP x 2.5 = 5250, + Equip Bows 350)
    -- WhiteMage: Regenerate (400) -> the Fell Seal Mender skills Renew 500, Mana Font 440, Blessed One 440, Rebirth 875
    local expected = { Squire = 1470, Chemist = 4990, Knight = 2900, Archer = 5600, WhiteMage = 6525, BlackMage = 5200 }
    for job, total in pairs(expected) do
        local sum = 0
        for _, aid in ipairs(Data.AbilitiesByJob[job]) do
            sum = sum + Data.Abilities[aid].Cost
            T.eq(Data.Abilities[aid].Job, job)
        end
        T.eq(sum, total, job .. " JP to master")
    end
    local function req(job)
        local r = Data.Jobs[job].Unlock[1]
        return r and (r.Job .. r.Level) or "start"
    end
    T.eq(req("Squire"), "start")
    T.eq(req("Chemist"), "start")
    T.eq(req("Knight"), "Squire2")
    T.eq(req("Archer"), "Squire2")
    T.eq(req("WhiteMage"), "Chemist2")
    T.eq(req("BlackMage"), "Chemist2")
    T.eq(#Data.Jobs.Mime.Unlock, 6, "the full TIC tree is in the data")
    local tic = 0
    for _, id in ipairs(Data.JobOrder) do
        if Data.Jobs[id].Group == "" then
            tic = tic + 1
        end
    end
    T.eq(tic, 20, "the 20 TIC jobs; War of the Lions and special jobs carry a group")
    T.eq(Data.Jobs.DarkKnight.Group, "WotL")
end

function S.config_defaults_are_consistent(w, T)
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local d = Data.ConfigDefaults
    T.eq(#d.JobLevels.Thresholds, 7)
    for i = 2, 7 do
        T.truthy(d.JobLevels.Thresholds[i] > d.JobLevels.Thresholds[i - 1])
    end
    for _, j in ipairs(d.Rules.StartingUnlocked) do
        T.truthy(Data.Jobs[j].Implemented, j)
    end
    T.truthy(Data.Presets[Data.DefaultPreset])
    for _, name in ipairs(Data.PresetOrder) do
        T.truthy(Data.Presets[name].Description ~= "", name .. " has a description")
    end
end

return S
