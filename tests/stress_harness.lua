-- Shared harness for the config stress test (see docs/superpowers/plans/).
-- Zero deps on purpose: the whole point is to test the config, not a framework.
local M = {}

M.results = {}

local emit -- forward-declared below; defined right after M.results

local function push(level, name, msg)
  M.results[#M.results + 1] = { level = level, name = name, msg = msg or '' }
  if emit then emit(level, name, (tostring(msg or ''):gsub('|', '/'):gsub('\n', ' ⏎ '))) end
end

function M.pass(name, msg) push('PASS', name, msg) end
function M.fail(name, msg) push('FAIL', name, msg) end
function M.warn(name, msg) push('WARN', name, msg) end

local function trace(err) return debug.traceback(tostring(err), 3) end

-- fn returns true/nil for pass, or { level = 'WARN'|'FAIL', msg = '...' }
function M.t(name, fn)
  local ok, res = xpcall(fn, trace)
  if not ok then return push('FAIL', name, res) end
  if res == true or res == nil then return push('PASS', name) end
  if type(res) == 'table' and res.level then return push(res.level, name, res.msg) end
  return push('FAIL', name, tostring(res))
end

function M.eq(name, expected, actual)
  M.t(name, function()
    if vim.deep_equal(expected, actual) then return true end
    return string.format('expected %s, got %s', vim.inspect(expected), vim.inspect(actual))
  end)
end

function M.truthy(name, cond, msg)
  M.t(name, function()
    if cond then return true end
    return msg or 'expected truthy, got ' .. vim.inspect(cond)
  end)
end

function M.falsy(name, cond, msg)
  M.t(name, function()
    if not cond then return true end
    return msg or 'expected falsy, got ' .. vim.inspect(cond)
  end)
end

-- every .lua that belongs to the config (skip .git, installed plugins, this test)
function M.lua_files()
  local out = {}
  for _, f in ipairs(vim.fn.glob(vim.fn.stdpath 'config' .. '/**/*.lua', false, true)) do
    if not f:match '/%.git/' and not f:match '/lazy/' and not f:match '/tests/stress' then out[#out + 1] = f end
  end
  table.sort(out)
  return out
end

-- messages that indicate a real failure (not a WARN/INFO notify)
function M.error_text(msgs)
  local bad = {}
  for line in tostring(msgs):gmatch '[^\n]+' do
    if line:match 'E%d%d%d+:' or line:match 'stack traceback' or line:match 'Error executing' or line:match '^ERROR' then
      bad[#bad + 1] = line:match '^%s*(.-)%s*$'
    end
  end
  return bad
end

-- Every result is also appended to $NVIM_STRESS_OUT as it happens, so a child
-- that dies mid-section (a keymap can launch a whole app) still reports the
-- checks it managed to finish.
local OUT = os.getenv 'NVIM_STRESS_OUT'
emit = function(level, name, msg)
  local line = string.format('@@%s|%s|%s\n', level, name, msg)
  io.write(line)
  io.flush()
  if OUT then
    local f = io.open(OUT, 'a')
    if f then
      f:write(line)
      f:close()
    end
  end
end

function M.flush() emit('END', tostring(#M.results), '') end

return M
