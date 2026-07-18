# Neon UI Refit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the nvim UI look cooler (polished & colorful) without changing keybindings or behavior, via lualine, a winbar, a mini.starter dashboard, colorizer, smooth scroll, and brighter tokyonight accents.

**Architecture:** New module folder `lua/custom/ui/` (mirrors existing `lua/custom/plugins/` pattern) holds statusline/winbar/theme/dashboard config; `init.lua` calls it from SECTION 5. The tokyonight block is fixed and extended inline. All new plugins defer via VeryLazy/BufRead.

**Tech Stack:** Neovim (Lua), tokyonight.nvim, lualine.nvim, mini.starter, nvim-colorizer.lua, neoscroll.nvim, lazy.nvim.

**Branch:** `feature/neon-ui` off local `master`. Remote `oovaa`. Do NOT merge until user approves after testing.

---

## File Structure

- Create `lua/custom/ui/init.lua` — entry point; `setup()` wires theme, spec, and smooth-cursor autocmd.
- Create `lua/custom/ui/theme.lua` — tokyonight accent extension, `winblend`, and colorizer config.
- Create `lua/custom/ui/spec.lua` — lualine config, winbar, bufferline tuning, mini.starter dashboard.
- Modify `init.lua`:
  - SECTION 3 (Neovim Options, ~110–235): add `winhl` cursorline pop.
  - SECTION 5 (Autocommands, ~311–337): call `require('custom.ui').setup()`.
  - SECTION 6.6 (Colorscheme, ~987–999 / dead block 1001–1006): fix + extend tokyonight.
  - SECTION 6.9 (UI Components, ~1217–1233): point bufferline to `custom.ui.spec`.
  - SECTION 6.16 (Visual Enhancements, ~1483–1533): add colorizer + neoscroll entries.
- Create `docs/superpowers/plans/2026-07-16-neon-ui-refit.md` — this plan.

---

### Task 1: Create branch and commit scaffold

**Files:**
- Repo: `~/.config/nvim` (git)

- [ ] **Step 1: Create and switch to the feature branch**

```bash
git checkout -b feature/neon-ui
```

- [ ] **Step 2: Verify branch**

Run: `git branch --show-current`
Expected: `feature/neon-ui`

- [ ] **Step 3: Commit (no file changes yet, just confirm clean)**

```bash
git status
```
Expected: working tree clean.

---

### Task 2: Fix and extend the tokyonight colorscheme block

**Files:**
- Modify `init.lua:987-1006` (SECTION 6.6)

- [ ] **Step 1: Replace the tokyonight plugin block** (lines 987–1006) with the fixed version below. This removes the dead/orphan block at 1001–1006 and adds brighter accents + window transparency.

```lua
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
        on_colors = function(colors)
          colors.border = colors.blue -- brighter UI borders
        end,
        on_highlights = function(hl, c)
          hl.WinSeparator = { fg = c.blue, bg = 'NONE' }
          hl.CursorLineNr = { fg = c.orange, bold = true }
          hl.CursorLine = { bg = '#1a1b2a' } -- subtle pop on the cursor line
          hl.FloatBorder = { fg = c.blue, bg = 'NONE' }
          hl.NormalFloat = { bg = '#16161e' } -- slightly lifted panel
        end,
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
```

- [ ] **Step 2: Open nvim to confirm it loads without error**

Run: `nvim --headless -c "qa!"` (or open nvim normally)
Expected: no Lua error about `end`/unexpected symbol; colorscheme loads.

- [ ] **Step 3: Commit**

```bash
git add init.lua
git commit -m "fix(ui): remove dead tokyonight block, add accent highlights"
```

---

### Task 3: Create `lua/custom/ui/theme.lua`

**Files:**
- Create `lua/custom/ui/theme.lua`

- [ ] **Step 1: Write the theme module** (tokyonight winblend + colorizer setup)

```lua
---@module 'custom.ui.theme'
local M = {}

--- Setup translucent floats and inline color previews.
---@return nil
function M.setup()
  -- Translucent floating windows for a "glow" feel without terminal alpha.
  vim.opt.winblend = 10
  vim.opt.pumblend = 10

  -- Inline hex/named color previews (toggled with <leader>uc).
  local ok, colorizer = pcall(require, 'colorizer')
  if ok then
    colorizer.setup({ '*' }, {
      RGB = true,
      RRGGBB = true,
      names = true,
      css = true,
    })
  end
end

return M
```

- [ ] **Step 2: Sanity check the file parses as Lua**

Run: `luac -p lua/custom/ui/theme.lua` (if `luac` absent, skip — nvim parse covers it)
Expected: no syntax error (or command not found, which is fine).

- [ ] **Step 3: Commit**

```bash
git add lua/custom/ui/theme.lua
git commit -m "feat(ui): add theme module (winblend + colorizer)"
```

---

### Task 4: Create `lua/custom/ui/spec.lua` (lualine, winbar, bufferline, dashboard)

**Files:**
- Create `lua/custom/ui/spec.lua`

- [ ] **Step 1: Write the spec module**

```lua
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
          action = ':Silent SessionRestore ' .. name,
        }
      end
    end
  end
  starter.setup {
    evaluate_single = true,
    header = '   _
  _ __   ___   __ _ _   _  ___
 | "_ \\ / _ \\ / _` | | | |/ _ \\
 | | | | (_) | (_| | |_| | (_) |
 |_| |_|\\___/ \\__, |\\__,_|\\___/
              |___/',
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
```

- [ ] **Step 2: Parse check**

Run: `luac -p lua/custom/ui/spec.lua` (skip if `luac` missing)
Expected: no syntax error.

- [ ] **Step 3: Commit**

```bash
git add lua/custom/ui/spec.lua
git commit -m "feat(ui): add lualine, winbar, bufferline, starter config"
```

---

### Task 5: Create `lua/custom/ui/init.lua` (wiring + smooth cursor)

**Files:**
- Create `lua/custom/ui/init.lua`

- [ ] **Step 1: Write the entry module**

```lua
---@module 'custom.ui'
local M = {}

local theme = require 'custom.ui.theme'
local spec = require 'custom.ui.spec'

--- Smooth-cursor highlight: brighten CursorLine briefly on movement.
local function setup_smooth_cursor()
  local grp = vim.api.nvim_create_augroup('neon-smooth-cursor', { clear = true })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = grp,
    callback = function()
      vim.cmd 'hi! CursorLine gui=bold'
      vim.defer_fn(function() vim.cmd 'hi! CursorLine gui=NONE' end, 120)
    end,
  })
end

--- Entry point called from init.lua SECTION 5.
---@return nil
function M.setup()
  theme.setup()
  spec.setup_lualine()
  spec.setup_bufferline()
  spec.setup_starter()
  setup_smooth_cursor()
end

return M
```

- [ ] **Step 2: Parse check**

Run: `luac -p lua/custom/ui/init.lua` (skip if missing)
Expected: no error.

- [ ] **Step 3: Commit**

```bash
git add lua/custom/ui/init.lua
git commit -m "feat(ui): wire custom.ui module + smooth cursor"
```

---

### Task 6: Hook `custom.ui` into `init.lua`

**Files:**
- Modify `init.lua` SECTION 5 (Autocommands, after the yank highlight ~336)
- Modify `init.lua` SECTION 6.9 bufferline block (1217–1233) to use spec
- Modify `init.lua` SECTION 6.16 (after 1533) to add colorizer + neoscroll

- [ ] **Step 1: Add the require call in SECTION 5** — after the `kickstart-highlight-yank` autocmd block (line ~337), add:

```lua
-- NEON UI REFIT (SECTION 6.x modules): statusline, winbar, dashboard, glow
pcall(function() require('custom.ui').setup() end)
```

- [ ] **Step 2: Replace the bufferline plugin block** (1217–1233) with one that defers to `custom.ui.spec`:

```lua
  -- BUFFERLINE
  -- WHAT: Shows open buffers as tabs at the top of the screen
  -- TO CHANGE: See lua/custom/ui/spec.lua setup_bufferline
  -- EFFECT: Shift+H/L to switch buffers; <leader>bd to delete a buffer
  --         Shows LSP diagnostics indicators on buffer tabs
  -- LOADING: keys = only loads when you press the keybindings
  -- CONFIG: Tuning lives in lua/custom/ui/spec.lua (diagnostics + icons)
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    config = function() require('custom.ui.spec').setup_bufferline() end,
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bd", "<cmd>bdelete<cr>", desc = "[B]uffer [D]elete" },
    },
  },
```

- [ ] **Step 3: Add colorizer + neoscroll to SECTION 6.16** (after the render-markdown block ~1533):

```lua
  -- COLORIZER
  -- WHAT: Highlights hex (#ff00aa) and named colors inline
  -- TO CHANGE: <leader>uc to toggle
  -- EFFECT: Color swatches appear behind color codes in any buffer
  -- LOADING: BufRead = loads when a file opens
  {
    'norcalli/nvim-colorizer.lua',
    event = 'BufRead',
    opts = {},
  },

  -- NEOSCROLL
  -- WHAT: Smooth animated scrolling on wheel and Ctrl-u/d
  -- TO CHANGE: Adjust lines/time in setup
  -- EFFECT: Scrolling feels eased instead of jumping
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'karb94/neoscroll.nvim',
    event = 'VeryLazy',
    config = function()
      require('neoscroll').setup {
        -- ponytail: defaults are fine; tuned easing for feel
        easing_function = 'quadratic',
        hide_cursor = true,
      }
    end,
  },
```

- [ ] **Step 4: Add the colorizer toggle keymap** in SECTION 4 (Keymaps, after an existing keymap ~280) or near the colorizer block:

```lua
vim.keymap.set('n', '<leader>uc', '<cmd>ColorizerToggle<cr>', { desc = '[U]I [C]olorizer toggle' })
```

- [ ] **Step 5: Open nvim and verify everything loads**

Run: open `nvim` (no file). Expected: dashboard appears; statusline shows at bottom; no Lua errors in `:messages`.
Run: `:Lazy` — expected: lualine, mini.starter, nvim-colorizer.lua, neoscroll.nvim present and loaded.
Run: open a file with a hex color (e.g. a CSS/lua file with `#1a1b2a`) — expected: swatch behind the code.
Run: scroll with mouse wheel — expected: smooth eased scroll.

- [ ] **Step 6: Commit**

```bash
git add init.lua
git commit -m "feat(ui): hook custom.ui into init.lua, add colorizer+neoscroll"
```

---

### Task 7: Push branch and hand off for testing

**Files:**
- Repo: `~/.config/nvim` (git)

- [ ] **Step 1: Push the feature branch to remote `oovaa`**

```bash
git push -u oovaa feature/neon-ui
```

- [ ] **Step 2: Verify remote branch exists**

Run: `git branch -r | grep neon-ui`
Expected: `oovaa/feature/neon-ui`

- [ ] **Step 3: Tell the user how to test**

Message to user:
```
Pushed feature/neon-ui. Test it:
  git -C ~/.config/nvim checkout feature/neon-ui && nvim
Or merge to master first:
  git -C ~/.config/nvim checkout master && git merge feature/neon-ui && nvim
Tell me if it looks good and I'll merge to master. If not, describe what to tweak.
```

- [ ] **Step 4: Do NOT merge to master** until the user approves after testing.

---

## Self-Review Notes

- **Spec coverage:** statusline ✓ (Task 4/6), winbar ✓ (Task 4), dashboard ✓ (Task 4/6), colorizer ✓ (Task 3/6), neoscroll ✓ (Task 6), tokyonight accents ✓ (Task 2), smooth cursor ✓ (Task 5), module layout ✓ (Tasks 3–5), branch/push ✓ (Tasks 1/7). No gaps.
- **Placeholders:** none — all code shown inline.
- **Type consistency:** `M.setup` (init), `theme.setup`, `spec.setup_lualine/setup_bufferline/setup_starter` names consistent across modules. `require('custom.ui')` matches folder `lua/custom/ui/init.lua`. `require('custom.ui.theme')`/`require('custom.ui.spec')` match created files.
- **Caveat:** `mini.starter` session action uses `:Silent SessionRestore` — auto_session's actual command may differ (`SessionRestore` is the documented one); Task 6 step 5 verifies. If `:Silent` errors, change action to `'SessionRestore ' .. name`.
