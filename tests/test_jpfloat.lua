-- NWP 10: "+N JP" floats above the head when the main job gains JP (tools/jpfloat.py, Service:FloatJP).
local S = {}

local function floats(w, guid)
    local out = {}
    for _, c in ipairs(w.osiCalls) do
        if c[1] == "ApplyStatus" and c[2] == guid and string.sub(c[3], 1, 12) == "FFTJ_JPGAIN_" then
            out[#out + 1] = c[3] .. "@" .. tostring(c[4])
        end
    end
    return table.concat(out, ",")
end

local function count(w, name, guid, status)
    local n = 0
    for _, c in ipairs(w.osiCalls) do
        if c[1] == name and c[2] == guid and c[3] == status then
            n = n + 1
        end
    end
    return n
end

function S.float_amounts_match_the_generated_statuses(w, T, Mocks)
    local Rules = Ext.Require("Server/Rules.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local f = Data.JPFloat
    T.eq(Rules.JPFloatAmount(f, 1), 1)
    T.eq(Rules.JPFloatAmount(f, 200), 200)
    T.eq(Rules.JPFloatAmount(f, 204), 200, "just above the exact range rounds down to it")
    T.eq(Rules.JPFloatAmount(f, 205), 210)
    T.eq(Rules.JPFloatAmount(f, 996), 1000)
    T.eq(Rules.JPFloatAmount(f, 5000), 1000, "capped (shown as +1000+ JP)")
    local fh = assert(io.open(Mocks.Root .. "/Mod/Public/FFTJobs/Stats/Generated/Data/Status_FFTJ_JPGain.txt", "rb"))
    local text = fh:read("a")
    fh:close()
    for n = 1, 1200 do
        local status = f.Prefix .. Rules.JPFloatAmount(f, n)
        T.truthy(string.find(text, 'new entry "' .. status .. '"', 1, true), status .. " exists for " .. n)
    end
end

function S.main_job_gains_float_and_other_jobs_stay_quiet(w, T)
    local svc = T.boot(w)
    T.eq(svc.State:Get(T.TAV).Primary, "Squire")
    svc:AddManualJP(T.TAV, 25, "Squire")
    T.eq(floats(w, T.TAV), "FFTJ_JPGAIN_25@6", "+25 JP for one turn")
    svc:AddManualJP(T.TAV, 30, "Chemist")
    T.eq(floats(w, T.TAV), "FFTJ_JPGAIN_25@6", "JP into another job does not float")
    svc:AddManualJP(T.TAV, 25, "Squire")
    T.eq(count(w, "RemoveStatus", T.TAV, "FFTJ_JPGAIN_25"), 1, "the same amount again: the old one goes first")
    T.eq(count(w, "ApplyStatus", T.TAV, "FFTJ_JPGAIN_25"), 2)
end

function S.combat_action_jp_floats_over_the_caster(w, T)
    local svc = T.boot(w)
    T.startCombat(w, "fight", { T.TAV, T.SHART })
    T.cast(w, T.TAV, "Target_MainHandAttack")
    local gained = T.job(svc, T.TAV, "Squire").Earned
    T.truthy(gained > 0)
    T.eq(floats(w, T.TAV), "FFTJ_JPGAIN_" .. gained .. "@6")
end

function S.switch_off_shows_nothing(w, T)
    local svc = T.boot(w, { extra = { Notifications = { JPOverhead = false } } })
    svc:AddManualJP(T.TAV, 25, "Squire")
    T.eq(floats(w, T.TAV), "")
end

return S
