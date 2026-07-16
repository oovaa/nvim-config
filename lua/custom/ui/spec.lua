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
      disabled_filetypes = { 'neo-tree', 'TelescopePrompt', 'alpha', 'lazy', 'starter' },
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

--- alpha-nvim dashboard: ASCII banner + recent files + quick actions.
---@return nil
function M.setup_starter()
  local ok, alpha = pcall(require, 'alpha')
  if not ok then return end
  local dashboard = require 'alpha.themes.dashboard'
  local config_dir = vim.fn.stdpath 'config'

  dashboard.section.header.val = {
    '   _                ',
    '  (_) ___ __ _ _ __  ',
    '  | |/ __/ _` | \'_ \\ ',
    '  | | (_| (_| | | | |',
    ' _/ |\\___\\__,_|_| |_|',
    '|__/                ',
  }
  dashboard.section.header.opts.hl = 'Include'

  local recent_files = function()
    local paths, seen = {}, {}
    for _, f in ipairs(vim.v.oldfiles or {}) do
      if #paths >= 9 then break end
      if f:find(config_dir, 1, true) then goto continue end
      if vim.fn.filereadable(f) == 0 then goto continue end
      local key = vim.fn.fnamemodify(f, ':.')
      if not seen[key] then
        seen[key] = true
        paths[#paths + 1] = { f = f, disp = vim.fn.fnamemodify(f, ':~:.') }
      end
      ::continue::
    end
    local entries = {}
    for i, p in ipairs(paths) do
      entries[#entries + 1] = dashboard.button(' ' .. i, p.disp, '<cmd>e ' .. p.f .. '<CR>')
    end
    return entries
  end

  dashboard.section.buttons.val = {
    dashboard.button('e', '  New File', '<cmd>ene<CR>'),
    dashboard.button('f', '  Find File', '<cmd>Telescope find_files<CR>'),
    dashboard.button('r', '  File Explorer', '<cmd>Neotree toggle<CR>'),
    dashboard.button('g', '  Git (LazyGit)', '<cmd>LazyGit<CR>'),
    dashboard.button('s', '  Recent Sessions', '<cmd>SessionRestore<CR>'),
    dashboard.button('u', '  Update Plugins', '<cmd>Lazy sync<CR>'),
    dashboard.button('q', '  Quit', '<cmd>qa<CR>'),
  }

  dashboard.section.footer.val = 'neon-ui · ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch

  alpha.setup {
    layout = {
      { type = 'padding', val = 2 },
      dashboard.section.header,
      { type = 'padding', val = 1 },
      dashboard.section.buttons,
      { type = 'padding', val = 1 },
      {
        type = 'group',
        val = function() return recent_files() end,
        opts = { shrink_margin = false },
      },
      { type = 'padding', val = 1 },
      dashboard.section.footer,
    },
    opts = { margin = 4, noautocmd = false },
  }
end

return M
