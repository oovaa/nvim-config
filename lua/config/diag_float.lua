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
  -- Reload-safe (<leader>ur evicts this module and re-runs setup): keep state
  -- in _G and tear down the previous timer/float first, otherwise a queued
  -- callback from the old timer opens a float the new state can't close.
  local state = _G._diag_float_state
  if state then
    if state.timer and not state.timer:is_closing() then
      pcall(function() state.timer:stop() end)
      pcall(function() state.timer:close() end)
    end
    if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
    state.timer, state.win, state.last_lnum = nil, nil, nil
  else
    _G._diag_float_state = {}
    state = _G._diag_float_state
  end

  local function close_diag_float()
    if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
    state.win = nil
  end

  -- Reuse a single timer instead of allocating one per CursorMoved (avoids
  -- per-move GC pressure; the UI audit flagged new_timer on every cursor move).
  local function get_diag_timer()
    if state.timer and not state.timer:is_closing() then return state.timer end
    state.timer = vim.uv.new_timer()
    return state.timer
  end

  local function stop_diag_timer()
    if state.timer then pcall(function() state.timer:stop() end) end
  end

  local function open_diag_float()
    if vim.b.large_file_mode then return end
    if vim.api.nvim_get_mode().mode ~= 'n' then return end
    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok_cursor then return end
    local lnum = cursor[1] - 1
    if lnum == state.last_lnum then return end
    if #vim.diagnostic.get(0, { lnum = lnum }) == 0 then
      close_diag_float()
      return
    end
    close_diag_float()
    local ok, _, win = pcall(vim.diagnostic.open_float, nil, {
      focusable = false,
      scope = 'line',
      border = 'rounded',
      close_events = { 'CursorMoved', 'BufLeave', 'InsertEnter', 'WinClosed' },
    })
    if ok and type(win) == 'number' then state.win = win end
    state.last_lnum = lnum
  end

  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Diagnostic float on line entry (debounced)',
    group = vim.api.nvim_create_augroup('diag-float-on-move', { clear = true }),
    callback = function()
      stop_diag_timer()
      close_diag_float()
      -- reset throttle so returning to a previously-seen line re-opens
      state.last_lnum = nil
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
    callback = function(ev)
      if vim.api.nvim_get_mode().mode ~= 'n' then return end
      -- Ignore updates for other buffers: they don't affect the current line
      -- and only cause the float to flicker/reopen with streaming LSPs.
      if ev.buf ~= vim.api.nvim_get_current_buf() then return end
      close_diag_float()
      stop_diag_timer()
      state.last_lnum = nil
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
      state.last_lnum = nil
    end,
  })

  -- Release the reused timer on exit so it can't keep the loop alive.
  vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'Stop diagnostic float timer on exit',
    group = vim.api.nvim_create_augroup('diag-float-cleanup', { clear = true }),
    callback = function()
      stop_diag_timer()
      close_diag_float()
      if state.timer and not state.timer:is_closing() then pcall(function() state.timer:close() end) end
    end,
  })
end

return M
