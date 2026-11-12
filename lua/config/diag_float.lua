---@module 'config.diag_float'
-- Diagnostic float state machine (Option A): show the float instantly when
-- landing on an error line. Inline text cannot wrap, so the float gives the
-- full wrapped message. close_events includes CursorMoved (old float closes
-- on move); we open via vim.schedule so the new cursor line is visible. No
-- bail on existing float (blink docs etc. must not block it). Tracks our
-- float so we don't close unrelated relative windows (hover, signature,
-- notifications).

local M = {}

function M.setup()
  local last_diag_lnum = nil
  local diag_float_timer ---@type uv.uv_timer_t|nil
  local diag_float_win ---@type integer|nil

  local function close_diag_float()
    if diag_float_win and vim.api.nvim_win_is_valid(diag_float_win) then pcall(vim.api.nvim_win_close, diag_float_win, true) end
    diag_float_win = nil
  end

  -- Reuse a single timer instead of allocating one per CursorMoved (avoids
  -- per-move GC pressure; the UI audit flagged new_timer on every cursor move).
  local function get_diag_timer()
    if diag_float_timer and not diag_float_timer:is_closing() then return diag_float_timer end
    diag_float_timer = vim.uv.new_timer()
    return diag_float_timer
  end

  local function stop_diag_timer()
    if diag_float_timer then pcall(function() diag_float_timer:stop() end) end
  end

  local function open_diag_float()
    if vim.b.large_file_mode then return end
    if vim.api.nvim_get_mode().mode ~= 'n' then return end
    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok_cursor then return end
    local lnum = cursor[1] - 1
    if lnum == last_diag_lnum then return end
    if #vim.diagnostic.get(0, { lnum = lnum }) == 0 then return end
    close_diag_float()
    local ok, _, win = pcall(vim.diagnostic.open_float, nil, {
      focusable = false,
      scope = 'line',
      border = 'rounded',
      close_events = { 'CursorMoved', 'BufLeave', 'InsertEnter', 'WinClosed' },
    })
    if ok and type(win) == 'number' then diag_float_win = win end
    last_diag_lnum = lnum
  end

  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Diagnostic float on line entry (debounced)',
    group = vim.api.nvim_create_augroup('diag-float-on-move', { clear = true }),
    callback = function()
      stop_diag_timer()
      close_diag_float()
      -- reset throttle so returning to a previously-seen line re-opens
      last_diag_lnum = nil
      local t = get_diag_timer()
      if not t then
        vim.schedule(open_diag_float)
        return
      end
      t:start(
        60,
        0,
        vim.schedule_wrap(function()
          stop_diag_timer()
          open_diag_float()
        end)
      )
    end,
  })
  -- DiagnosticChanged: coalesce with debounce so streaming diagnostics (vtsls/TS
  -- projects) don't spam opens. Only meaningful in normal mode.
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    desc = 'Refresh diagnostic float on change (debounced)',
    group = vim.api.nvim_create_augroup('diag-float-on-change', { clear = true }),
    callback = function()
      if vim.api.nvim_get_mode().mode ~= 'n' then return end
      stop_diag_timer()
      last_diag_lnum = nil
      local t = get_diag_timer()
      if not t then
        vim.schedule(open_diag_float)
        return
      end
      t:start(
        80,
        0,
        vim.schedule_wrap(function()
          stop_diag_timer()
          open_diag_float()
        end)
      )
    end,
  })

  -- CursorMovedI: reset state in insert mode (no popup) to avoid stale throttle.
  vim.api.nvim_create_autocmd('CursorMovedI', {
    desc = 'Reset diagnostic float state in insert mode',
    group = vim.api.nvim_create_augroup('diag-float-insert-reset', { clear = true }),
    callback = function()
      stop_diag_timer()
      close_diag_float()
      last_diag_lnum = nil
    end,
  })
end

return M
