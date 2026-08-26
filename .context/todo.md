# Plan: Defer Telescope + Extensions for Startup Performance

## Context

Current config loads telescope.nvim at `event = 'VeryLazy'` (init.lua:291) which pulls in ~130–150ms of self-time during startup:
- telescope extensions (fzf, ui-select, projects, file_browser) all loaded eagerly inside telescope's `config()` function (lines 371–374)
- `project.nvim` (line 1247) and `telescope-vim-bookmarks` (line 1380) also use `VeryLazy` / eager `config` that loads their telescope extensions
- Keys already defined for all telescope features (<leader>sp, <leader>fe, <leader>fE, <leader>mb, <leader><leader>, etc.)

Moving telescope trigger from `VeryLazy` → `cmd = { 'Telescope' } + keys = { ... }` defers everything until first actual use. Only `fzf` + `ui-select` are needed for core pickers; `projects` + `file_browser` + `vim_bookmarks` can load lazily on their specific keymaps.

Target: reduce cold startup from ~85ms (this machine) / ~350ms (reported) by ~120–150ms.

---

## Phase 1: Create Branch & Baseline Measurements

**Why:** Establish a clean git branch and record reproducible before/after metrics.

**Test first** → none (measurement only)

**New file** → none

**Modify** → none

**Commands:**
```bash
git checkout -b perf/telescope-defer-extensions
# Record baseline 5x --startuptime runs, save to /tmp/baseline.log
for i in 1 2 3 4 5; do nvim --headless --startuptime /tmp/baseline_$i.log -c 'q'; done
awk '/NVIM STARTED/{print $1}' /tmp/baseline_*.log
grep -h telescope._extensions /tmp/baseline_*.log | sort -rn -k4 | head -20
```

---

## Phase 2: Refactor telescope.nvim Spec (init.lua lines 288–440)

**Why:** Move trigger from VeryLazy to cmd+keys; keep only fzf/ui-select eager; defer projects/file_browser to their keymaps.

**Test first** → none (manual verification: `<leader>sf`, `<leader><leader>`, `<leader>sp`, `<leader>fe` all work)

**Modify** → `init.lua` (telescope.nvim spec block)
- Change `event = 'VeryLazy'` → `cmd = { 'Telescope' }, keys = { ... }`
- Add all telescope keymaps to `keys` table (so lazy.nvim knows to load on those keys)
- In `config()`: keep only `load_extension('fzf')` + `load_extension('ui-select')`
- Remove eager `load_extension('projects')` and `load_extension('file_browser')`
- Wrap projects/file_browser extension loading in the keymap callbacks (or use separate `keys` entries on their plugin specs)

**Key mappings to include in `keys`:**
| Key | Action | Desc |
|-----|--------|------|
| `<leader>sh` | builtin.help_tags | Search Help |
| `<leader>sk` | builtin.keymaps | Search Keymaps |
| `<leader>sf` | builtin.find_files | Search Files |
| `<leader><leader>` | builtin.find_files | Search Files (alias) |
| `<leader>sp` | extensions.projects.projects | Search Projects |
| `<leader>ss` | builtin.builtin | Search Select Telescope |
| `<leader>sw` | builtin.grep_string | Search Word |
| `<leader>sg` | builtin.live_grep | Search Grep |
| `<leader>sd` | builtin.diagnostics | Search Diagnostics |
| `<leader>sr` | builtin.resume | Search Resume |
| `<leader>s.` | builtin.oldfiles | Search Recent Files |
| `<leader>sc` | builtin.commands | Search Commands |
| `<leader>/` | current_buffer_fuzzy_find | Search Buffer |
| `<leader>s/` | live_grep open files | Search Open Files |
| `<leader>sn` | find_files config dir | Search Neovim Files |
| `<leader>fe` | Telescope file_browser | File Explorer |
| `<leader>fE` | Telescope file_browser cwd | File Explorer (cwd) |
| `<leader>ls` | lsp_document_symbols | List Symbols (file) |
| `<leader>lS` | lsp_workspace_symbols | List Symbols (workspace) |

---

## Phase 3: Refactor project.nvim Spec (init.lua lines 1245–1257)

**Why:** project.nvim only used by `<leader>sp`; its VeryLazy load + telescope extension load is ~27ms self-time.

**Modify** → `init.lua` (project.nvim spec)
- Change `event = 'VeryLazy'` → `keys = { { '<leader>sp', ... } }` (trigger telescope projects on key)
- In keymap callback: lazy-load project_nvim setup + telescope.load_extension('projects')

---

## Phase 4: Refactor telescope-vim-bookmarks Spec (init.lua lines 1371–1381)

**Why:** Already has `keys` but also eager `config` that loads vim_bookmarks extension (~loads on startup). The `keys` already include `<leader>mb` for Telescope.

**Modify** → `init.lua` (telescope-vim-bookmarks spec)
- Remove `config = function() require('telescope').load_extension 'vim_bookmarks' end`
- Move `load_extension('vim_bookmarks')` into the `<leader>mb` keymap callback (or add a `keys` entry that does it)
- Ensure `<leader>mt`, `<leader>mc`, `<leader>mj`, `<leader>mk` still work (vim-bookmarks plugin itself loads via its own keys/dependencies)

---

## Phase 5: Ensure telescope-file-browser.nvim is Loaded on Keys

**Why:** telescope-file-browser is declared in `lua/custom/plugins/init.lua` (line 10) without explicit trigger — it loads as dependency of telescope but currently eager due to telescope's config calling load_extension. After Phase 2, we need it to load on `<leader>fe` / `<leader>fE`.

**Modify** → `lua/custom/plugins/init.lua`
- Add `keys = { { '<leader>fe', '<cmd>Telescope file_browser<CR>' }, { '<leader>fE', '<cmd>Telescope file_browser path=%:p:h<CR>' } }`
- Remove the eager load_extension('file_browser') from telescope config (already done in Phase 2)
- The extension will auto-load when `:Telescope file_browser` is invoked (lazy.nvim handles cmd trigger)

---

## Phase 6: Documentation Updates

**Why:** Keep docs in sync with new lazy-loading strategy.

**Modify** → `README.md`
- Update "LOADING" comment for telescope block (line ~290)
- Update CHEATSHEET.md load-strategy table if present

**Modify** → `PERFORMANCE_PLAN.md`
- Mark telescope defer task as DONE
- Add measured before/after numbers

**Modify** → `init.lua` (inline)
- Add header comment in telescope block explaining cmd+keys strategy
- Add comments on project.nvim and vim_bookmarks blocks

---

## Phase 7: Post-Change Benchmark & Push

**Why:** Verify improvement and push branch for comparison.

**Commands:**
```bash
# Record 5x after runs
for i in 1 2 3 4 5; do nvim --headless --startuptime /tmp/after_$i.log -c 'q'; done

# Summary
echo "=== BASELINE ==="; awk '/NVIM STARTED/{print $1}' /tmp/baseline_*.log | sort -n | awk '{sum+=$1} END {print "avg:", sum/NR "ms"}'
echo "=== AFTER ==="; awk '/NVIM STARTED/{print $1}' /tmp/after_*.log | sort -n | awk '{sum+=$1} END {print "avg:", sum/NR "ms"}'

# Telescope extension self-times
grep -h telescope._extensions /tmp/after_*.log | sort -rn -k4 | head -10

git add -A
git commit -m "perf: defer telescope + extensions to first use (cmd+keys)

- telescope.nvim: VeryLazy -> cmd=Telescope + keys for all mappings
- project.nvim: VeryLazy -> keys=<leader>sp (lazy-load extension in callback)
- telescope-vim-bookmarks: removed eager config, load vim_bookmarks on <leader>mb
- telescope-file-browser: added keys for <leader>fe/<leader>fE
- Expected startup reduction: ~120-150ms

Docs: updated README, CHEATSHEET.md, PERFORMANCE_PLAN.md, inline comments"

git push -u origin perf/telescope-defer-extensions
```

---

## Critical Files

| File | Action |
|------|--------|
| `init.lua` | Modify (telescope spec, project.nvim spec, vim_bookmarks spec) |
| `lua/custom/plugins/init.lua` | Modify (add keys to telescope-file-browser) |
| `README.md` | Modify (update load strategy notes) |
| `CHEATSHEET.md` | Modify (update load-strategy table) |
| `PERFORMANCE_PLAN.md` | Modify (mark done, add metrics) |

## Reusable Components (no changes needed)

- `lazy.nvim` plugin spec system (cmd/keys/event handling)
- `telescope.nvim` builtin pickers and extension API
- Existing keymap definitions (just moving from config() to keys table)

## Verification

1. **Startup time:** `nvim --headless --startuptime /tmp/test.log -c 'q'` → avg should drop by ≥100ms
2. **Keymap functionality:** `<leader>sf`, `<leader><leader>`, `<leader>sp`, `<leader>fe`, `<leader>fE`, `<leader>mb`, `<leader>mt` all open correct pickers
3. **No regressions:** `:Telescope` command works, `:Telescope file_browser` works, `:Telescope projects` works, `:Telescope vim_bookmarks` works
4. **Extension self-times:** `grep telescope._extensions /tmp/test.log` should show 0 (not loaded at startup)
5. **Git diff:** `git diff master..perf/telescope-defer-extensions --stat` shows only intended files changed