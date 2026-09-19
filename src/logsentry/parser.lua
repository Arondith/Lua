local parser = {}

local function parse_number(value)
    local number = tonumber(value)
    if number == nil then
        return value
    end
    return number
end

function parser.parse_line(line)
    if type(line) ~= "string" or line:match("^%s*$") then
        return nil, "empty line"
    end

    local timestamp, remainder = line:match("^(%S+)%s+(.+)$")
    if not timestamp then
        return nil, "missing timestamp"
    end

    local entry = {
        timestamp = timestamp,
        raw = line
    }

    for key, value in remainder:gmatch("([%w_%-]+)=([^%s]+)") do
        value = value:gsub('^"', ""):gsub('"$', "")
        entry[key] = parse_number(value)
    end

    if not entry.level then
        return nil, "missing level"
    end

    entry.level = tostring(entry.level):upper()

    if entry.status then
        entry.status = tonumber(entry.status)
    end

    if entry.latency_ms then
        entry.latency_ms = tonumber(entry.latency_ms)
    end

    return entry
end

function parser.parse_file(path)
    local file, err = io.open(path, "r")
    if not file then
        return nil, "unable to open file: " .. tostring(err)
    end

    local entries = {}
    local rejected = {}

    for line_number, line in ipairs(parser.read_lines(file)) do
        local entry, parse_error = parser.parse_line(line)
        if entry then
            table.insert(entries, entry)
        else
            table.insert(rejected, {
                line = line_number,
                reason = parse_error,
                raw = line
            })
        end
    end

    file:close()
    return {
        entries = entries,
        rejected = rejected
    }
end

function parser.read_lines(file)
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    return lines
end

return parser
