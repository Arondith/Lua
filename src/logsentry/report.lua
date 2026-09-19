local analyzer = require("logsentry.analyzer")
local json = require("logsentry.json")

local report = {}

local function percentage(value)
    return string.format("%.2f%%", (value or 0) * 100)
end

local function sorted_pairs(map)
    local keys = {}
    for key in pairs(map or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)

    local index = 0
    return function()
        index = index + 1
        local key = keys[index]
        if key ~= nil then
            return key, map[key]
        end
    end
end

function report.to_text(summary, rejected_count)
    local lines = {
        "LogSentry Analysis",
        "===================",
        string.format("Parsed entries : %d", summary.total),
        string.format("Rejected lines : %d", rejected_count or 0),
        string.format("Error requests : %d (%s)", summary.error_requests, percentage(summary.error_rate)),
        string.format("Slow requests  : %d", summary.slow_requests),
        string.format("Avg latency    : %.2f ms", summary.latency.average_ms),
        string.format("Max latency    : %.2f ms", summary.latency.max_ms),
        "",
        "Levels:"
    }

    for level, count in sorted_pairs(summary.levels) do
        table.insert(lines, string.format("  %-8s %d", level, count))
    end

    table.insert(lines, "")
    table.insert(lines, "Top endpoints:")

    for _, item in ipairs(analyzer.top_entries(summary.endpoints, 5)) do
        table.insert(lines, string.format("  %-30s %d", item.key, item.count))
    end

    if #summary.alerts > 0 then
        table.insert(lines, "")
        table.insert(lines, "Alerts:")
        for _, alert in ipairs(summary.alerts) do
            table.insert(
                lines,
                string.format("  [%s] %s: %s", alert.severity:upper(), alert.code, alert.message)
            )
        end
    end

    return table.concat(lines, "\n")
end

function report.to_markdown(summary, rejected_count)
    local lines = {
        "# LogSentry Analysis",
        "",
        "| Metric | Value |",
        "|---|---:|",
        string.format("| Parsed entries | %d |", summary.total),
        string.format("| Rejected lines | %d |", rejected_count or 0),
        string.format("| Error rate | %s |", percentage(summary.error_rate)),
        string.format("| Slow requests | %d |", summary.slow_requests),
        string.format("| Average latency | %.2f ms |", summary.latency.average_ms),
        string.format("| Maximum latency | %.2f ms |", summary.latency.max_ms),
        "",
        "## Top endpoints",
        "",
        "| Endpoint | Requests |",
        "|---|---:|"
    }

    for _, item in ipairs(analyzer.top_entries(summary.endpoints, 5)) do
        table.insert(lines, string.format("| `%s` | %d |", item.key, item.count))
    end

    table.insert(lines, "")
    table.insert(lines, "## Alerts")

    if #summary.alerts == 0 then
        table.insert(lines, "")
        table.insert(lines, "No configured anomaly thresholds were exceeded.")
    else
        for _, alert in ipairs(summary.alerts) do
            table.insert(
                lines,
                string.format("- **%s — %s:** %s", alert.severity:upper(), alert.code, alert.message)
            )
        end
    end

    return table.concat(lines, "\n")
end

function report.to_json(summary, rejected_count)
    return json.encode({
        summary = summary,
        rejected_lines = rejected_count or 0
    })
end

return report
