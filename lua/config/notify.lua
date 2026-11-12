---@module 'config.notify'
-- NOTIFY THROTTLE (spam guard for auto-save + conform)
-- A file the formatter can't handle (e.g. badly broken json) fails on
-- EVERY auto-save, and notify_on_error would re-notify every few
-- keystrokes. First notice shows; identical repeats within 15s are
-- dropped. Manual <leader>ff still notifies when you ask for it.
-- Re-applied instead of stacked: snacks installs a shim that swaps
-- `vim.notify` on first call (snacks/init.lua:219), so a one-shot wrap
-- at startup is dead by the first format error.

local M = {}

local throttle_state = { msg = nil, at = 0 }

local function wrap_notify(fn)
  if fn == vim.notify_throttled then return fn end
  ---@diagnostic disable-next-line: duplicate-set-field
  function vim.notify(msg, level, opts)
    if type(msg) == 'string' and msg:match '^Formatter failed' then
      local now = vim.uv.now()
      if msg == throttle_state.msg and now - throttle_state.at < 15000 then return end
      throttle_state.msg, throttle_state.at = msg, now
    end
    return fn(msg, level, opts)
  end
  vim.notify_throttled = vim.notify
  return vim.notify
end

function M.setup()
  vim.notify = wrap_notify(vim.notify)
  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    group = vim.api.nvim_create_augroup('notify-throttle', { clear = true }),
    callback = function()
      vim.schedule(function()
        local ok, notifier = pcall(require, 'snacks.notifier')
        if ok and type(notifier.notify) == 'function' then notifier.notify = wrap_notify(notifier.notify) end
        vim.notify = wrap_notify(vim.notify)
      end)
    end,
  })
end

return M
