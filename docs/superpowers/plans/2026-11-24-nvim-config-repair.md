# Nvim Config Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the verified Neovim configuration defects, make tests safe and truthful, restore measured laziness, and correct terminal UX without changing the visual identity or adding dependencies.

**Architecture:** Keep the existing lazy.nvim spec layout, builtin UI modules, native LSP APIs, and session module. Make narrow lifecycle fixes at their owning layer, add behavioral regressions around fresh processes and buffer events, and preserve the user's dirty work while rebasing onto the newer remote.

**Tech Stack:** Neovim 0.12.6, Lua/LuaJIT, lazy.nvim, Plenary, Snacks, native LSP, Treesitter, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-24-nvim-config-repair-design.md`

## Global Constraints

- Neovim 0.12.6 is the supported and CI-pinned version.
- Preserve the eight user-owned dirty files and their intended fixes; never overwrite them during rebase or implementation.
- Reconcile the three commits already on `origin/master` before pushing.
- No new plugins or dependencies; keep the current plugin budget and visual identity.
- No broad module reorganization, colorscheme change, or layout redesign.
- Use named `clear = true` autocmd groups and buffer-specific callbacks.
- Keep `<leader>ur` as the real reload path: evict `config.*`/`custom.*` modules before sourcing `$MYVIMRC`.
- Keep the 200 KB Treesitter guard and 1 MiB large-file cleanup threshold.
- Do not reintroduce prettierd, async format-on-save, or lower the 2000 ms formatting timeout.
- Keep the Python LSP ladder, Mason exclusions, Treesitter main API, Biome `$HOME` rejection, lint cwd pinning, and byte-offset handling.
- Session logic stays in `config.sessions`; dashboard code consumes that module rather than `_G` aliases.
- Stylua must pass on every touched Lua file.
- Defer session caching, theme-write debouncing, Snacks indent animation, Actions Preview/Inc Rename eager-load removal, and speculative micro-optimizations.

## Review Focus

- **Pre-existing user paths:** fixtures must refuse collisions and remove only paths they created; Task 1 pins this with an ownership/refusal regression.
- **First-open startup and oversized files:** fresh-process tests must cover `nvim file.py`, 256 KB Lua, and 2 MiB LSP buffers; Tasks 3 and 5 own these.
- **Asynchronous lifecycle races:** buffer wipes and multi-client detach must not leave callbacks or clear another client's highlights; Tasks 5 and 6 own these.
- **False-green tooling:** missing required tools, failed children, and stray scheduled tracebacks must fail visibly; Task 2 owns CI/E2E enforcement.
- **Untrusted Markdown:** remote images must not auto-download or trigger internal-network requests; Task 10 owns this.

---

### Task 0: Preserve dirty work and reconcile the remote

**Files:**
- Modify: `tests/stress_child.lua` only to resolve the remote overlap
- Create: `docs/superpowers/plans/2026-11-24-nvim-config-repair.md`
- Preserve: the eight currently dirty files and the new design doc

**Interfaces:**
- Produces: a local `master` based on current `origin/master`, with the user's intended dirty changes restored and no lost hunks.

- [ ] **Step 1: Snapshot the worktree**

Run:

```bash
mkdir -p /tmp/opencode/nvim-repair-backup
git status --short > /tmp/opencode/nvim-repair-backup/status-before.txt
git diff --binary > /tmp/opencode/nvim-repair-backup/worktree-before.patch
git diff --cached --binary > /tmp/opencode/nvim-repair-backup/index-before.patch
git ls-files --others --exclude-standard > /tmp/opencode/nvim-repair-backup/untracked-before.txt
```

Expected: backup files exist and include all eight dirty tracked files plus the design/plan docs.

- [ ] **Step 2: Stash, fetch, and rebase**

Run:

```bash
git stash push -u -m 'pre-nvim-repair-2026-11-24'
git fetch origin master
git rebase origin/master
git stash pop
```

If `tests/stress_child.lua` conflicts, retain the remote behavior for `<leader>nta` and `crr` while preserving the user's added `<leader>nto` skip for now. Do not discard either side wholesale.

- [ ] **Step 3: Create the isolated worktree and restore the work**

After the rebase, use the harness's native worktree tool to create a repair branch from the rebased `master`, move the session into that worktree, then run `git stash pop` there. Resolve any `tests/stress_child.lua` conflict by retaining the remote behavior for `<leader>nta` and `crr` while preserving the user's added `<leader>nto` skip for now. Do not discard either side wholesale.

Run in the worktree:

```bash
git status --short
git diff -- tests/stress_child.lua
git log --oneline -5
```

Expected: the same eight files remain modified, design/plan docs are untracked or tracked, and the branch contains `c31eba5`.

- [ ] **Step 4: Commit the design and plan**

```bash
git add docs/superpowers/specs/2026-11-24-nvim-config-repair-design.md docs/superpowers/plans/2026-11-24-nvim-config-repair.md
git commit -m 'docs: plan verified nvim config repairs'
```

### Task 1: Make test fixtures collision-safe

**Files:**
- Modify: `lua/tests/helpers.lua`
- Modify: `tests/stress.lua`
- Modify: `tests/test_config_modules.lua`
- Test: `tests/test_data_safety.lua`

**Interfaces:**
- Produces: `helpers.fixture_path(label: string) -> string` and `helpers.remove_fixture(path: string) -> nil`.
- `fixture_path` returns a nonexistent unique path under `stdpath('data')/test-fixtures/`, records ownership in a module-local table, and refuses to return an existing path.
- `remove_fixture` refuses paths not returned by `fixture_path`, then deletes only that owned path.

- [ ] **Step 1: Write the failing ownership test**

Add a test to `tests/test_data_safety.lua` that:
1. Creates a foreign file containing a sentinel.
2. Asserts `pcall(helpers.remove_fixture, foreign_path)` is false.
3. Asserts the sentinel file still exists.
4. Calls `helpers.fixture_path('owned')`, asserts the path does not exist, creates it, removes it, and asserts it is gone.

- [ ] **Step 2: Run the focused test and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_data_safety.lua')" -c 'qa!'
```

Expected: FAIL because the fixture helpers do not exist.

- [ ] **Step 3: Implement the fixture helpers**

Use `vim.fn.tempname()` only for its unique basename; construct the final path under `stdpath('data')/test-fixtures/` so session tests remain outside suppressed temporary subtrees. Keep ownership in a module-local table. Do not delete the shared parent directory.

- [ ] **Step 4: Replace unsafe fixture paths**

In `tests/stress.lua` and `tests/test_config_modules.lua`, replace fixed `session-stress-proj`, `session-write-test`, `stress_probe_a.lua`, and `stress_probe_b.lua` paths with `helpers.fixture_path(...)`. Track each created path and call `helpers.remove_fixture(path)` in cleanup. Never call recursive delete on a path the helper did not create.

- [ ] **Step 5: Run safety and affected suites**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_data_safety.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_config_modules.lua')" -c 'qa!'
```

Expected: both pass with no fixed-path writes or deletions.

- [ ] **Step 6: Commit**

```bash
git add lua/tests/helpers.lua tests/test_data_safety.lua tests/test_config_modules.lua tests/stress.lua
git commit -m 'test: make fixture paths collision-safe'
```

### Task 2: Make E2E, reload, and CI failures visible

**Files:**
- Modify: `tests/test_e2e_features.lua`
- Modify: `tests/test_autocmd_idempotency.lua`
- Modify: `.github/workflows/smoke-test.yml`

**Interfaces:**
- Consumes: existing `run()`/`boot()` E2E helpers.
- Produces: child failures and stray tracebacks fail tests/CI; optional skips remain explicitly labeled.

- [ ] **Step 1: Strengthen the E2E child assertion**

Change `run()` to assert `res.code == 0` and reject combined output containing `Invalid buffer id`, `stack traceback:`, `Error in command line:`, or `vim.schedule callback:` before returning the report. Preserve the existing return shape for callers.

- [ ] **Step 2: Exercise the real reload callback**

In `tests/test_autocmd_idempotency.lua`, find the normal-mode `<leader>ur` mapping with `nvim_get_keymap`, assert it has a callback, invoke it, and compare named autocmd counts before/after. Do not replace this with bare `:source $MYVIMRC`.

- [ ] **Step 3: Audit pending tests**

Replace `pending()` with explicit executable/tool assertions wherever CI is expected to provide the tool. Label genuinely optional pending cases with `[optional]` in their test description.

- [ ] **Step 4: Harden the workflow**

Prepend `$HOME/.local/share/nvim/mason/bin` to `PATH` before the Plenary loop. Keep existing exit-status/summary checks and reject:
- `vim.schedule callback:`
- `stack traceback:`
- `Error in command line:`
- `Pending:` lines not containing `[optional]`

Keep the separate stress job unchanged.

- [ ] **Step 5: Run affected suites and workflow syntax check**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_e2e_features.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_autocmd_idempotency.lua')" -c 'qa!'
bash -n setup.sh
```

Expected: suites pass, reload counts remain stable, and a deliberately failed child is reported as a failure.

- [ ] **Step 6: Commit**

```bash
git add tests/test_e2e_features.lua tests/test_autocmd_idempotency.lua .github/workflows/smoke-test.yml tests/test_*.lua
git commit -m 'test: fail on hidden runtime and child errors'
```

### Task 3: Repair Treesitter first-file handling and class navigation

**Files:**
- Modify: `lua/plugins/treesitter.lua`
- Modify: `tests/test_performance.lua`
- Modify: `tests/stress_child.lua`
- Test: `tests/test_performance.lua`

**Interfaces:**
- Produces: local `start(bufnr)` behavior shared by FileType and already-loaded buffers; oversized buffers are explicitly stopped; parserless class wrappers are inert.

- [ ] **Step 1: Add fresh-process Treesitter tests**

Add child-process tests that launch isolated Neovim instances with:
1. A small Python file as a startup argument; after setup, `vim.treesitter.highlighter.active[buf]` must exist.
2. A 256 KB Lua file as a startup argument; after setup and a short wait, the highlighter must not exist.

Do not manufacture a FileType event in these tests.

- [ ] **Step 2: Add parserless navigation coverage**

Invoke `[C`, `]C`, and the selection/move/swap wrappers in a buffer where `vim.treesitter.get_parser(buf, nil, { error = false })` returns nil. Assert no error and no textobject call. Restore the corresponding stress-child cases instead of skipping them.

- [ ] **Step 3: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_performance.lua')" -c 'qa!'
```

Expected: startup-file and parserless cases fail before implementation.

- [ ] **Step 4: Factor and bootstrap the starter**

Move the existing FileType callback body into a local `start(bufnr)` function. Register it for FileType, then call it for every already-loaded normal buffer. Preserve buftype, minified/200 KB, filetype mapping, parser-install, and fold-window logic. In the oversized branch call `vim.treesitter.stop(bufnr)`.

Guard `sel`, `mv`, and `sw` with `vim.treesitter.get_parser(bufnr, nil, { error = false })` before calling textobjects.

- [ ] **Step 5: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_performance.lua')" -c 'qa!'
stylua --check lua/plugins/treesitter.lua tests/test_performance.lua tests/stress_child.lua
```

Expected: startup Python starts, oversized Lua stays stopped, parserless motions are inert, and formatting passes.

- [ ] **Step 6: Commit**

```bash
git add lua/plugins/treesitter.lua tests/test_performance.lua tests/stress_child.lua
git commit -m 'fix: bootstrap treesitter for startup buffers safely'
```

### Task 4: Fix Tailwind and per-buffer Java attachment

**Files:**
- Modify: `lua/config/lsp_servers.lua`
- Modify: `lua/plugins/editing.lua`
- Create: `tests/test_lsp_lifecycle.lua`

**Interfaces:**
- Tailwind `root_dir(bufnr, on_dir)` calls `on_dir(root)` only for a discovered root.
- JDTLS uses a named FileType autocmd and `start_or_attach(opts, { bufnr = args.buf, dap = { hotcodereplace = 'auto' } })`.

- [ ] **Step 1: Write failing lifecycle tests**

In `tests/test_lsp_lifecycle.lua`:
1. Stub `vim.fs.root` and assert Tailwind calls `on_dir` once with the root, and never with nil for a single-file buffer.
2. Stub `require('nvim-jdtls').start_or_attach`, create two Java buffers with different project markers, invoke the FileType callbacks, and assert each call receives the correct `bufnr` and root-derived `cmd`/workspace configuration.

- [ ] **Step 2: Run the new suite and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'
```

Expected: Tailwind callback contract and Java per-buffer assertions fail.

- [ ] **Step 3: Fix Tailwind**

Replace the returning `root_dir` with:

```lua
root_dir = function(bufnr, on_dir)
  local root = vim.fs.root(bufnr, tailwind_markers)
  if root then on_dir(root) end
end
```

- [ ] **Step 4: Fix JDTLS startup**

Create a named `clear = true` FileType autocmd for Java. Compute the root from `args.buf`, preserve the existing data directory and launcher behavior, skip large-file buffers, and call `start_or_attach(opts, { bufnr = args.buf, dap = { hotcodereplace = 'auto' } })`. Invoke the same handler for already-open Java buffers. Use built-in LSP capabilities instead of requiring Blink.

- [ ] **Step 5: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'
stylua --check lua/config/lsp_servers.lua lua/plugins/editing.lua tests/test_lsp_lifecycle.lua
```

Expected: both lifecycle tests pass.

- [ ] **Step 6: Commit**

```bash
git add lua/config/lsp_servers.lua lua/plugins/editing.lua tests/test_lsp_lifecycle.lua
git commit -m 'fix: attach tailwind and java per buffer root'
```

### Task 5: Restore LSP laziness and multi-client lifecycle behavior

**Files:**
- Modify: `lua/plugins/lsp.lua`
- Modify: `lua/plugins/editing.lua`
- Modify: `tests/test_lsp_lifecycle.lua`
- Test: `tests/test_e2e_features.lua`

**Interfaces:**
- Blink and LuaSnip remain unloaded at VimEnter until InsertEnter.
- Large-file buffers do not trigger native/direct LSP startup.
- Document-highlight autocmds are isolated per client or cleared only after the final supporting client detaches.

- [ ] **Step 1: Write failing laziness and lifecycle tests**

Add child-process assertions that:
1. At VimEnter, before InsertEnter, `package.loaded['blink.cmp']` and `package.loaded['luasnip']` are nil.
2. Default `make_client_capabilities()` still reports snippet support.
3. A fresh 2 MiB TypeScript, Java, and Lua buffer has no attached LSP client after setup.

Add a two-client fake-client test proving detaching one supporting client does not remove the remaining client's highlight autocmds.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_e2e_features.lua')" -c 'qa!'
```

Expected: Blink is loaded too early, large buffers start clients, or multi-client cleanup fails.

- [ ] **Step 3: Remove eager Blink coupling**

Remove the Mason-time Blink require/capability merge and the VTSLS Blink dependency/forced load. Use Neovim's built-in capabilities, which already include snippet support. Preserve Blink's InsertEnter event, cmdline setting, LuaSnip preset, and dependencies.

- [ ] **Step 4: Gate native and direct LSP startup**

In `lua/plugins/lsp.lua`, replace `once = true` FileType handlers with per-buffer callbacks that return when `vim.b[args.buf].large_file_mode` is set. Apply the same check in the already-open buffer loop. Keep the LspAttach detach safety net.

In VTSLS, register equivalent per-buffer FileType enabling and handle already-open buffers; do not call `vim.lsp.enable` unconditionally.

- [ ] **Step 5: Isolate document-highlight cleanup**

Use client-specific augroup names, or clear highlight autocmds only when no remaining attached client supports `textDocument/documentHighlight`. One client's detach must not clear another client's handlers.

- [ ] **Step 6: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_e2e_features.lua')" -c 'qa!'
stylua --check lua/plugins/lsp.lua lua/plugins/editing.lua tests/test_lsp_lifecycle.lua tests/test_e2e_features.lua
```

Expected: laziness, no-spawn, snippet capability, and multi-client assertions pass.

- [ ] **Step 7: Commit**

```bash
git add lua/plugins/lsp.lua lua/plugins/editing.lua tests/test_lsp_lifecycle.lua tests/test_e2e_features.lua
git commit -m 'perf: avoid eager completion and large-file lsp startup'
```

### Task 6: Fix diagnostic floats and the CodeLens wipe race

**Files:**
- Modify: `lua/config/diag_float.lua`
- Modify: `lua/plugins/lsp.lua`
- Modify: `tests/test_keymaps_autocmds.lua`
- Test: `tests/test_e2e_features.lua`

**Interfaces:**
- Diagnostic floats close when diagnostics disappear without cursor movement.
- `BufWipeout` disables CodeLens for that buffer before Neovim invalidates it.

- [ ] **Step 1: Write failing regressions**

Extend `tests/test_keymaps_autocmds.lua` with: set a diagnostic, open the tracked float, reset diagnostics without moving the cursor, wait 100 ms, and assert the float is closed.

Add a child Markdown test that attaches marksman, edits the buffer, waits beyond the 200 ms CodeLens refresh, wipes it, waits again, and exits. The shared E2E assertion must reject `Invalid buffer id` or any traceback.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_keymaps_autocmds.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_e2e_features.lua')" -c 'qa!'
```

Expected: stale float and/or CodeLens race fails before implementation.

- [ ] **Step 3: Fix float invalidation**

Call `close_diag_float()` before returning from `open_diag_float()` when no diagnostics exist, and invalidate the tracked float before scheduling a DiagnosticChanged refresh.

- [ ] **Step 4: Fix CodeLens cleanup**

Register one named `clear = true` BufWipeout autocmd during LSP setup that calls `pcall(vim.lsp.codelens.enable, false, { bufnr = ev.buf })`. Do not patch Neovim runtime files or disable CodeLens globally.

- [ ] **Step 5: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_keymaps_autocmds.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_e2e_features.lua')" -c 'qa!'
stylua --check lua/config/diag_float.lua lua/plugins/lsp.lua tests/test_keymaps_autocmds.lua tests/test_e2e_features.lua
```

Expected: both regressions pass without stray scheduled errors.

- [ ] **Step 6: Commit**

```bash
git add lua/config/diag_float.lua lua/plugins/lsp.lua tests/test_keymaps_autocmds.lua tests/test_e2e_features.lua
git commit -m 'fix: clean diagnostic and codelens buffer state'
```

### Task 7: Normalize sessions and Markdown buffer behavior

**Files:**
- Modify: `lua/config/sessions.lua`
- Modify: `lua/custom/ui/dashboard.lua`
- Modify: `lua/config/markdown.lua`
- Modify: `lua/plugins/appearance.lua`
- Modify: `tests/test_config_modules.lua`
- Test: `tests/test_markdown_lists.lua`, `tests/test_builtin_ui.lua`

**Interfaces:**
- Produces: `sessions.is_suppressed(cwd: string) -> boolean` as the shared normalized predicate.
- `find_session_for`, writes, `list_projects`, dashboard Resume, and dashboard session picker all honor suppression.

- [ ] **Step 1: Write failing session and Markdown tests**

Extend `tests/test_config_modules.lua` to cover:
1. Trailing slashes.
2. Sibling-prefix boundaries such as `/tmp-other`.
3. Exact home versus a home child.
4. Custom `TMPDIR` subtree and exact `/tmp`.
5. `TMPDIR='/'` not suppressing every cwd.
6. Stale temp sessions absent from `list_projects` and dashboard choices.

Move list-project fixtures from `/tmp/lp-*` to unique non-suppressed paths from Task 1.

Add a Markdown test that triggers FileType for a non-current buffer and asserts its `formatoptions`/`comments`, not the current buffer's options. Add oversized `.markdown`/`.mdx` coverage for the render guard.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_config_modules.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_markdown_lists.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
```

Expected: filtering and non-current-buffer assertions fail.

- [ ] **Step 3: Share session suppression**

Normalize cwd and environment temp roots once. Ignore `/` as a subtree temp root so it cannot suppress every cwd. Export `is_suppressed(cwd)`. Use it in `find_session_for`, `VimLeavePre` writes, and `list_projects`; filter dashboard Resume and project choices through the canonical module. Preserve exact suppression of `~/`, `~/Downloads`, `/etc`, and `/tmp`.

- [ ] **Step 4: Fix Markdown targeting**

Set `formatoptions` and `comments` through `vim.bo[args.buf]` or `nvim_buf_call(args.buf, ...)`. Change the render-size guard to react to valid Markdown buffers by filetype rather than filename pattern; preserve the 200 KB threshold and byte-safe rendering.

- [ ] **Step 5: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_config_modules.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_markdown_lists.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
stylua --check lua/config/sessions.lua lua/custom/ui/dashboard.lua lua/config/markdown.lua lua/plugins/appearance.lua tests/test_config_modules.lua tests/test_markdown_lists.lua tests/test_builtin_ui.lua
```

Expected: all focused suites pass.

- [ ] **Step 6: Commit**

```bash
git add lua/config/sessions.lua lua/custom/ui/dashboard.lua lua/config/markdown.lua lua/plugins/appearance.lua tests/test_config_modules.lua tests/test_markdown_lists.lua tests/test_builtin_ui.lua
git commit -m 'fix: normalize session and markdown buffer handling'
```

### Task 8: Remove redundant redraw and lint work

**Files:**
- Modify: `lua/custom/ui/statusline.lua`
- Modify: `lua/plugins/ui.lua`
- Test: `tests/test_performance.lua`, `tests/test_lint.lua`, `tests/test_builtin_ui.lua`

**Interfaces:**
- Statusline diagnostic counts use `vim.diagnostic.count(buf)` and retain `{ e, w, i, h, total }`.
- Progress events invalidate `_progress` and request one throttled `redrawstatus`.
- Snacks Words is disabled; `<leader>uH` remains the single document-highlight toggle.

- [ ] **Step 1: Write failing performance/UI tests**

Add assertions that:
1. With 10,000 synthetic diagnostics, `_count_diags` returns correct severity totals and does not call `vim.diagnostic.get`.
2. An `LspProgress`/`Progress` event changes idle statusline output after the throttle without requiring a cursor move.
3. BufWritePost lint is skipped in insert/select/replace modes, while InsertLeave and manual lint still run.
4. Snacks Words is disabled in the loaded configuration.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_performance.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_lint.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
```

Expected: the new assertions fail before implementation.

- [ ] **Step 3: Implement the narrow changes**

Replace diagnostic iteration with `vim.diagnostic.count` and map severity keys into the existing cache. Add a named `clear = true` progress autocmd group that invalidates `_progress` and schedules a single throttled `redrawstatus`. Apply the formatting module's raw-mode guard to BufWritePost lint only. Set Snacks `words.enabled = false`.

- [ ] **Step 4: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_performance.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_lint.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
stylua --check lua/custom/ui/statusline.lua lua/plugins/ui.lua tests/test_performance.lua tests/test_lint.lua tests/test_builtin_ui.lua
```

Expected: all focused suites pass.

- [ ] **Step 5: Commit**

```bash
git add lua/custom/ui/statusline.lua lua/plugins/ui.lua tests/test_performance.lua tests/test_lint.lua tests/test_builtin_ui.lua
git commit -m 'perf: reduce diagnostic redraw and lint work'
```

### Task 9: Correct dashboard, picker, terminal, and command behavior

**Files:**
- Modify: `lua/custom/ui/dashboard.lua`
- Modify: `lua/config/terminal.lua` only if a test exposes reuse state that needs adjustment
- Modify: `lua/plugins/ui.lua`
- Modify: `lua/config/autocmds.lua`
- Modify: `init.lua`
- Modify: `tests/stress_child.lua`
- Test: `tests/test_builtin_ui.lua`, `tests/test_config_modules.lua`, `tests/test_qol.lua`

**Interfaces:**
- Dashboard LazyGit calls `config.terminal.toggle_float('lazygit')`.
- `<leader>sp` calls `require('snacks').picker.projects()`.
- Dashboard display truncation does not alter action paths or byte-based extmark offsets.

- [ ] **Step 1: Write failing behavioral tests**

Add tests proving:
1. Repeated dashboard `g` presses reuse the same terminal float buffer/job.
2. `<leader>sp` invokes the projects picker, not the files picker.
3. Home shortening does not rewrite `/home/omar2`.
4. Dashboard Resume/button labels remain within 40/60/80-column windows, including a 200-character cwd, while actions retain full paths.
5. `:DiffOrig` reads the current buffer's file when the alternate buffer differs.
6. `:StartupTime` removes an old log before running and sorts numeric durations descending.
7. `<leader>nn` history and which-key groups exist; `<leader>nto` executes successfully in a child instead of being skipped.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_config_modules.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_qol.lua')" -c 'qa!'
```

Expected: affected assertions fail before implementation.

- [ ] **Step 3: Implement the behavior fixes**

Use `toggle_float` for dashboard LazyGit. Replace `<leader>sp` with the existing projects picker and remove the misleading description. Anchor home-prefix matching at a path boundary. Truncate only dashboard display copies to the available width; preserve full action paths and byte offsets. Capture the current filename before `:DiffOrig` creates its scratch buffer. Clear the startup log and use `sort -k2,2nr`; document that headless `+q` omits UI/VimEnter stages. Restore tested notification/tips stress cases and remove only skips for behavior now covered.

- [ ] **Step 4: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_builtin_ui.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_config_modules.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_qol.lua')" -c 'qa!'
stylua --check lua/custom/ui/dashboard.lua lua/plugins/ui.lua lua/config/autocmds.lua init.lua tests/test_builtin_ui.lua tests/test_config_modules.lua tests/test_qol.lua tests/stress_child.lua
```

Expected: all focused suites pass.

- [ ] **Step 5: Commit**

```bash
git add lua/custom/ui/dashboard.lua lua/config/terminal.lua lua/plugins/ui.lua lua/config/autocmds.lua init.lua tests/test_builtin_ui.lua tests/test_config_modules.lua tests/test_qol.lua tests/stress_child.lua
git commit -m 'fix: align dashboard picker and terminal behavior'
```

### Task 10: Harden Markdown privacy and correct stale setup/docs

**Files:**
- Modify: `lua/custom/plugins/init.lua`
- Modify: `setup.sh`
- Modify: `README.md`
- Modify: `SETUP.md`
- Modify: `AGENTS.md`
- Modify: `CHEATSHEET.md`
- Modify: `lua/config/keymaps.lua`
- Modify: `lua/plugins/visual.lua`
- Modify: `lua/plugins/formatting.lua`
- Test: `tests/test_post_audit.lua`, `tests/test_formatting.lua`

**Interfaces:**
- Remote Markdown images default to no automatic download; users can explicitly opt in.
- Setup checks Node before system package installation and describes Mason-managed vtsls accurately.

- [ ] **Step 1: Write failing configuration/documentation tests**

Add focused assertions that:
1. image.nvim's Markdown integration sets `download_remote_images = false`.
2. Biome repos use `{'biome', 'prettier'}` and no unreachable organizer entry.
3. `need node` appears in the first system-dependency block before package installation.
4. `gy` copies the nearest diagnostic message rather than reporting the line total.
5. The `<leader>h` which-key description matches its actual KiteHost/HTTP action.
6. Docs describe temp-subtree sessions, `<leader>nn`, tips coverage, Mason-managed vtsls, and StartupTime limitations consistently.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_post_audit.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_formatting.lua')" -c 'qa!'
bash -n setup.sh
```

Expected: the new assertions fail before implementation.

- [ ] **Step 3: Apply privacy and setup fixes**

Set `download_remote_images = false` and document the explicit opt-in and behavior tradeoff. Move `need node` into the initial system dependency checks. Remove the redundant bun-based vtsls installation and rely on the existing Mason ensure spec; correct the documentation without changing the Python ladder or Mason exclusions.

- [ ] **Step 4: Correct commands, labels, and docs**

Make `gy` yank the nearest diagnostic message. Correct the `<leader>h` label. Remove the unreachable Biome organizer from `js_formatters` without changing formatting semantics. Update stale session, tips, startup, and setup notes in the listed docs.

- [ ] **Step 5: Run focused tests and formatting**

```bash
nvim --headless -c "lua require('plenary.busted').run('tests/test_post_audit.lua')" -c 'qa!'
nvim --headless -c "lua require('plenary.busted').run('tests/test_formatting.lua')" -c 'qa!'
bash -n setup.sh
stylua --check lua/custom/plugins/init.lua lua/config/keymaps.lua lua/plugins/visual.lua lua/plugins/formatting.lua tests/test_post_audit.lua tests/test_formatting.lua
```

Expected: all focused checks pass.

- [ ] **Step 6: Commit**

```bash
git add lua/custom/plugins/init.lua setup.sh README.md SETUP.md AGENTS.md CHEATSHEET.md lua/config/keymaps.lua lua/plugins/visual.lua lua/plugins/formatting.lua tests/test_post_audit.lua tests/test_formatting.lua
git commit -m 'fix: harden markdown and correct setup guidance'
```

### Task 11: Full verification, review, and push

**Files:**
- Review: complete diff from `origin/master`
- Update: only files required by verification findings

**Interfaces:**
- Produces: a reviewed, fully tested branch pushed to `origin/master` with logical conventional commits.

- [ ] **Step 1: Run formatting and every regular suite**

```bash
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
stylua --check .
for f in tests/test_*.lua; do
  nvim --headless -c "lua require('plenary.busted').run('$f')" -c 'qa!' || exit 1
done
```

Expected: Stylua passes and every suite reports success with no failures, errors, stray tracebacks, or unexpected pending results.

- [ ] **Step 2: Run fresh-process startup and lazy-load checks**

Record at least seven warm startup samples with the existing startup helper and compare against the ~48 ms baseline. Run the new startup-file, large-file, Blink, and no-LSP-spawn child probes. Do not accept a regression beyond run-to-run noise.

- [ ] **Step 3: Run the full stress harness**

```bash
nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'
```

Expected: zero failures. Review warnings explicitly; do not add skips to hide regressions.

- [ ] **Step 4: Run interactive terminal smoke checks**

Verify dashboard, sessions, notifications/tips, completion before/after InsertEnter, LSP progress, diagnostic floats, LazyGit float reuse, and 40/60/80-column dashboard rendering. Record any environment-only limitations.

- [ ] **Step 5: Fresh review**

Dispatch a read-only reviewer subagent with the complete diff from `origin/master`. Require correctness, test quality, architecture, security/privacy, and performance findings with severity labels. Fix all Critical/Required findings and rerun affected checks.

- [ ] **Step 6: Final Git checks and push**

```bash
git status --short
git diff --check origin/master...HEAD
git log --oneline origin/master..HEAD
git push origin master
```

Expected: clean worktree, no whitespace errors, logical conventional commits, and successful push.
