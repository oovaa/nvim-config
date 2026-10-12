-- Startup performance gate. Boots the real config in subprocesses and asserts a
-- median wall-clock budget, then prints the slowest sourcing entries so a red
-- run is diagnosable.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_startup.lua")' -c 'qa!'

describe('startup performance', function()
  local H = require 'tests.helpers'

  -- GH runners are several times slower than a warm dev box (~72-95ms there),
  -- so the budget is a regression guard, not a "must be instant" gate.
  local BUDGET_MS = 400
  local RUNS = 3

  it(string.format('median startup stays under %dms over %d runs', BUDGET_MS, RUNS), function()
    local times, log = H.startup_ms(RUNS)
    local slowest = H.slowest(log, 8)
    vim.fn.delete(log)

    assert.is_true(#times == RUNS, 'expected ' .. RUNS .. ' startup samples, got ' .. #times)
    local median = H.median(times)

    if median >= BUDGET_MS then
      local detail = { string.format('median startup %.1fms >= %dms', median, BUDGET_MS), 'slowest sourcing entries:' }
      vim.list_extend(detail, slowest)
      error(table.concat(detail, '\n'))
    end

    -- surface the numbers on green runs too — startup work is invisible otherwise
    print(string.format('startup median %.1fms (runs: %s)', median, table.concat(times, ', ')))
  end)
end)
