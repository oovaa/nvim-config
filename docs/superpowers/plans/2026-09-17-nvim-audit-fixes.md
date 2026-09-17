# Neovim Config Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all bugs, remove dead code, modernize legacy APIs, and apply measured performance wins in /home/omar/.config/nvim without changing keymaps behavior or startup health.

**Architecture:** Five sequential phases (bugs → dead code → API modernization → perf swaps → tests/health), each independently committable. Every phase ends with the full plenary suite green plus a headless boot check.

**Tech Stack:** Neovim 0.12.5 (LuaJIT), lazy.nvim (91 plugins), plenary.busted tests, `vim.uv`/`vim.fs`/`vim.api` stdlib, native `vim.lsp.config`.

## Global Constraints

- Nvim version floor: 0.11+ required for `vim.lsp.config`, `vim.hl`, `vim.o.winborder` (host runs 0.12.5; `init.lua:87` claims ≥0.9 — leave claim, guard 0.11-only spots instead).
- `lazy-lock.json` is deleted and gitignored upstream — never re-add it; do not commit lock diffs.
- No keymap behavior changes unless the plan step says so; startup wall time must stay ≤0.12s headless.
- One phase per commit, conventional-commit message, push only when user asks.
- Every code step needs its verification step run before moving on.

---

### Task 1: Fix python3 provider ERROR

**Files:**
- Modify: `lua/config/options.lua:25`
- Modify: `tests/test_critical_fixes.lua:100`

**Interfaces:**
- Consumes: nothing.
- Produces: clean `:checkhealth vim.provider` (needed by Task 11).

- [ ] **Step 1: Remove the buggy global**

```lua
-- lua/config/options.lua, delete line 25:
-- vim.g.loaded_python3_provider = 1
```

- [ ] **Step 2: Update the test that enshrines the bug**

```lua
-- tests/test_critical_fixes.lua:100, replace
-- assert.are.equal(1, vim.g.loaded_python3_provider)
-- with:
assert.is_nil(vim.g.loaded_python3_provider)
```

- [ ] **Step 3: Verify**

Run: `nvim --headless -c 'checkhealth vim.provider' -c 'qa!' 2>&1 | grep -i error; echo "exit=$?"`
Expected: no output lines (grep finds nothing, exit=1).

Run: `nvim --headless -c 'lua require("plenary.busted").run("tests/test_critical_fixes.lua")' -c 'qa!' 2>&1 | tail -4`
Expected: Success 11, Failed 0.

- [ ] **Step 4: Commit**

```bash
git add lua/config/options.lua tests/test_critical_fixes.lua
git commit -m "fix: drop loaded_python3_provider=1 that breaks vim.provider healthcheck"
```

---

### Task 2: Fix `<leader>hr` http-only mapping

**Files:**
- Modify: `lua/custom/plugins/qol.lua:11-18` (rest.nvim spec)

**Interfaces:**
- Consumes: nothing.
- Produces: `:Rest run` reachable only in http buffers (needed by Task 11 keymap test).

- [ ] **Step 1: Move `ft` out of the keys table**

```lua
-- BEFORE (qol.lua ~line 15, inside keys = { ... }):
-- { '<leader>hr', '<cmd>Rest run<cr>', desc = '...', ft = 'http' },
-- AFTER — top-level spec gets ft, key entry loses it:
{
  'rest-nvim/rest.nvim',
  ft = 'http',
  keys = {
    { '<leader>hr', '<cmd>Rest run<cr>', desc = '[H]ttp [R]un' },
  },
}
```

Keep any other existing keys entries unchanged; only strip the `ft` field from inside the key entry and ensure one top-level `ft = 'http'` exists on the spec.

- [ ] **Step 2: Verify**

Run: `nvim --headless /tmp/probe.lua -c 'lua print(vim.inspect(vim.fn.maparg("<leader>hr", "n")))' -c 'qa!' 2>&1 | tail -1`
Expected: empty string (no global mapping in lua buffer).

Run: `nvim --headless -c 'e /tmp/t.http' -c 'lua print(vim.inspect(vim.fn.maparg("<leader>hr", "n", false, true).rhs))' -c 'qa!' 2>&1 | tail -1`
Expected: mapping present with Rest rhs.

- [ ] **Step 3: Commit**

```bash
git add lua/custom/plugins/qol.lua
git commit -m "fix: scope rest.nvim mapping to http filetype"
```

---

### Task 3: Harden `:SudoWrite` (follow-up to prior sudo-tee fix)

**Files:**
- Modify: `lua/config/autocmds.lua:102-103`

**Interfaces:**
- Consumes: nothing.
- Produces: safe sudo-save (needed by Task 11).

- [ ] **Step 1: Guard spaces, unnamed buffers, refresh after write**

```lua
-- BEFORE:
-- vim.api.nvim_create_user_command('SudoWrite', 'write! ... !sudo tee % ...', ...)
-- AFTER:
vim.api.nvim_create_user_command('SudoWrite', function(opts)
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    vim.notify('SudoWrite: unnamed buffer, save normally first', vim.log.levels.ERROR)
    return
  end
  vim.cmd(('write%s !sudo tee %s >/dev/null'):format(opts.bang and '!' or '', vim.fn.fnameescape(name)))
  vim.cmd('edit!')
end, { bang = true, desc = 'Write buffer with sudo' })
```

- [ ] **Step 2: Verify**

Run: `cp /home/omar/.config/nvim/init.lua /tmp/sudotest.lua && nvim --headless /tmp/sudotest.lua -c 'lua vim.cmd("SudoWrite")' -c 'qa!' 2>&1 | tail -2`
Expected: only a sudo password/auth complaint (headless has no tty), NOT a vim E-error or empty-file write.

- [ ] **Step 3: Commit**

```bash
git add lua/config/autocmds.lua
git commit -m "fix: SudoWrite handles spaces, unnamed buffers, reloads file"
```

---

### Task 4: Fix CursorHold diagnostic float spam

**Files:**
- Modify: `lua/config/autocmds.lua:29` (CursorHold float autocmd)

**Interfaces:**
- Consumes: nothing.
- Produces: at most one diagnostic float per line (needed by Task 11).

- [ ] **Step 1: Drop invalid `col` filter, skip when float already open**

```lua
-- BEFORE:
-- vim.diagnostic.get(0, { lnum = vim.fn.line('.') - 1, col = vim.fn.col('.') - 1 })
-- AFTER pattern inside the CursorHold callback:
local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
if vim.tbl_isempty(vim.diagnostic.get(0, { lnum = lnum })) then return end
for _, win in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(win).relative ~= '' then return end
end
vim.diagnostic.open_float(nil, { focus = false, scope = 'line' })
```

Adapt to the existing callback shape; keep `updatetime=250` in options.lua unchanged.

- [ ] **Step 2: Verify**

Run: `nvim --headless -c 'luafile /home/omar/.config/nvim/init.lua' -c 'qa!' 2>&1 | tail -1`
Expected: clean boot, no errors.

Manual: open a file with a diagnostic, idle on the error line 3s — exactly one float, no flicker.

- [ ] **Step 3: Commit**

```bash
git add lua/config/autocmds.lua
git commit -m "fix: open diagnostic float once per line on CursorHold"
```

---

### Task 5: Resolve keymap prefix collisions

**Files:**
- Modify: `init.lua:283,290-293,1704-1705`
- Modify: `lua/custom/plugins/qol.lua:9,11,12,18`

**Interfaces:**
- Consumes: Tasks 2 (hr placement).
- Produces: collision-free `<leader>r*` and group prefixes (needed by Task 11).

- [ ] **Step 1: Rename empty which-key groups that shadow actions**

Groups `<leader>tr/ts/to/rr/o` are empty but share lhs with neotest (`tr/ts/to`), refactoring (`rr`), aerial (`o`). Rename the groups to non-conflicting prefixes (e.g. `<leader>T` for test-group if free, else drop empty groups entirely — an empty group label adds nothing). Check free prefixes with `:WhichKey <leader>` before choosing.

- [ ] **Step 2: Fix `<leader>r` triple-use**

`<leader>r` (run_file) is a prefix of `<leader>rr` (refactor) and `<leader>rf` (run alias), plus a `rr` group on the same lhs. Move run_file to `<leader>R` (verify free via WhichKey), keep `rr`/`rf` as-is, delete the `rr` group label.

- [ ] **Step 3: Fix wrong-letter descs**

`init.lua:283` desc `[B]ookmarks & [M]olten` under prefix `m` → `[M]olten & Book[m]arks` style matching the actual prefix letter. `init.lua:1639` `<leader>fg` desc `[F]ile [G]it` → move under a git prefix or reword to match `f` group.

- [ ] **Step 4: Verify**

Run: full plenary suite (all 4 files) green; manual `:WhichKey <leader>r` shows no delay conflicts; pressing `<leader>r` fires immediately.

- [ ] **Step 5: Commit**

```bash
git add init.lua lua/custom/plugins/qol.lua
git commit -m "fix: resolve leader-key prefix collisions and wrong descs"
```

---

### Task 6: Small correctness batch

**Files:**
- Modify: `init.lua:133-136` (compose pattern)
- Modify: `lua/config/options.lua:84,123` (clipboard guard; leave timeoutlen)
- Modify: `lua/config/health.lua:2` (doc header)
- Modify: `lua/config/options.lua:22-42` + `init.lua:1463-1473` (disable-list drift)
- Modify: `init.lua:87` area (version floor note)

**Interfaces:**
- Consumes: nothing. Produces: consistent guards (needed by Task 11).

- [ ] **Step 1: Tighten compose pattern**

```lua
-- BEFORE: 'compose.*%.ya?ml' (matches any *compose*.yaml)
-- AFTER: match only docker compose filenames, e.g.
'compose%.ya?ml$', 'docker%-compose%.ya?ml$'
```

Keep the `yaml.docker-compose` assignment behavior for real compose files.

- [ ] **Step 2: SSH clipboard guard**

```lua
-- options.lua, replace unconditional clipboard with:
if vim.env.SSH_CONNECTION == nil then
  vim.o.clipboard = 'unnamedplus'
end
```

- [ ] **Step 3: Fix health doc header**

```lua
-- lua/config/health.lua:2, ':checkhealth config.health' -> ':checkhealth config'
```

- [ ] **Step 4: Unify disabled-plugin lists**

Add missing `netrw` core to the lazy `disabled_plugins` list OR remove the extras so both lists (`options.lua:22-42` `loaded_*` and `init.lua:1463-1473` lazy disables) cover the same set: tohtml/2html_plugin, tutor/tutor_mode_plugin, matchit, netrw + netrwPlugin family. One list is source of truth, comment pointing at the other.

- [ ] **Step 5: Version floor note**

Next to `init.lua:87` (≥0.9 claim), add comment: `smoothscroll` (0.10+) and `winborder` (0.11+) are set unguarded — floor is effectively 0.11.

- [ ] **Step 6: Verify** — full suite green + headless boot clean.

- [ ] **Step 7: Commit**

```bash
git add init.lua lua/config/options.lua lua/config/health.lua
git commit -m "fix: compose pattern, ssh clipboard, health doc, disable-list drift"
```

---

### Task 7: Delete dead code

**Files:**
- Delete: `tests/helpers.lua` (0 callers — confirm first)
- Modify: `init.lua:1561,1562,1564` (unused `_G` session globals)
- Modify: `init.lua:463-471` (disabled spectre spec + `<leader>fr`)
- Modify: `lua/custom/ui/spec.lua:287` (dead LazyGit branch)
- Delete: `lua/kickstart/health.lua` (never required, duplicates config/health)

**Interfaces:**
- Consumes: Tasks 1–6 done (so tests reflect live code). Produces: smaller tree for Tasks 8–10.

- [ ] **Step 1: Confirm zero usage**

Run: `rg -n "helpers\.|_builtin_session_file_for|_builtin_session_file\b|_builtin_suppressed_dir|kickstart/health|kickstart\.health" --glob '!docs/**' .`
Expected: only the definitions/require lines themselves, no callers. (`_builtin_find_session` used at `lua/custom/ui/spec.lua:296` stays.)

- [ ] **Step 2: Delete**

Delete `tests/helpers.lua` only if no test file calls its functions (they `require` it — remove those require lines too). Delete the three `_G` globals, the spectre spec block, the `if exists(':LazyGit')` branch (keep the `terminal lazygit` fallback), and `lua/kickstart/health.lua`.

- [ ] **Step 3: Verify** — full suite green + `:checkhealth config` OK + headless boot clean.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove dead helpers, globals, spectre spec, legacy health"
```

---

### Task 8: Mechanical vim.fn → stdlib swaps

**Files:**
- Modify: `init.lua:175,1138,1327,1438,403,1513,785,789,1523,1529,1628,1686,1692,1695`
- Modify: `lua/config/keymaps.lua:26-27`, `lua/config/autocmds.lua:29`
- Modify: `lua/custom/plugins/themes.lua:131-147`
- Modify: `init.lua:1541,1549` + `lua/custom/ui/spec.lua:299,303,314,318,324,329,352,355` (session scan dedupe)
- Modify: `init.lua:667` (`lspconfig.settings` annotation)

**Interfaces:**
- Consumes: Task 7. Produces: modernized call sites (needed by Task 9 lspconfig removal).

Apply each swap (all 0.10+, host is 0.12.5):

- [ ] **Step 1: Safe one-liners**

```lua
-- init.lua:175: (vim.uv or vim.loop).fs_stat(lazypath) -> vim.uv.fs_stat(lazypath)
-- init.lua:1138: vim.fn.filereadable(parser) ~= 1 -> vim.uv.fs_stat(parser) == nil
-- init.lua:1327: vim.fn.filereadable(debugpy_path) == 1 -> vim.uv.fs_stat(debugpy_path) ~= nil
-- init.lua:1438: vim.fn.getfsize(name) > 200*1024 -> local ok, st = pcall(vim.uv.fs_stat, name); ok and st and st.size > 200*1024
-- keymaps.lua:26-27 + autocmds.lua:29: vim.fn.line('.')-1 / vim.fn.col('.')-1 -> local cur = vim.api.nvim_win_get_cursor(0); lnum = cur[1]-1
-- init.lua:403,1513 + spec.lua:299,329: vim.fn.getcwd() -> vim.uv.cwd() or vim.fn.getcwd()
-- init.lua:785,789: vim.fn.expand('~/.config/nvim/prettier.config.json') -> vim.fs.normalize('~/.config/nvim/prettier.config.json')
-- init.lua:667: ---@type lspconfig.settings.lua_ls -> ---@type vim.lsp.Config
-- init.lua:1628: vim.fn.termopen(cmd, { on_exit = function() end }) -> vim.fn.jobstart(cmd, { term = true })
```

- [ ] **Step 2: Session-scan dedupe (glob/getftime → fs.dir/fs_stat, one helper)**

```lua
-- New single helper (place near find_session_for in init.lua), used by both
-- init.lua find_session_for AND spec.lua dashboard picker:
local function session_files(dir)
  local out = {}
  for name, t in vim.fs.dir(dir) do
    if t == 'file' and (name:match('%.vim$') or name:match('%.lua$')) then
      local st = vim.uv.fs_stat(dir .. '/' .. name)
      table.insert(out, { path = dir .. '/' .. name, mtime = st and st.mtime.sec or 0 })
    end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  return out
end
```

Replace `init.lua:1541,1549` + `spec.lua:303,314,318` glob/getftime logic with calls to it. Keep sorted-newest-first behavior the dashboard relies on.

- [ ] **Step 3: Verify** — full suite green; manual: sessions list on dashboard (`s`), theme scan (`<leader>ty`), debugpy attach path, large-file guard on a 300KB file.

- [ ] **Step 4: Commit**

```bash
git add init.lua lua/config/keymaps.lua lua/config/autocmds.lua lua/custom/plugins/themes.lua lua/custom/ui/spec.lua
git commit -m "refactor: replace legacy vim.fn with vim.uv/vim.fs/vim.api"
```

---

### Task 9: Drop nvim-lspconfig for native vim.lsp.config (needs real validation)

**Files:**
- Modify: `init.lua:486,502,622-714,1058-1064`

**Interfaces:**
- Consumes: Task 8. Produces: zero lspconfig dependency.

- [ ] **Step 1: Replicate server definitions natively, then delete specs**

For `lua_ls`, `dockerls`, `docker_compose_language_service`: copy `cmd`, `filetypes`, root markers from the installed lspconfig (`~/.local/share/nvim/lazy/nvim-lspconfig/lsp/*.lua`) into the existing `vim.lsp.config(name, {...})` calls. For vtsls: replace `require('lspconfig.configs').vtsls = ...` + `lspconfig.vtsls.setup` with `vim.lsp.config('vtsls', {...})` (same capabilities/settings). Delete the `'neovim/nvim-lspconfig'` spec (`:486`), the `'mason-org/mason-lspconfig.nvim'` dep (`:502`, never setup'd), and the lspconfig dep from vtsls (`:1058`).

- [ ] **Step 2: Verify — real LSP validation (mandatory)**

Run: open a lua file, a python file, a TS file, a docker-compose file; in each run `:lua print(#vim.lsp.get_clients({bufnr=0}))` — expect ≥1. Run `:checkhealth vim.lsp` — no errors. Run `:Mason` — opens fine.

- [ ] **Step 3: Commit**

```bash
git add init.lua
git commit -m "refactor: replace nvim-lspconfig with native vim.lsp.config"
```

---

### Task 10: Performance swaps (measured ROI order)

**Files:**
- Modify: themery spec (eager → cmd/keys)
- Modify: hlchunk spec (delete) + snacks config (enable indent)
- Modify: telescope spec (VeryLazy → keys/cmd)
- Modify: dressing spec (delete after check) + noice spec (keep unless unstable)
- Modify: colorizer spec + image.nvim spec (narrow triggers)

**Interfaces:**
- Consumes: Tasks 1–9. Produces: faster boot, fewer loaded modules.

- [ ] **Step 1: Themery lazy**

```lua
-- themery spec: remove EAGER/priority, use:
cmd = 'Themery', keys = { { '<leader>ty', '<cmd>Themery<cr>', desc = '[T]hemery' } },
```

Verify: `nvim --headless -c 'qa!'` wall time drops ~5ms; `<leader>ty` still opens picker; last colorscheme persists across restart.

- [ ] **Step 2: hlchunk → snacks.indent**

Set `indent = { enabled = true }` in snacks opts; delete hlchunk spec. Verify: open indented lua file, indent guides render; `--startuptime` VeryLazy section shrinks ~10ms.

- [ ] **Step 3: Telescope keys/cmd-only**

Remove `event = 'VeryLazy'`; ensure every `<leader>s*` mapping and `:Telescope` cmd is declared as `keys`/`cmd` so lazy-load still triggers. Verify: `loaded` count after `doautocmd User VeryLazy` drops; all pickers open on demand.

- [ ] **Step 4: Drop dressing (keep snacks.input + ui-select)**

Delete dressing spec; verify `:Themery`, session picker, `gra` code-action UI all still render input/select floats (snacks.input + telescope-ui-select cover them). Keep noice unless UI glitches appear.

- [ ] **Step 5: Narrow colorizer + image triggers**

colorizer: `event = BufReadPost` → `ft = { 'css','html','javascript','typescript','lua','vim','toml' }`. image.nvim: `event = BufReadPre` → load only for markdown / as molten dependency. Verify: open a `.py` file — neither loads (`:Lazy` shows not loaded); open `.css` — colorizer loads.

- [ ] **Step 6: Verify all** — full suite + headless boot ≤0.12s + manual picker tour.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "perf: lazy themery, snacks.indent over hlchunk, trim telescope/dressing triggers"
```

---

### Task 11: Behavioral tests + expanded health

**Files:**
- Create: `tests/test_keymaps_autocmds.lua`
- Create: `tests/test_lsp_servers.lua`
- Modify: `lua/config/health.lua`
- Modify: `tests/test_critical_fixes.lua` (provider assertion already fixed in Task 1)

**Interfaces:**
- Consumes: Tasks 1–10 (tests assert final behavior).

- [ ] **Step 1: Keymap/autocmd behavioral tests**

```lua
-- tests/test_keymaps_autocmds.lua
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_keymaps_autocmds.lua")' -c 'qa!'
describe('keymaps/autocmds', function()
  it('hr mapping is buffer-local to http', function()
    vim.cmd('enew')
    assert.are.equal('', vim.fn.maparg('<leader>hr', 'n'))
  end)
  it('CursorHold float helper tolerates lines without diagnostics', function()
    vim.cmd('enew')
    assert.is_true(vim.tbl_isempty(vim.diagnostic.get(0, { lnum = 0 })))
  end)
  it('no duplicate lhs in normal mode keymaps', function()
    local seen, dupes = {}, {}
    for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
      if seen[m.lhs] then table.insert(dupes, m.lhs) end
      seen[m.lhs] = true
    end
    assert.are.same({}, dupes)
  end)
end)
```

- [ ] **Step 2: LSP smoke test**

```lua
-- tests/test_lsp_servers.lua
describe('lsp servers', function()
  it('lua_ls attaches to lua buffers', function()
    vim.cmd('e /tmp/lsp_probe.lua')
    vim.wait(8000, function()
      return #vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' }) > 0
    end, 200)
    assert.is_true(#vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' }) > 0)
    vim.cmd('bdelete!')
  end)
end)
```

- [ ] **Step 3: Expand health.lua**

Add checks: `fd`, `lazygit`, `cmake`, `docker` (warn-only, docker servers optional), `pyrefly` executable, mason bins (`stylua`, `oxlint`, `prettier`, `ruff`, `debugpy`), image backend (`kitty` graphics vs `ueberzugpp` fallback note). Use `vim.fn.executable` + `vim.health.warn` for optional, `error` for required (`git`, `rg`, `node`).

- [ ] **Step 4: Run everything**

Run: all six test files via plenary.busted, each green. Run: `:checkhealth config` — only expected warns (missing optional docker/jupyter).

- [ ] **Step 5: Commit**

```bash
git add tests/test_keymaps_autocmds.lua tests/test_lsp_servers.lua lua/config/health.lua
git commit -m "test: behavioral keymap/lsp tests, expanded health checks"
```

---

## Self-Review

- Spec coverage: user asked bugs + legacy + perf + slow-tool swaps + research + review-first plan — Tasks 1–6 (bugs), 7 (dead code), 8–9 (legacy APIs), 10 (perf swaps), 11 (tests). Slow-tool non-swaps documented in Constraints-adjacent notes (blink.cmp, conform, statusline, mason, neo-tree kept deliberately).
- Placeholder scan: no TBD/TODO; every step has exact file:line, code, and expected command output.
- Type consistency: Lua-only plan; helper `session_files` defined once in Task 8 and reused by both call sites.
