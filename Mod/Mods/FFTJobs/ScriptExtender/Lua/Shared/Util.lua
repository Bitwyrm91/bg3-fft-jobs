-- Small table/string helpers shared by server and client. No game API calls here.
local Util = {}

function Util.DeepCopy(v)
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, x in pairs(v) do
        out[k] = Util.DeepCopy(x)
    end
    return out
end

-- True for a non-empty table whose keys are exactly 1..n.
function Util.IsArray(t)
    if type(t) ~= "table" then
        return false
    end
    local n = #t
    if n == 0 then
        return false
    end
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
            return false
        end
    end
    return true
end

-- Copy of base with over applied on top. Dictionaries merge recursively; arrays and scalars replace.
function Util.DeepMerge(base, over)
    local out = Util.DeepCopy(base)
    if type(over) ~= "table" then
        return out
    end
    for k, v in pairs(over) do
        local b = out[k]
        if type(v) == "table" and type(b) == "table" and not Util.IsArray(b) and not Util.IsArray(v) then
            out[k] = Util.DeepMerge(b, v)
        else
            out[k] = Util.DeepCopy(v)
        end
    end
    return out
end

function Util.SortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

function Util.Count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

function Util.SplitPath(path)
    local parts = {}
    for p in string.gmatch(path, "[^%.]+") do
        parts[#parts + 1] = p
    end
    return parts
end

function Util.GetPath(t, path)
    local cur = t
    for _, p in ipairs(Util.SplitPath(path)) do
        if type(cur) ~= "table" then
            return nil
        end
        cur = cur[p]
    end
    return cur
end

function Util.SetPath(t, path, value)
    local parts = Util.SplitPath(path)
    local cur = t
    for i = 1, #parts - 1 do
        local p = parts[i]
        if type(cur[p]) ~= "table" then
            cur[p] = {}
        end
        cur = cur[p]
    end
    cur[parts[#parts]] = value
end

-- Removes path from t, then prunes tables left empty.
function Util.ClearPath(t, path)
    local parts = Util.SplitPath(path)
    local chain = { t }
    local cur = t
    for i = 1, #parts - 1 do
        cur = cur[parts[i]]
        if type(cur) ~= "table" then
            return
        end
        chain[#chain + 1] = cur
    end
    cur[parts[#parts]] = nil
    for i = #parts - 1, 1, -1 do
        if next(chain[i + 1]) == nil then
            chain[i][parts[i]] = nil
        end
    end
end

-- "Lae'zel" -> "laezel", "Aim +1" -> "aim1": for matching user input to ids and names.
function Util.Normalize(s)
    return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

local UUID_PATTERN = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

-- Osiris GUID strings look like "S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c";
-- the engine keys characters by the trailing UUID.
function Util.Guid(s)
    if type(s) ~= "string" then
        return nil
    end
    local uuid = string.match(s, UUID_PATTERN)
    return uuid and string.lower(uuid) or s
end

function Util.Trim(s)
    return (string.gsub(tostring(s or ""), "^%s+", ""):gsub("%s+$", ""))
end

function Util.ParseBool(s)
    local v = string.lower(Util.Trim(s))
    if v == "true" or v == "1" or v == "yes" or v == "on" then
        return true
    end
    if v == "false" or v == "0" or v == "no" or v == "off" then
        return false
    end
    return nil
end

-- Formats a JP/XP number for messages: integers without decimals, others with up to 2.
function Util.Num(x)
    if type(x) ~= "number" then
        return tostring(x)
    end
    if x == math.floor(x) then
        return string.format("%d", x)
    end
    return (string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", ""))
end

function Util.Join(list, sep)
    local parts = {}
    for i, v in ipairs(list or {}) do
        parts[i] = tostring(v)
    end
    return table.concat(parts, sep or ", ")
end

return Util
