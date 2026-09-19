local json = {}

local function escape_string(value)
    return value
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function is_array(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

function json.encode(value)
    local value_type = type(value)

    if value_type == "nil" then
        return "null"
    elseif value_type == "boolean" or value_type == "number" then
        return tostring(value)
    elseif value_type == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif value_type ~= "table" then
        error("unsupported JSON type: " .. value_type)
    end

    local parts = {}

    if is_array(value) then
        for _, item in ipairs(value) do
            table.insert(parts, json.encode(item))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for key in pairs(value) do
        table.insert(keys, tostring(key))
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(
            parts,
            json.encode(key) .. ":" .. json.encode(value[key])
        )
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

return json
