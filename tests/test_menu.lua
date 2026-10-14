-- Job menus in BG3's own UI (tools/menu_gen.py): which menu spells a character gets, what casting them does, and the
-- JP lines for the Learn tooltips.
local S = {}

local function spells(w, guid)
    return w.chars[guid].spells
end

function S.menus_follow_unlocks_and_learning(w, T)
    local svc = T.boot(w)
    local sp = spells(w, T.TAV)
    for _, id in ipairs({ "Shout_FFTJ_ChangeJob", "Shout_FFTJ_SecondaryJob", "Shout_FFTJ_SecondaryJob_None",
        "Shout_FFTJ_ChangeJob_Squire", "Shout_FFTJ_ChangeJob_Chemist", "Shout_FFTJ_SecondaryJob_Chemist",
        "Shout_FFTJ_ChangeJob_Knight_Locked", "Shout_FFTJ_SecondaryJob_DarkKnight_Locked",
        "Shout_FFTJ_LearnFrom_Squire", "Shout_FFTJ_Learn_Focus" }) do
        T.truthy(sp[id], id)
    end
    T.falsy(sp.Shout_FFTJ_ChangeJob_Knight, "locked regular job: only the ??? entry")
    T.falsy(sp.Shout_FFTJ_ChangeJob_Cleric, "locked special job: not listed")
    T.falsy(sp.Shout_FFTJ_ChangeJob_Cleric_Locked, "locked special job: not listed")
    T.falsy(sp.Shout_FFTJ_ChangeJob_SoulCollector, "Soul Collector stays on the Job Board (NWP)")
    T.falsy(sp.Shout_FFTJ_LearnFrom_Chemist, "Learn menus only for the job and the secondary")
    svc:AddManualJP(T.TAV, 300, "Squire")
    T.cast(w, T.TAV, "Shout_FFTJ_Learn_Focus")
    T.truthy(svc.State:Get(T.TAV).Jobs.Squire.Learned.Focus, "casting a Learn entry learns it")
    T.eq(svc.State:Get(T.TAV).Jobs.Squire.Unspent, 0)
    T.falsy(sp.Shout_FFTJ_Learn_Focus, "a learned ability leaves the menu")
    T.truthy(sp.Shout_FFTJ_Focus)
    T.contains(w.notifications, "Tav learned Focus (Squire).")
    svc:UnlockAll(T.TAV)
    T.truthy(sp.Shout_FFTJ_ChangeJob_Knight, "unlocked: the real entry")
    T.falsy(sp.Shout_FFTJ_ChangeJob_Knight_Locked)
end

function S.casting_menu_entries_changes_jobs(w, T)
    local svc = T.boot(w)
    local sp = spells(w, T.TAV)
    T.cast(w, T.TAV, "Shout_FFTJ_ChangeJob_Chemist")
    T.eq(svc.State:Get(T.TAV).Primary, "Chemist")
    T.truthy(sp.Shout_FFTJ_LearnFrom_Chemist)
    T.falsy(sp.Shout_FFTJ_LearnFrom_Squire)
    T.cast(w, T.TAV, "Shout_FFTJ_SecondaryJob_Squire")
    T.eq(svc.State:Get(T.TAV).Secondary, "Squire")
    T.truthy(sp.Shout_FFTJ_LearnFrom_Squire, "the secondary's Learn menu")
    T.cast(w, T.TAV, "Shout_FFTJ_SecondaryJob_None")
    T.eq(svc.State:Get(T.TAV).Secondary, nil)
    T.falsy(sp.Shout_FFTJ_LearnFrom_Squire)
end

function S.refusals_are_notified_and_menus_give_no_jp(w, T)
    local svc = T.boot(w)
    local before = T.job(svc, T.TAV, "Squire").Earned
    T.cast(w, T.TAV, "Shout_FFTJ_Learn_Focus")
    T.contains(w.notifications, "Not done: Focus needs 300 JP in Squire (you have 0)")
    T.cast(w, T.TAV, "Shout_FFTJ_ChangeJob_Knight_Locked")
    T.contains(w.notifications, "Not done: Knight is still locked")
    T.cast(w, T.TAV, "Shout_FFTJ_ChangeJob")
    T.eq(T.job(svc, T.TAV, "Squire").Earned, before, "menu casts earn no JP")
    w.chars[T.TAV].inCombat = true
    T.cast(w, T.TAV, "Shout_FFTJ_ChangeJob_Chemist")
    T.eq(svc.State:Get(T.TAV).Primary, "Squire")
    T.contains(w.notifications, "Not done: Can't change jobs during combat")
end

function S.menu_jp_is_sent_when_it_changes(w, T)
    local svc = T.boot(w)
    local sent = {}
    svc.OnMenuJP = function(p)
        sent[#sent + 1] = p
    end
    svc.LastMenuJP = nil
    svc:PushMenuJP()
    T.eq(#sent, 1)
    T.eq(sent[1].Chars[T.TAV].Name, "Tav")
    T.eq(sent[1].Chars[T.TAV].JP.Squire, 0)
    svc:PushMenuJP()
    T.eq(#sent, 1, "nothing changed, nothing sent")
    svc:AddManualJP(T.TAV, 120, "Squire")
    svc:PushMenuJP()
    T.eq(#sent, 2)
    T.eq(sent[2].Chars[T.TAV].JP.Squire, 120)
    T.eq(sent[2].Chars[T.TAV].JP.Knight, nil, "locked jobs are left out")
    local JobMenu = Ext.Require("Client/JobMenu.lua")
    local Data = Ext.Require("Shared/GeneratedData.lua")
    local lines = JobMenu.Lines(Data.JobMenu, Data.Jobs, sent[2].Chars[T.TAV])
    T.eq(lines[Data.JobMenu.HaveHandle.Squire], "Tav has 120 Squire JP to spend.")
    T.eq(lines[Data.JobMenu.HaveHandle.Knight], nil)
end

function S.every_menu_spell_has_a_stats_entry(w, T, Mocks)
    local f = assert(io.open(Mocks.Root .. "/Mod/Public/FFTJobs/Stats/Generated/Data/Spell_FFTJ_Menu.txt", "rb"))
    local text = f:read("a")
    f:close()
    local have = {}
    for name in text:gmatch('new entry "([^"]+)"') do
        have[name] = true
    end
    local m = Ext.Require("Shared/GeneratedData.lua").JobMenu
    local n = 0
    local function check(id)
        T.truthy(have[id], id)
        n = n + 1
    end
    check(m.Change)
    check(m.Secondary)
    check(m.Clear)
    for jobId, id in pairs(m.Primary) do
        check(id)
        check(m.SecondaryOf[jobId])
        if m.Regular[jobId] then
            check(id .. m.LockedSuffix)
            check(m.SecondaryOf[jobId] .. m.LockedSuffix)
        end
    end
    for _, id in pairs(m.LearnFrom) do
        check(id)
    end
    for _, id in pairs(m.Learn) do
        check(id)
    end
    T.eq(n, 602, "every generated entry is one the server can grant")
end

return S
