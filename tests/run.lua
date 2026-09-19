package.path = "./src/?.lua;./src/?/init.lua;" .. package.path

local parser = require("logsentry.parser")
local analyzer = require("logsentry.analyzer")
local report = require("logsentry.report")
local json = require("logsentry.json")

local tests = {}
local passed = 0
local failed = 0

local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end

local function assert_equal(expected, actual, message)
    if expected ~= actual then
        error(
            (message or "values are not equal")
                .. string.format("\nexpected: %s\nactual:   %s", tostring(expected), tostring(actual)),
            2
        )
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "expected value to be truthy", 2)
    end
end

test("parser reads a structured log line", function()
    local entry, err = parser.parse_line(
        "2026-09-19T02:00:08Z level=ERROR method=POST path=/api/orders status=500 latency_ms=1280"
    )

    assert_equal(nil, err)
    assert_equal("ERROR", entry.level)
    assert_equal("POST", entry.method)
    assert_equal("/api/orders", entry.path)
    assert_equal(500, entry.status)
    assert_equal(1280, entry.latency_ms)
end)

test("parser rejects logs without a level", function()
    local entry, err = parser.parse_line(
        "2026-09-19T02:00:08Z method=GET path=/health status=200"
    )

    assert_equal(nil, entry)
    assert_equal("missing level", err)
end)

test("analyzer calculates latency and error rate", function()
    local entries = {
        assert(parser.parse_line(
            "2026-09-19T02:00:01Z level=INFO path=/health status=200 latency_ms=100"
        )),
        assert(parser.parse_line(
            "2026-09-19T02:00:02Z level=ERROR path=/orders status=500 latency_ms=1500"
        )),
        assert(parser.parse_line(
            "2026-09-19T02:00:03Z level=INFO path=/orders status=200 latency_ms=200"
        ))
    }

    local summary = analyzer.analyze(entries, {
        slow_threshold_ms = 1000,
        error_rate_threshold = 0.30
    })

    assert_equal(3, summary.total)
    assert_equal(1, summary.error_requests)
    assert_equal(0.3333, summary.error_rate)
    assert_equal(1, summary.slow_requests)
    assert_equal(600.0, summary.latency.average_ms)
    assert_equal(1500, summary.latency.max_ms)
    assert_equal(2, #summary.alerts)
end)

test("top entries are sorted by count", function()
    local top = analyzer.top_entries({
        ["/health"] = 2,
        ["/orders"] = 5,
        ["/users"] = 3
    }, 2)

    assert_equal("/orders", top[1].key)
    assert_equal(5, top[1].count)
    assert_equal("/users", top[2].key)
end)

test("JSON encoder produces deterministic object keys", function()
    local encoded = json.encode({
        status = "ok",
        count = 2
    })

    assert_equal('{"count":2,"status":"ok"}', encoded)
end)

test("markdown report exposes operational metrics", function()
    local summary = analyzer.analyze({
        assert(parser.parse_line(
            "2026-09-19T02:00:01Z level=INFO path=/health status=200 latency_ms=20"
        ))
    })

    local output = report.to_markdown(summary, 0)
    assert_true(output:find("# LogSentry Analysis", 1, true) ~= nil)
    assert_true(output:find("Average latency", 1, true) ~= nil)
end)

for _, item in ipairs(tests) do
    local ok, err = pcall(item.fn)
    if ok then
        passed = passed + 1
        print("PASS  " .. item.name)
    else
        failed = failed + 1
        print("FAIL  " .. item.name)
        print("      " .. tostring(err):gsub("\n", "\n      "))
    end
end

print("")
print(string.format("%d passed, %d failed, %d total", passed, failed, #tests))

if failed > 0 then
    os.exit(1)
end
