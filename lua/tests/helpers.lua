---@module 'tests.helpers'
-- Location-agnostic config reader for specs: concatenates init.lua + every
-- lua/**/*.lua so string assertions survive file moves (modular split).

local M = {}

function M.read(path) return table.concat(vim.fn.readfile(path), '\n') end

function M.all()
  local root = vim.fn.stdpath 'config'
  local parts = { M.read(root .. '/init.lua') }
  local files = vim.fn.glob(root .. '/lua/**/*.lua', false, true)
  table.sort(files)
  for _, f in ipairs(files) do
    parts[#parts + 1] = M.read(f)
  end
  return table.concat(parts, '\n')
end

--- Same as all() but with `--` comments stripped (checks code, not prose).
--- Strips both `--[[ ]]` blocks (whose continuation lines lack a `--`
--- prefix) and trailing line comments.
function M.code() return M.all():gsub('%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', '') end

--- Boots nvim in a subprocess `runs` times and returns `{ times, log }` where
--- `times` are the startup times (ms) and `log` is the final --startuptime file
--- (kept so callers can show which entries were slow). Each run is its own
--- process, so this measures cold boot of the config. The first run is discarded:
--- it pays for lazily-cached plugin/bytecode that every later run reuses, so
--- including it makes the median meaningless.
function M.startup_ms(runs)
  local log = vim.fn.tempname()
  -- tempname()'s parent dir only exists once nvim itself writes there, and the
  -- measurement happens in a subprocess — create it or the log comes back empty.
  vim.fn.mkdir(vim.fn.fnamemodify(log, ':h'), 'p')
  local times = {}
  for i = 1, runs + 1 do
    -- --startuptime APPENDS to an existing file; without this each run would
    -- re-parse every previous run's lines and the sample count would drift.
    vim.fn.delete(log)
    vim.fn.system { 'nvim', '--headless', '--startuptime', log, '+qa!' }
    if i > 1 then
      for _, l in ipairs(vim.fn.readfile(log)) do
        local ms = tonumber(l:match '^(%S+)%s+%S+: %-%-%- NVIM STARTED %-%-%-$')
        if ms then times[#times + 1] = ms end
      end
    end
  end
  table.sort(times)
  return times, log
end

--- Median of a numeric list (returns the mean of the middle pair when even).
function M.median(t)
  local n = #t
  return n % 2 == 1 and t[(n + 1) / 2] or (t[n / 2] + t[n / 2 + 1]) / 2
end

--- Slowest `n` entries from a --startuptime log, by self+sourced ms.
--- Used to make a startup regression diagnosable instead of just red.
-- log columns are: clock  self+sourced  self:  sourced script.
-- Rank on self+sourced (column 2); column 1 is cumulative and would just
-- return the slowest-to-finish chain, not the slowest work.
function M.slowest(log, n)
  local rows = {}
  for _, l in ipairs(vim.fn.readfile(log)) do
    local self, what = l:match '^%s*[%d.]+%s+([%d.]+)%s+[%d.]+:%s*(.*)$'
    -- skip the trailing summary block (NVIM STARTED / totals), keep real entries
    if what and what ~= '' and not what:match 'NVIM STARTED' and what ~= 'editing files in windows' then
      rows[#rows + 1] = { ms = tonumber(self), what = what }
    end
  end
  table.sort(rows, function(a, b) return a.ms > b.ms end)
  local out = {}
  for i = 1, math.min(n, #rows) do
    out[i] = string.format('%7.2f  %s', rows[i].ms, rows[i].what)
  end
  return out
end

--- Counts autocmds grouped by named augroup from `vim.api.nvim_get_autocmds({})`.
--- Returns table mapping augroup name -> count. Anonymous (`''`) groups included
--- so a missing clear group shows up as growth, but the test asserts tracked
--- groups are non-empty strings (Neovim permits empty-string groups).
function M.autocmd_count()
  local counts = {}
  for _, ac in ipairs(vim.api.nvim_get_autocmds {}) do
    local group = ac.group_name or ac.group or ''
    counts[group] = (counts[group] or 0) + 1
  end
  return counts
end

return M
