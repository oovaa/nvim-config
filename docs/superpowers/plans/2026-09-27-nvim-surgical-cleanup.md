# Nvim Surgical Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove neo-tree, telescope, vim-bookmarks, and fidget; migrate their last consumers to snacks/builtin; fix stale config — with zero daily-workflow change (except `<leader>mb` group, dropped per spec).

**Architecture:** Consumers migrate before providers die (M1/M2 before R2; fidget + its statusline replacement in one task so progress UI is never lost). Tests use the repo's existing `plenary.busted` + content-assertion style (`tests/helpers.lua`: `H.all()` raw, `H.code()` comment-stripped). One commit per task.

**Tech Stack:** Neovim 0.12 Lua, lazy.nvim, snacks.nvim picker, plenary.busted (already a transitive dep — never removed).

---

## File structure

| File | Change |
|------|--------|
| `tests/test_cleanup.lua` | CREATE — all new assertions for this plan (appended task by task) |
| `lua/plugins/formatting.lua:18` | M1: actions-preview backend `telescope` → `snacks` |
| `lua/plugins/editing.lua:17-18` | M2: `<leader>st` → `snacks.picker.todo_comments()`, drop `cmd` |
| `lua/plugins/lsp.lua:29` | R4: delete fidget dep |
| `lua/custom/ui/spec.lua:267-269` | M4: statusline shows `vim.lsp.status()` progress |
| `lua/custom/ui/spec.lua:180` | R1: drop `neo-tree`/`TelescopePrompt` ft arms |
| `lua/custom/ui/spec.lua:404,435` | R1: drop `silent! Neotree close` |
| `lua/custom/ui/spec.lua:439-445` | M5: drop telescope session-picker branch |
| `lua/plugins/ui.lua:14-46` | R1: delete neo-tree spec |
| `lua/plugins/visual.lua:95-187` | R2: delete telescope spec block |
| `lua/plugins/bookmarks.lua` | R3: DELETE file |
| `lua/plugins/visual.lua:75` | R3: which-key `<leader>m` group relabel to `[M]olten` |
| `lua/config/sessions.lua:85` | R1: drop `silent! Neotree close` |
| `lua/config/terminal.lua:78-84` | R1: drop neo-tree float guard/comments |
| `lua/config/options.lua:54-55,157-158,210` | R1 comment + F1 lazyredraw flip + F4 |
| `lua/plugins/completion.lua:23` | F2: `has 'win32'` → `vim.uv.os_uname()` |
| `lua/config/health.lua:10,17-18,20` | F3: reword rg/fd/make, drop cmake |
| `init.lua:14,40,46,63` | header updates (startup line, LAYOUT, keymap ref) |
| Comment sweep (F4+M6) | `visual.lua:39-51,62,64,85-86,201`; `lsp.lua:87,133`; `appearance.lua:57-59`; `spec.lua:153,221,248`; `qol.lua:43-44` |
| `tests/test_modular.lua`, `tests/test_performance.lua` | Task 9: update for removals |

Run all test commands with cwd `~/.config/nvim`. Full-suite command lists every file (no runner script exists).

---

### Task 1: Baseline measurements

**Files:** none (record only)

- [ ] **Step 1: Record startup baseline**

Run: `nvim --headless --startuptime /tmp/before.log +q && sort -k2 /tmp/before.log | tail -n 5`
Expected: tail prints 5 slowest sources; note total from the `-- NVIM STARTED --` line.

- [ ] **Step 2: Record plugin count**

Run: `nvim --headless -c "lua local s = require('lazy').stats(); print(string.format('%d/%d plugins in %.1fms', s.loaded, s.count, s.startuptime))" -c "qa!" 2>&1 | tail -1`
Expected: prints e.g. `N/M plugins in Xms`. Jot both numbers down — Task 13 compares against them.

---

### Task 2: M1 — actions-preview backend telescope → snacks

**Files:**
- Create: `tests/test_cleanup.lua`
- Modify: `lua/plugins/formatting.lua:18`

- [ ] **Step 1: Write the failing test** — create `tests/test_cleanup.lua`:

```lua
-- Surgical cleanup assertions.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!'

describe('surgical cleanup', function()
  local H = require('tests.helpers')

  describe('M1 actions-preview', function()
    it('uses the snacks backend, not telescope', function()
      local code = H.code() -- comments stripped: checks code, not prose
      local spec = code:match "'aznhe21/actions%-preview%.nvim'.-\n  %},"
      assert.is_not_nil(spec, 'actions-preview spec should exist')
      assert.is_truthy(spec:match "backend%s*=%s*{%s*'snacks'", 'backend must be snacks')
      assert.is_nil(spec:match 'telescope', 'no telescope string in the actions-preview block')
      -- NOTE: global telescope absence is asserted by Task 6 (R2), after
      -- bookmarks.lua (which still requires telescope) is deleted in Task 8.
    end)
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `backend must be snacks`.

- [ ] **Step 3: Write minimal implementation** — in `lua/plugins/formatting.lua:18`:

```lua
    opts = { backend = { 'snacks' } },
```

(replacing `opts = { backend = { 'telescope' } },`; also update the comment on line 16-17 if it names telescope — that prose is covered by Task 12's sweep, leave it for now.)

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (1/1).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/formatting.lua
git commit -m "feat: actions-preview uses snacks backend"
```

---

### Task 3: M2 — `<leader>st` TodoTelescope → snacks todo_comments

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/plugins/editing.lua:17-18`

- [ ] **Step 1: Write the failing test** — append inside `describe('surgical cleanup', ...)`:

```lua
  describe('M2 todo picker', function()
    it('<leader>st uses snacks todo_comments, TodoTelescope is gone', function()
      local code = H.code()
      assert.is_nil(code:match 'TodoTelescope', 'TodoTelescope must be gone')
      assert.is_truthy(code:match 'todo_comments%(%)', '<leader>st must call snacks picker todo_comments')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `TodoTelescope must be gone`.

- [ ] **Step 3: Write minimal implementation** — in `lua/plugins/editing.lua`, replace:

```lua
    event = 'VeryLazy',
    cmd = 'TodoTelescope',
    keys = { { '<leader>st', '<cmd>TodoTelescope<cr>', desc = '[S]earch [T]odo comments' } },
```

with:

```lua
    event = 'VeryLazy',
    keys = { { '<leader>st', function() require('snacks').picker.todo_comments() end, desc = '[S]earch [T]odo comments' } },
```

(`todo-comments.nvim` registers the `todo_comments` picker source itself when snacks is present — verified in the installed plugin at `lua/todo-comments/snacks.lua`. `VeryLazy` keeps it off the startup path.)

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/editing.lua
git commit -m "feat: todo picker migrates to snacks"
```

---

### Task 4: R4+M4 — remove fidget, statusline shows `vim.lsp.status()`

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/plugins/lsp.lua:29` (delete fidget line)
- Modify: `lua/custom/ui/spec.lua:267-269`

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('R4/M4 lsp progress', function()
    it('fidget is gone; statusline shows vim.lsp.status()', function()
      local code = H.code()
      assert.is_nil(code:match 'fidget', 'fidget spec must be gone')
      assert.is_truthy(code:match 'vim%.lsp%.status%(%)', 'statusline must read vim.lsp.status()')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `fidget spec must be gone`.

- [ ] **Step 3: Write minimal implementation**

(a) Delete the fidget line in `lua/plugins/lsp.lua`:

```lua
      -- Shows LSP loading progress in the bottom-right corner
      { 'j-hui/fidget.nvim', opts = {} },
```

(b) In `lua/custom/ui/spec.lua`, replace:

```lua
    local lsp_s = M._lsp_name.name == '' and '' or '%#SL_lsp#  ' .. M._lsp_name.name .. hl_c
```

with:

```lua
    -- ponytail: vim.lsp.status() carries $/progress text while servers work;
    -- show it live, fall back to the cached client name when idle.
    local prog = vim.lsp.status()
    local lsp_s = prog ~= '' and ('%#SL_lsp#' .. prog .. hl_c)
      or (M._lsp_name.name == '' and '' or '%#SL_lsp#  ' .. M._lsp_name.name .. hl_c)
```

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/lsp.lua lua/custom/ui/spec.lua
git commit -m "feat: builtin lsp status replaces fidget"
```

---

### Task 5: R1 — remove neo-tree

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/plugins/ui.lua` (delete lines 8-46 neo-tree spec block)
- Modify: `lua/config/sessions.lua:85` (drop `pcall(vim.cmd, 'silent! Neotree close')`, keep the `mkdir` + `mksession` lines)
- Modify: `lua/custom/ui/spec.lua:180,404,435` (trim ft arms, drop close calls)
- Modify: `lua/config/terminal.lua:78-84` (drop neo-tree float guard)
- Modify: `lua/config/options.lua:54-55` (reword comment)
- Modify: `init.lua:46` (LAYOUT line: `neo-tree, snacks, nvim-lint` → `snacks, nvim-lint`)

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('R1 neo-tree', function()
    it('neo-tree spec and close calls are gone', function()
      local code = H.code()
      assert.is_nil(code:match 'neo%-tree', 'no neo-tree code must remain')
      assert.is_nil(code:match 'Neotree', 'no :Neotree references must remain')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `no neo-tree code must remain`.

- [ ] **Step 3: Write minimal implementation**

(a) `lua/plugins/ui.lua`: delete the whole neo-tree spec table (the `-- NEO-TREE` comment through its closing `},`), keep the BUILTIN UI comment and snacks spec.

(b) `lua/config/sessions.lua:85`: delete the line `pcall(vim.cmd, 'silent! Neotree close')`.

(c) `lua/custom/ui/spec.lua:180`: `if ft == 'neo-tree' or ft == 'TelescopePrompt' or ft == 'lazy' or ft == 'dashboard' then` → `if ft == 'lazy' or ft == 'dashboard' then`. Lines 404/435: delete the `pcall(vim.cmd, 'silent! Neotree close'); ` prefix (keep the rest of each statement).

(d) `lua/config/terminal.lua`: delete the neo-tree float guard block (comment line 78 + the `if ... filetype == 'neo-tree'` early-return, lines 78-83); fix the E444 comment on line 84 to drop the neo-tree mention.

(e) `lua/config/options.lua:54-55`: `neo-tree replaces netrw` → `snacks explorer replaces netrw`; `avoids netrw/neo-tree explorer conflicts` → `avoids netrw/explorer conflicts`.

(f) `init.lua:46` LAYOUT line: `lua/plugins/ui.lua           neo-tree, snacks, nvim-lint` → `lua/plugins/ui.lua           snacks explorer, nvim-lint`.

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/ui.lua lua/config/sessions.lua lua/custom/ui/spec.lua lua/config/terminal.lua lua/config/options.lua init.lua
git commit -m "feat: remove neo-tree, snacks explorer owns files"
```

---

### Task 6: R2 — remove telescope

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/plugins/visual.lua` (delete lines 95-187 telescope spec block)
- Modify: `init.lua:40` (LAYOUT line: drop `telescope` from visual.lua description)

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('R2 telescope', function()
    it('telescope, fzf-native and ui-select specs are gone', function()
      local code = H.code()
      assert.is_nil(code:match 'telescope%.nvim', 'telescope spec must be gone')
      assert.is_nil(code:match 'fzf%-native', 'fzf-native spec must be gone')
      assert.is_nil(code:match 'ui%-select', 'ui-select spec must be gone')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `telescope spec must be gone`.

- [ ] **Step 3: Write minimal implementation**

(a) `lua/plugins/visual.lua`: delete from `{ -- Fuzzy Finder (files, lsp, etc)` through the closing `},` of the telescope spec (lines 95-187). Keep guess-indent, gitsigns, noice comment (Task 12), which-key.

(b) `init.lua:40`: `lua/plugins/visual.lua       guess-indent, gitsigns, which-key, telescope` → `lua/plugins/visual.lua       guess-indent, gitsigns, which-key`.

Note: `<leader>mb` still references `require('telescope')` until Task 8 — suite stays red on R3's test until then; that is expected ordering (provider dies before its last consumer is deleted in the next task).

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: new block passes (5/5 for the blocks so far touching telescope specs; R3 block not yet written).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/visual.lua init.lua
git commit -m "feat: remove telescope, snacks picker owns search"
```

---

### Task 7: M5 — dashboard session picker drops telescope branch

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/custom/ui/spec.lua:439-445`

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('M5 session picker', function()
    it('dashboard session picker has no telescope branch', function()
      local code = H.code()
      assert.is_nil(code:match 'telescope%.pickers', 'dashboard must not require telescope pickers')
      assert.is_truthy(code:match 'vim%.ui%.select', 'vim.ui.select fallback must remain')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `must not require telescope pickers`.

- [ ] **Step 3: Write minimal implementation** — in `lua/custom/ui/spec.lua`, replace:

```lua
      if pcall(require, 'telescope') then
        local pickers, finders, conf = require('telescope.pickers'), require('telescope.finders'), require('telescope.config').values
        pickers.new({}, { prompt_title = 'Sessions', finder = finders.new_table { results = items }, sorter = conf.generic_sorter({}), previewer = false, attach_mappings = function(_, m)
          m('i', '<CR>', function(pb) local sel = require('telescope.actions.state').get_selected_entry(); require('telescope.actions').close(pb); do_pick(sel[1]) end)
          m('n', '<CR>', function(pb) local sel = require('telescope.actions.state').get_selected_entry(); require('telescope.actions').close(pb); do_pick(sel[1]) end)
          return true end }):find()
      else pick() end
```

with:

```lua
      pick()
```

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/custom/ui/spec.lua
git commit -m "feat: session picker uses vim.ui.select only"
```

---

### Task 8: R3 — delete bookmarks section

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Delete: `lua/plugins/bookmarks.lua`
- Modify: `lua/plugins/visual.lua:75` (which-key `<leader>m` label)
- Modify: `init.lua:63` (keymap reference line)

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('R3 bookmarks', function()
    it('vim-bookmarks specs and keys are gone', function()
      local code = H.code()
      assert.is_nil(code:match '[Bb]ookmark', 'no bookmark code must remain')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `no bookmark code must remain`.

- [ ] **Step 3: Write minimal implementation**

(a) `git rm lua/plugins/bookmarks.lua` (auto-imported via `{ import = 'plugins' }` — deletion is the whole removal).

(b) `lua/plugins/visual.lua:75`: `{ '<leader>m', group = '[M]olten & Book[m]arks' },` → `{ '<leader>m', group = '[M]olten' },`.

(c) `init.lua:63`: `Bookmarks:   <leader>mt/mc/mj/mk/mb` line — delete it.

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (full file green).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/visual.lua init.lua
git rm lua/plugins/bookmarks.lua
git commit -m "feat: remove vim-bookmarks section"
```

---

### Task 9: Repair existing suite for removals

**Files:**
- Modify: `tests/test_modular.lua`
- Modify: `tests/test_performance.lua`

Context: three existing tests assert the pre-cleanup state and now fail. Update them — no behavior change.

- [ ] **Step 1: Confirm the failures**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_modular.lua")' -c 'qa!' 2>&1 | tail -8`
Expected: FAIL on `lost spec` (telescope/neo-tree/bookmarks) and `missing lua/plugins/bookmarks.lua`.

- [ ] **Step 2: Update `tests/test_modular.lua`**

(a) modules list (line 29-33): remove `'bookmarks'` → eleven modules remain.

(b) kept-spec list (lines 53-62): remove `'nvim-telescope/telescope.nvim'`, `'nvim-neo-tree/neo-tree.nvim'`, `'tom-anders/telescope-vim-bookmarks.nvim'`.

(c) init must-not-contain list (lines 13-17): remove `'telescope.nvim'` and `'neo-tree.nvim'` (they are gone everywhere now, asserting their absence from init.lua is vacuous).

- [ ] **Step 3: Update `tests/test_performance.lua`**

(a) Delete Test 5 `describe('telescope-fzf-native', ...)` block (lines 139-151) entirely.

(b) Rewrite Test 9 (lines 202-219) as removal proof:

```lua
  -- Test 9: telescope + noice removed, daily keys on snacks
  describe('picker migration complete', function()
    it('telescope and noice specs are gone; search keys live on snacks', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()
      local code = content:gsub('%-%-[^\n]*', '') -- strip comments: check code, not prose
      assert.is_nil(code:match "'folke/noice%.nvim'", 'noice spec should be removed')
      assert.is_nil(code:match "'nvim%-telescope/telescope%.nvim'", 'telescope spec should be removed')
      assert.is_truthy(code:match "'folke/snacks%.nvim'", 'snacks spec should exist')
      local sspec = code:match "'folke/snacks%.nvim'.-\n  %},"
      assert.is_not_nil(sspec, 'snacks spec should exist')
      for _, k in ipairs { '<leader>sf', '<leader>sg', '<leader>sd', '<leader>e', '<leader>fe' } do
        assert.is_truthy(sspec:find(k, 1, true), k .. ' should be a snacks key')
      end
      -- NOTE: <leader>st lives on the todo-comments spec (Task 3 test), not here.
    end)
  end)
```

- [ ] **Step 4: Run both files to verify they pass**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_modular.lua")' -c 'qa!' 2>&1 | tail -3`
Expected: PASS. Then: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_performance.lua")' -c 'qa!' 2>&1 | tail -3`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_modular.lua tests/test_performance.lua
git commit -m "test: suite matches post-cleanup plugin set"
```

---

### Task 10: F1+F2 — lazyredraw flip + win32 idiom

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/config/options.lua:157-158`
- Modify: `lua/plugins/completion.lua:23`

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('F1/F2 modern APIs', function()
    it('lazyredraw is on; win32 check uses vim.uv', function()
      local code = H.code()
      assert.is_truthy(code:match 'lazyredraw%s*=%s*true', 'lazyredraw must be re-enabled (noice is gone)')
      assert.is_nil(code:match "has%s*'win32'", 'legacy has-win32 check must be gone')
      assert.is_truthy(code:match 'os_uname', 'platform check must use vim.uv.os_uname')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `lazyredraw must be re-enabled`.

- [ ] **Step 3: Write minimal implementation**

(a) `lua/config/options.lua`: replace

```lua
-- NOTE: Disabled because it conflicts with Noice.nvim
vim.o.lazyredraw = false
```

with:

```lua
-- Enabled: defers redraws during macros/scripts. Was disabled for Noice.nvim,
-- which has since been removed (snacks notifier+input own the cmdline).
vim.o.lazyredraw = true
```

(b) `lua/plugins/completion.lua:23`: `if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end` → `if vim.uv.os_uname().sysname == 'Windows_NT' or vim.fn.executable 'make' == 0 then return end`.

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/config/options.lua lua/plugins/completion.lua
git commit -m "fix: re-enable lazyredraw, modernize win32 check"
```

---

### Task 11: F3 — health check rewording

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/config/health.lua`

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('F3 health check', function()
    it('no fzf-native rows; make row names luasnip', function()
      local c = H.read(vim.fn.stdpath 'config' .. '/lua/config/health.lua')
      assert.is_nil(c:match 'fzf', 'no fzf-native rows must remain')
      assert.is_nil(c:match 'cmake', 'cmake row must be gone with fzf-native')
      assert.is_truthy(c:match '[Ll]uaSnip', 'make row must name the LuaSnip build')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `no fzf-native rows must remain`.

- [ ] **Step 3: Write minimal implementation** — in `lua/config/health.lua`:

(a) `{ bin = 'rg', why = 'telescope live_grep, grug-far' }` → `{ bin = 'rg', why = 'snacks grep, grug-far' }`.

(b) `{ bin = 'make', why = 'telescope-fzf-native build' }` → `{ bin = 'make', why = 'LuaSnip jsregexp build' }`.

(c) `{ bin = 'fd', why = 'telescope find_files speed' }` → `{ bin = 'fd', why = 'snacks picker speed' }`.

(d) Delete the `{ bin = 'cmake', why = 'telescope-fzf-native build' },` line.

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS. Also run `:checkhealth config` manually once and eyeball output.

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/config/health.lua
git commit -m "fix: health check drops fzf-native rows"
```

---

### Task 12: F4+M6 — stale comment sweep

**Files:**
- Modify: `tests/test_cleanup.lua` (append block)
- Modify: `lua/plugins/visual.lua`, `lua/config/options.lua`, `lua/plugins/ui.lua`, `lua/plugins/lsp.lua`, `lua/plugins/appearance.lua`, `lua/custom/ui/spec.lua`, `lua/custom/plugins/qol.lua`

- [ ] **Step 1: Write the failing test** — append:

```lua
  describe('F4 stale comments', function()
    it('no noice/telescope/neo-tree prose remains', function()
      local all = H.all() -- prose included: this one checks comments
      assert.is_nil(all:match '[Nn]oice', 'no noice prose must remain')
      assert.is_nil(all:match '[Tt]elescope', 'no telescope prose must remain')
      assert.is_nil(all:match '[Nn]eo%-?[Tt]ree', 'no neo-tree prose must remain')
    end)
  end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_cleanup.lua")' -c 'qa!' 2>&1 | tail -5`
Expected: FAIL on `no noice prose must remain`.

- [ ] **Step 3: Write minimal implementation** (comments only, no behavior change):

(a) `visual.lua`: delete the commented noice block (lines 39-51); line 62 `(only loaded transitively via noice)` → `(only loaded on demand)`; lines 64, 85-86, 201: reword telescope/neo-tree remarks to snacks (e.g. line 201 `migrated from telescope (keys identical)` → `owns daily search (keys kept stable)`).

(b) `options.lua:210`: `(noice, blink, telescope)` → `(blink, snacks)`.

(c) `lsp.lua:87`: `(diff preview, telescope UI)` → `(diff preview, snacks UI)`; line 133: `(telescope kept cmd-only for vim_bookmarks + ui-select)` → delete the parenthetical.

(d) `appearance.lua:57-59`: `Or use telescope! ... resumes last telescope search` → `Or use snacks! ... <space>sr resumes last snacks search`.

(e) `spec.lua:153,221,248`: `noice-style` / `noice parity` → plain wording (`[cur/total]`, `recording indicator`).

(f) `qol.lua:43-44`: `vim.ui.select via telescope-ui-select` → `vim.ui.select via builtin (plain) until a picker override is chosen`.

(g) Leftover explorer prose: `ui.lua:51` → drop the neo-tree clause (`zero requires anywhere` only); `ui.lua:226` (`Explorer trial (neo-tree kept cmd-only...)`) → `Explorer (snacks.explorer owns daily files)`; `options.lua:59` trailing comment → `-- File explorer (replaced by snacks explorer)`; `spec.lua:178` → `-- disabled filetypes like lualine: lazy / dashboard`.

After edits, re-run the Task 12 test; if it names a leftover, fix that line too (the test is the checklist).

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (whole file green).

- [ ] **Step 5: Commit**

```bash
git add tests/test_cleanup.lua lua/plugins/visual.lua lua/config/options.lua lua/plugins/ui.lua lua/plugins/lsp.lua lua/plugins/appearance.lua lua/custom/ui/spec.lua lua/custom/plugins/qol.lua
git commit -m "docs: sweep stale telescope/noice/neo-tree comments"
```

---

### Task 13: Final verification + startup header

**Files:**
- Modify: `init.lua:14` (measured startup line)

- [ ] **Step 1: Run the FULL suite — every file green**

Run each (cwd `~/.config/nvim`), all must PASS:
```bash
for t in test_cleanup test_modular test_performance test_critical_fixes test_keymaps_autocmds test_lsp_servers test_polish test_qol; do nvim --headless -c "lua require('plenary.busted').run('tests/$t.lua')" -c 'qa!' 2>&1 | tail -1; done
```
Expected: 8 PASS lines, zero FAILs.

- [ ] **Step 2: Review what `:Lazy clean` would remove**

Run: `nvim --headless -c 'Lazy clean' -c 'qa!'` — interactive; instead run `nvim -c 'Lazy clean' +q` in a terminal and confirm the removal list is exactly: neo-tree.nvim (+ nui.nvim orphan), telescope.nvim, telescope-fzf-native, telescope-ui-select, telescope-vim-bookmarks, vim-bookmarks, fidget.nvim. Confirm `plenary.nvim` is NOT listed (todo-comments/neotest/rest/vtsls keep it). Then accept the clean.

- [ ] **Step 3: Measure new startup and update the header**

Run: `nvim --headless --startuptime /tmp/after.log +q && sort -k2 /tmp/after.log | tail -n 5`
Expected: total ≤ Task 1 baseline. Update `init.lua:14` `MEASURED STARTUP TIME` line with the new number and date.

- [ ] **Step 4: Smoke test (manual, 2 min)**

`:checkhealth config` clean · `gra` on an error (snacks code-action UI) · `<leader>st` (todo picker) · record + replay a macro (lazyredraw flip) · dashboard `s` (session select) · open a Python/TS file (LSP attaches, progress text appears in statusline).

- [ ] **Step 5: Commit**

```bash
git add init.lua
git commit -m "docs: post-cleanup startup number"
```

---

## Coverage map (spec → tasks)

R1 → Task 5 · R2 → Task 6 · R3 → Task 8 · R4 → Task 4 · M1 → Task 2 ·
M2 → Task 3 · M3 → Task 8 · M4 → Task 4 · M5 → Task 7 · M6 → Task 12 ·
F1/F2 → Task 10 · F3 → Task 11 · F4 → Task 12 · Verification → Tasks 1, 13.
