---@module 'custom.ui.tabline'
local M = {}
local statusline = require 'custom.ui.statusline'

-- builtin tabline (replaces bufferline.nvim) — buffers as tabs, diagnostics + modified dot
function M.setup_bufferline()
  local function define_hl()
    -- ponytail: adaptive dot fg + seamless bg — TabLine* bg may be nil (transparent themes)
    local sel = vim.api.nvim_get_hl(0, { name = 'TabLineSel' })
    local norm = vim.api.nvim_get_hl(0, { name = 'TabLine' })
    -- accent fallback from the theme's live highlights (statusline uses
    -- String's fg for green); hex is the last resort when the group is absent.
    local function live_fg(name)
      local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name })
      if ok and type(h) == 'table' and type(h.fg) == 'number' then return string.format('#%06x', h.fg) end
      return nil
    end
    local function fg_for(bg)
      if not bg then return live_fg 'String' or '#9ece6a' end
      local r = math.floor(bg / 65536) % 256
      local g = math.floor(bg / 256) % 256
      local b = bg % 256
      local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
      -- light bg -> dark green for contrast, dark bg -> light green
      if luma > 140 then
        return '#005f00'
      else
        return '#9ece6a'
      end
    end
    local function set_mod(name, bg)
      local fg = fg_for(bg)
      if bg then
        vim.api.nvim_set_hl(0, name, { fg = fg, bg = string.format('#%06x', bg), bold = true })
      else
        -- transparent theme: no bg so dot inherits TabLine bg, clear stale bg
        vim.api.nvim_set_hl(0, name, { fg = fg, bold = true })
        -- nvim_set_hl without bg keeps old bg; force clear
        local cur = vim.api.nvim_get_hl(0, { name = name })
        if cur.bg then vim.api.nvim_set_hl(0, name, { fg = fg, bg = nil, bold = true }) end
      end
    end
    set_mod('TabLineMod', norm.bg)
    set_mod('TabLineModSel', sel.bg)
  end
  define_hl()
  local grp = vim.api.nvim_create_augroup('BuiltinTabline', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = grp, callback = define_hl })
  -- Click a buffer tab to switch to it (mouse enabled). Only left-click
  -- switches; anything else is ignored so right-click menus keep working.
  _G._builtin_tabclick = function(bufnr, _, button)
    if button == 'l' and vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_set_current_buf(bufnr) end
  end
  -- ponytail: labeled segments ('E2 W1') not bare numbers ('2 1') — E/W/I/H letters
  -- with the standard Diagnostic* hl groups, so the tabline reads at a glance.
  local function diag_seg(n, letter, hl) return n > 0 and ('%#' .. hl .. '#' .. letter .. n .. ' ') or '' end
  -- %-escape buffer names before they join the tabline (which re-parses % items)
  local function esc(s) return (s:gsub('%%', '%%%%')) end
  _G._builtin_tabline = function()
    local s, idx = '', 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted then
        idx = idx + 1
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
        if name == '' then name = '[No Name]' end
        name = esc(name)
        local is_cur = buf == vim.api.nvim_get_current_buf()
        local hl = is_cur and '%#TabLineSel#' or '%#TabLine#'
        local cnt = statusline._diag_counts[buf] or statusline._count_diags(buf)
        local diag = diag_seg(cnt.e, 'E', 'DiagnosticError')
          .. diag_seg(cnt.w, 'W', 'DiagnosticWarn')
          .. diag_seg(cnt.i, 'I', 'DiagnosticInfo')
          .. diag_seg(cnt.h, 'H', 'DiagnosticHint')
        local mod_hl = is_cur and '%#TabLineModSel#' or '%#TabLineMod#'
        local mod = vim.bo[buf].modified and ' ' .. mod_hl .. '●' .. hl or ''
        s = s .. '%' .. buf .. '@_builtin_tabclick@' .. hl .. ' ' .. idx .. ' ' .. name .. mod .. (diag ~= '' and ' ' .. diag or '') .. ' %X%*'
      end
    end
    return s .. '%#TabLineFill#%='
  end
  vim.o.showtabline = 2
  vim.o.tabline = '%!v:lua._builtin_tabline()'
end

-- aliases for modular entry points
M.setup = M.setup_bufferline

return M
