local analyzer = {}

local function increment(map, key)
    key = key or "unknown"
    map[key] = (map[key] or 0) + 1
end

local function round(value, places)
    local factor = 10 ^ (places or 0)
    return math.floor(value * factor + 0.5) / factor
end

function analyzer.analyze(entries, options)
    options = options or {}
    local slow_threshold = options.slow_threshold_ms or 1000
    local error_rate_threshold = options.error_rate_threshold or 0.10

    local summary = {
        total = #entries,
        levels = {},
        status_codes = {},
        endpoints = {},
        slow_requests = 0,
        error_requests = 0,
        latency = {
            count = 0,
            total_ms = 0,
            average_ms = 0,
            max_ms = 0
        },
        alerts = {}
    }

    for _, entry in ipairs(entries) do
        increment(summary.levels, entry.level)

        if entry.status then
            increment(summary.status_codes, tostring(entry.status))
            if entry.status >= 500 then
                summary.error_requests = summary.error_requests + 1
            end
        elseif entry.level == "ERROR" or entry.level == "FATAL" then
            summary.error_requests = summary.error_requests + 1
        end

        if entry.path then
            increment(summary.endpoints, entry.path)
        end

        if entry.latency_ms then
            local latency = entry.latency_ms
            summary.latency.count = summary.latency.count + 1
            summary.latency.total_ms = summary.latency.total_ms + latency
            summary.latency.max_ms = math.max(summary.latency.max_ms, latency)

            if latency >= slow_threshold then
                summary.slow_requests = summary.slow_requests + 1
            end
        end
    end

    if summary.latency.count > 0 then
        summary.latency.average_ms =
            round(summary.latency.total_ms / summary.latency.count, 2)
    end

    summary.error_rate =
        summary.total > 0 and round(summary.error_requests / summary.total, 4) or 0

    if summary.error_rate >= error_rate_threshold and summary.total > 0 then
        table.insert(summary.alerts, {
            code = "HIGH_ERROR_RATE",
            severity = "critical",
            message = string.format(
                "Error rate %.2f%% exceeds configured threshold %.2f%%",
                summary.error_rate * 100,
                error_rate_threshold * 100
            )
        })
    end

    if summary.slow_requests > 0 then
        table.insert(summary.alerts, {
            code = "SLOW_REQUESTS",
            severity = "warning",
            message = string.format(
                "%d request(s) exceeded %d ms",
                summary.slow_requests,
                slow_threshold
            )
        })
    end

    return summary
end

function analyzer.top_entries(map, limit)
    local items = {}
    for key, value in pairs(map or {}) do
        table.insert(items, { key = key, count = value })
    end

    table.sort(items, function(a, b)
        if a.count == b.count then
            return a.key < b.key
        end
        return a.count > b.count
    end)

    local output = {}
    for i = 1, math.min(limit or 5, #items) do
        output[i] = items[i]
    end
    return output
end

return analyzer
