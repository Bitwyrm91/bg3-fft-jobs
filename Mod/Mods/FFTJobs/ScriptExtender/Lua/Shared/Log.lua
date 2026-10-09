-- Console logging through Ext.Utils.Print (the SE's _P).
local Log = {
    Debug = false,
    Prefix = "[FFTJobs] ",
}

local function emit(level, ...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    Ext.Utils.Print(Log.Prefix .. level .. table.concat(parts, " "))
end

function Log.Info(...)
    emit("", ...)
end

function Log.Warn(...)
    emit("WARNING: ", ...)
end

function Log.Error(...)
    emit("ERROR: ", ...)
end

function Log.DebugLog(...)
    if Log.Debug then
        emit("debug: ", ...)
    end
end

-- Runs fn(...) and logs (instead of propagating) any error, with a traceback.
function Log.Safe(where, fn, ...)
    local ok, err = xpcall(fn, debug.traceback, ...)
    if not ok then
        Log.Error(where .. ": " .. tostring(err))
    end
    return ok, err
end

return Log
