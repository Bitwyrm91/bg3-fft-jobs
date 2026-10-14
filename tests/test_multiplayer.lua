-- NWP 12, multiplayer: each player changes only the characters they control (user, 2026-10-14), the Job Board opens
-- only for the player who asked, party news reaches every player once.
local S = {}

-- Tav and Astarion belong to player 1 (the host), Shadowheart to player 2.
local function mp(w, T, opts)
    T.party(w)
    w.chars[T.TAV].user, w.chars[T.ASTA].user, w.chars[T.SHART].user = 1, 1, 2
    opts = opts or {}
    opts.noParty = true
    return T.boot(w, opts)
end

function S.a_player_changes_only_their_own_characters(w, T)
    local svc = mp(w, T)
    local NetServer = Ext.Require("Server/NetServer.lua")
    local r = NetServer.Handle(svc, { Op = "SetPrimary", Char = T.SHART, Job = "Squire", From = T.TAV })
    T.falsy(r.Ok)
    T.contains(r.Message, "Shadowheart is controlled by another player")
    T.eq(svc.State:Get(T.SHART).Primary, "Chemist", "unchanged")
    T.truthy(NetServer.Handle(svc, { Op = "View", Char = T.SHART, From = T.TAV }).Ok, "looking is fine")
    T.truthy(NetServer.Handle(svc, { Op = "SetPrimary", Char = T.ASTA, Job = "Chemist", From = T.TAV }).Ok,
        "the same player's other character")
    T.truthy(NetServer.Handle(svc, { Op = "SetPrimary", Char = T.SHART, Job = "Squire", From = T.SHART }).Ok,
        "her own player")
end

function S.everyone_may_change_everyone_when_the_switch_is_on(w, T)
    local svc = mp(w, T, { extra = { Rules = { EditOthersInMultiplayer = true } } })
    local NetServer = Ext.Require("Server/NetServer.lua")
    T.truthy(NetServer.Handle(svc, { Op = "SetPrimary", Char = T.SHART, Job = "Squire", From = T.TAV }).Ok)
end

function S.single_player_and_unknown_players_are_not_limited(w, T)
    local svc = T.boot(w) -- no player ids on the mock characters
    local NetServer = Ext.Require("Server/NetServer.lua")
    T.truthy(NetServer.Handle(svc, { Op = "SetPrimary", Char = T.SHART, Job = "Squire", From = T.TAV }).Ok)
    T.truthy(NetServer.Handle(svc, { Op = "SetPrimary", Char = T.ASTA, Job = "Chemist" }).Ok, "no From: allowed")
end

function S.the_board_tells_the_server_who_asks(w, T, Mocks)
    mp(w, T)
    w.controlled = T.TAV -- this client plays Tav
    local seen = {}
    local server = w.serverChannels.FFTJ_Board
    local handler = server.requestHandler
    server.requestHandler = function(data, user)
        seen[#seen + 1] = data
        return handler(data, user)
    end
    T.cast(w, T.TAV, "Shout_FFTJ_JobBoard")
    local tab = Mocks.FindWidgets(w.windows[1], function(x)
        return x.Kind == "Button" and x.Label:find("Shadowheart", 1, true) ~= nil
    end)[1]
    T.truthy(tab, "a tab per party member")
    tab.OnClick(tab)
    T.truthy(#seen > 0, "the tab asks the server for her view")
    T.eq(seen[#seen].Char, T.SHART)
    T.eq(seen[#seen].From, T.TAV, "and says who is asking")
end

function S.the_board_opens_for_the_player_who_cast_it(w, T)
    mp(w, T)
    T.cast(w, T.SHART, "Shout_FFTJ_JobBoard")
    local open = w.serverChannels.FFTJ_Open
    local last = open.sentTo and open.sentTo[#open.sentTo]
    T.truthy(last, "sent to one player, not broadcast")
    T.eq(last.user, T.SHART, "addressed by her character")
    T.eq(last.data.Char, T.SHART)
end

function S.party_news_reach_every_player_once(w, T)
    mp(w, T)
    w.console("fft_badge", "Cleric")
    local to = {}
    for _, n in ipairs(w.notified) do
        if n.text:find("The party found the Cleric Badge", 1, true) then
            to[#to + 1] = n.char
        end
    end
    T.eq(#to, 2, "one per player")
    local users = {}
    for _, g in ipairs(to) do
        users[w.chars[g].user] = true
    end
    T.truthy(users[1] and users[2], "player 1 and player 2")
end

function S.party_news_in_single_player_go_to_one_character(w, T)
    T.boot(w)
    w.console("fft_badge", "Cleric")
    local n = 0
    for _, x in ipairs(w.notified) do
        if x.text:find("The party found the Cleric Badge", 1, true) then
            n = n + 1
        end
    end
    T.eq(n, 1)
end

return S
