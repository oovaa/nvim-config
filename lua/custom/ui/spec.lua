---@module 'custom.ui.spec'
local M = {}

-- builtin statusline (replaces lualine.nvim) — same sections, tokyonight colors
function M.setup_lualine()
  vim.o.laststatus = 3 -- globalstatus
  vim.o.showmode = false
  local function lsp_name()
    local c = vim.lsp.get_clients { bufnr = 0 }
    return #c == 0 and '' or '󰄶 ' .. c[1].name
  end
  local function git_branch()
    local b = vim.b.gitsigns_head or vim.g.gitsigns_head
    return b and b ~= '' and (' ' .. b) or ''
  end
  local function diagnostics()
    local d = vim.diagnostic.get(0)
    if #d == 0 then return '' end
    local cnt = { 0, 0, 0, 0 }
    for _, v in ipairs(d) do cnt[v.severity] = cnt[v.severity] + 1 end
    local icons = { '', '', '', '' }
    local s = {}
    for i = 1, 4 do if cnt[i] > 0 then s[#s + 1] = icons[i] .. cnt[i] end end
    return table.concat(s, ' ')
  end
  _G._builtin_statusline = function()
    local mode = vim.fn.mode():upper()
    local branch = git_branch()
    local diag = diagnostics()
    local fname = vim.fn.expand '%:~:.'
    if fname == '' then fname = '[No Name]' elseif vim.bo.modified then fname = fname .. ' [+]' end
    local lsp = lsp_name()
    local enc = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
    local ft = vim.bo.filetype
    local loc = '%l:%c'
    local pct = '%p%%'
    -- left: mode | branch diag | filename   right: lsp | enc ft | pct loc
    local left = string.format(' %s %s %s %%f%%m', mode, branch, diag)
    -- use %f for filename handled above via fname; inject manually
    -- ponytail: keep it simple — statusline is a Vim expression, not a lua concat per redraw
    return string.format(' %s  %s %s │ %s │ %s %s │ %s %s ', mode, branch, diag, fname, lsp, enc .. (ft ~= '' and ' ' .. ft or ''), pct, loc)
  end
  vim.o.statusline = '%!v:lua._builtin_statusline()'
end

-- builtin tabline (replaces bufferline.nvim) — buffers as tabs, diagnostics indicator
function M.setup_bufferline()
  _G._builtin_tabline = function()
    local s = ''
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
        if name == '' then name = '[No Name]' end
        local d = vim.diagnostic.get(buf)
        local cnt = { 0, 0, 0, 0 }
        for _, v in ipairs(d) do cnt[v.severity] = cnt[v.severity] + 1 end
        local icons = { '', '', '', '' }
        local diag = ''
        for i = 1, 4 do if cnt[i] > 0 then diag = diag .. icons[i] .. cnt[i] .. ' ' end end
        local hl = buf == vim.api.nvim_get_current_buf() and '%#TabLineSel#' or '%#TabLine#'
        s = s .. hl .. ' ' .. name .. (diag ~= '' and ' ' .. diag or '') .. ' %*'
      end
    end
    return s .. '%#TabLineFill#%='
  end
  vim.o.showtabline = 2
  vim.o.tabline = '%!v:lua._builtin_tabline()'
end

-- builtin dashboard (replaces alpha-nvim) — scratch buffer on VimEnter when no args
function M.setup_starter()
  local header = {
    '   _                ',
    '  (_) ___ __ _ _ __  ',
    "  | |/ __/ _` | '_ \\ ",
    '  | | (_| (_| | | | |',
    ' _/ |\\___\\__,_|_| |_|',
    '|__/                ',
  }
  local config_dir = vim.fn.stdpath 'config'
  local function recent_files()
    local out, seen = {}, {}
    for _, f in ipairs(vim.v.oldfiles or {}) do
      if #out >= 9 then break end
      if f:find(config_dir, 1, true) then goto continue end
      if vim.fn.filereadable(f) == 0 then goto continue end
      local key = vim.fn.fnamemodify(f, ':.')
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = ' ' .. #out + 1 .. '  ' .. vim.fn.fnamemodify(f, ':~:.')
      end
      ::continue::
    end
    return out
  end
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      if vim.fn.argc() > 0 or vim.api.nvim_buf_get_name(0) ~= '' then return end
      if vim.bo.filetype ~= '' then return end
      local buf = vim.api.nvim_get_current_buf()
      local lines = {}
      vim.list_extend(lines, { '', '' })
      vim.list_extend(lines, header)
      vim.list_extend(lines, { '', '  e  New File      f  Find File      r  File Explorer', '  g  Git (LazyGit) s  Recent       u  Update Plugins  q  Quit', '' })
      vim.list_extend(lines, recent_files())
      vim.list_extend(lines, { '', 'neon-ui · ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].modifiable = false
      vim.bo[buf].filetype = 'dashboard'
      vim.keymap.set('n', 'e', '<cmd>ene<CR>', { buffer = buf })
      vim.keymap.set('n', 'f', '<cmd>Telescope find_files<CR>', { buffer = buf })
      vim.keymap.set('n', 'r', '<cmd>Neotree toggle<CR>', { buffer = buf })
      vim.keymap.set('n', 'g', function()
        if vim.fn.exists ':LazyGit' == 2 then vim.cmd 'LazyGit' else vim.cmd 'terminal lazygit' end
      end, { buffer = buf })
      vim.keymap.set('n', 'q', '<cmd>qa<CR>', { buffer = buf })
    end,
  })
end

return M
