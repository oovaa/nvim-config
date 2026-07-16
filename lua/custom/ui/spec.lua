---@module 'custom.ui.spec'
local M = {}

--- Lualine statusline config (tokyonight theme, mode-aware).
---@return nil
function M.setup_lualine()
  local ok, lualine = pcall(require, 'lualine')
  if not ok then return end
  lualine.setup {
    options = {
      theme = 'tokyonight',
      icons_enabled = true,
      component_separators = { left = '', right = '' },
      section_separators = { left = '', right = '' },
      disabled_filetypes = { 'neo-tree', 'TelescopePrompt', 'starter', 'lazy' },
      globalstatus = true,
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { { 'filename', path = 1 } },
      lualine_x = { 'encoding', 'fileformat', 'filetype' },
      lualine_y = { 'progress' },
      lualine_z = { 'location' },
    },
    winbar = {
      lualine_c = {
        {
          function()
            local fname = vim.fn.expand '%:t'
            if fname == '' then return '' end
            local icon, _ = require('nvim-web-devicons').get_icon(fname, vim.fn.expand '%:e', { default = true })
            local mod = vim.bo.modified and ' [+]' or ''
            local diag = ''
            local count = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
            if count > 0 then diag = '  ' .. count end
            return icon .. ' ' .. fname .. mod .. diag
          end,
          color = { fg = '#7aa2f7' },
        },
      },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    inactive_winbar = { lualine_c = { { 'filename', path = 1 } } },
  }
end

--- Tune bufferline with diagnostic + filetype icons.
---@return nil
function M.setup_bufferline()
  local ok, bufferline = pcall(require, 'bufferline')
  if not ok then return end
  bufferline.setup {
    options = {
      mode = 'buffers',
      diagnostics = 'nvim_lsp',
      diagnostics_indicator = function(_, _, diag)
        local icons = { error = '', warn = '', info = '', hint = '' }
        local s = {}
        for severity, count in pairs(diag) do
          if count > 0 then s[#s + 1] = icons[severity] .. count end
        end
        return table.concat(s, ' ')
      end,
      separator_style = 'thin',
      always_show_bufferline = true,
      offsets = {
        { filetype = 'neo-tree', text = 'File Explorer', text_align = 'center' },
      },
    },
  }
end

--- mini.starter dashboard: ASCII banner + recent projects.
---@return nil
function M.setup_starter()
  local ok, starter = pcall(require, 'mini.starter')
  if not ok then return end
  local sessions_dir = vim.fn.stdpath 'data' .. '/auto_session'
  local recent = {}
  local handle = vim.loop.fs_scandir(sessions_dir)
  if handle then
    while true do
      local name = vim.loop.fs_scandir_next(handle)
      if not name then break end
      if name:match '%.vim$' then
        recent[#recent + 1] = {
          name = name:gsub('%.vim$', ''):gsub('_', '/'),
          action = ':SessionRestore ' .. name,
        }
      end
    end
  end
  starter.setup {
    evaluate_single = true,
    header = '   _\n  _ __   ___   __ _ _   _  ___\n | "_ \\ / _ \\ / _` | | | |/ _ \\\n | | | | (_) | (_| | |_| | (_) |\n |_| |_|\\___/ \\__, |\\__,_|\\___/\n              |___/',
    items = {
      { name = 'e  File Explorer', action = 'Neotree toggle' },
      { name = 'ff Find File', action = 'Telescope find_files' },
      { name = 'fg Git (LazyGit)', action = 'LazyGit' },
      { name = 'Recent Projects', action = 'Telescope projects' },
      { name = 'Recent Sessions', action = 'SessionRestore' },
      unpack(recent),
      { name = 'q  Quit', action = 'qa' },
    },
    content_hooks = { starter.gen_hook.aligning('center', 'center') },
  }
end

return M
