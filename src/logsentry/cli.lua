local parser = require("logsentry.parser")
local analyzer = require("logsentry.analyzer")
local report = require("logsentry.report")

local cli = {}

local function usage()
    return [[
LogSentry - dependency-free Lua log analyzer

Usage:
  lua main.lua analyze <file> [options]

Options:
  --format <text|markdown|json>   Output format (default: text)
  --slow <milliseconds>           Slow-request threshold (default: 1000)
  --error-rate <decimal>          Error-rate alert threshold (default: 0.10)
  --output <file>                 Write report to a file
  --help                          Show this help

Example:
  lua main.lua analyze sample/app.log --format markdown --slow 800
]]
end

local function parse_options(args, start_index)
    local options = {
        format = "text",
        slow_threshold_ms = 1000,
        error_rate_threshold = 0.10
    }

    local index = start_index
    while index <= #args do
        local flag = args[index]

        if flag == "--format" then
            index = index + 1
            options.format = args[index]
        elseif flag == "--slow" then
            index = index + 1
            options.slow_threshold_ms = tonumber(args[index])
        elseif flag == "--error-rate" then
            index = index + 1
            options.error_rate_threshold = tonumber(args[index])
        elseif flag == "--output" then
            index = index + 1
            options.output = args[index]
        elseif flag == "--help" then
            options.help = true
        else
            return nil, "unknown option: " .. tostring(flag)
        end

        index = index + 1
    end

    if not ({ text = true, markdown = true, json = true })[options.format] then
        return nil, "format must be text, markdown, or json"
    end

    if not options.slow_threshold_ms or options.slow_threshold_ms <= 0 then
        return nil, "--slow must be a positive number"
    end

    if not options.error_rate_threshold
        or options.error_rate_threshold < 0
        or options.error_rate_threshold > 1 then
        return nil, "--error-rate must be between 0 and 1"
    end

    return options
end

local function render(summary, rejected_count, format)
    if format == "json" then
        return report.to_json(summary, rejected_count)
    elseif format == "markdown" then
        return report.to_markdown(summary, rejected_count)
    end
    return report.to_text(summary, rejected_count)
end

local function write_output(path, content)
    local file, err = io.open(path, "w")
    if not file then
        return nil, err
    end

    file:write(content)
    file:write("\n")
    file:close()
    return true
end

function cli.run(args)
    args = args or {}

    if args[1] == "--help" or args[1] == nil then
        print(usage())
        return 0
    end

    if args[1] ~= "analyze" then
        io.stderr:write("Unknown command: " .. tostring(args[1]) .. "\n\n")
        io.stderr:write(usage())
        return 2
    end

    local path = args[2]
    if not path then
        io.stderr:write("A log file path is required.\n\n")
        io.stderr:write(usage())
        return 2
    end

    local options, option_error = parse_options(args, 3)
    if not options then
        io.stderr:write(option_error .. "\n")
        return 2
    end

    if options.help then
        print(usage())
        return 0
    end

    local parsed, parse_error = parser.parse_file(path)
    if not parsed then
        io.stderr:write(parse_error .. "\n")
        return 1
    end

    local summary = analyzer.analyze(parsed.entries, options)
    local output = render(summary, #parsed.rejected, options.format)

    if options.output then
        local ok, write_error = write_output(options.output, output)
        if not ok then
            io.stderr:write("unable to write report: " .. tostring(write_error) .. "\n")
            return 1
        end
        print("Report written to " .. options.output)
    else
        print(output)
    end

    return 0
end

return cli
