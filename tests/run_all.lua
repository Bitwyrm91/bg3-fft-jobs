-- Runs every test suite with a fresh mock world per test.
--   lua5.4 tests/run_all.lua            (from the repository root; Windows: lua54.exe tests\run_all.lua)
--   lua5.4 tests/run_all.lua grants     (only tests whose suite or name contains "grants")
local here = debug.getinfo(1, "S").source:match("^@(.*)[/\\]run_all%.lua$") or "tests"
local Mocks = dofile(here .. "/mocks.lua")
local T = dofile(here .. "/testlib.lua")

local SUITES = {
    "test_rules.lua",
    "test_config.lua",
    "test_engine.lua",
    "test_persistence.lua",
    "test_commands.lua",
    "test_ui.lua",
    "test_data.lua",
    "test_effects.lua",
    "test_bosses.lua",
    "test_souls.lua",
    "test_menu.lua",
    "test_scaling.lua",
    "test_statcast.lua",
}

local filter = arg and arg[1]
local passed, failed, failures = 0, 0, {}

for _, file in ipairs(SUITES) do
    local suite = dofile(here .. "/" .. file)
    assert(type(suite) == "table", file .. " must return a table of tests")
    local names = {}
    for name in pairs(suite) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local full = file:gsub("%.lua$", "") .. " :: " .. name
        if not filter or string.find(string.lower(full), string.lower(filter), 1, true) then
            local world = Mocks.Install()
            local ok, err = xpcall(suite[name], debug.traceback, world, T, Mocks)
            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                failures[#failures + 1] = full .. "\n    " .. tostring(err):gsub("\n", "\n    ")
            end
        end
    end
end

for _, f in ipairs(failures) do
    print("FAIL " .. f)
end
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
