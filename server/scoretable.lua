-- mzb_arena - server: what the basketball floor's scorer's table says, for a script that keeps a game of its own
-- (client/scoretable.lua puts it on the table; gk_basketball's games come on their own: Config.ScoreTable.feed).
--   exports.mzb_arena:SetScoreTable({ home = 'PANIC', away = 'NARCOS', homeScore = 78, awayScore = 74,
--                                      period = 'QTR 3', clock = '5:12' })      -- on the table while it is set
--   exports.mzb_arena:SetScoreTable(nil)                                          -- let it go (the feed, or the picture)
--   exports.mzb_arena:GetScoreTable()

local function text(v, n)
    if v == nil then return '' end
    return tostring(v):sub(1, n)
end

exports('SetScoreTable', function(t)
    if type(t) ~= 'table' then
        GlobalState.mzbScoreTable = nil
        return true
    end
    GlobalState.mzbScoreTable = { home = text(t.home, 24), away = text(t.away, 24), homeScore = text(t.homeScore, 4),
                                  awayScore = text(t.awayScore, 4), period = text(t.period, 24), clock = text(t.clock, 12) }
    return true
end)

exports('GetScoreTable', function() return GlobalState.mzbScoreTable end)

GlobalState.mzbScoreTable = nil                    -- (what a run before this one left up: GlobalState outlives it)
