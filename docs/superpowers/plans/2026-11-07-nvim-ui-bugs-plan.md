# Neovim UI bugs: debug findings + fix plan (2026-11-07)

Config: `~/.config/nvim` (nvim 0.12.6, 57 plugins, kickstart-derived modular). UI stack: custom `lua/custom/ui/{statusline,tabline,dashboard}`, `snacks.nvim` (picker/explorer/notifier/input/indent/scope/words/scratch), `blink.cmp`, `which-key`, `gitsigns`, `flash`, `conform`, `nvim-lint`, `aerial`, treesitter. **No** noice/dressing/lualine/bufferline. `vim._core.ui2` is **disabled** (see below).

## Manual/automated test matrix executed

| Area | Method | Cases | Result |
|---|---|---|---|
| Startup/errors | headless load, `:messages`/stderr | full config, TS/py/lua buffers | no ui2/cmdline_show errors; no `v:errmsg` in probes |
| TS (multi-file) | `/tmp/opencode/e2e2` + `/tmp/opencode/nvim-ui-test` (`tsconfig`, `t.ts/js/tsx/jsx`, `mixed.ts`) | vtsls attach count, treesitter, diagnostics | 1 `vtsls` client, TS parsers OK, diagnostics present (type errors detected) |
| Python/Lua | headless ft + modules | `a.py`, `b.lua` | filetypes/modules OK |
| Diagnostic popup (Option A) | headless CursorMoved + tmux | diag line → float opens; clean line → closes; diag→clean→diag; hover coexistence | **fixed**: opens after 60ms debounce, closes on move, tracks own win id |
| Cmdline `/` and `:` | tmux | `/con` search completion, `:e t` completion, `:messages` | auto-select works (`wildmode=full,full`); no ui2 invalid-window errors |
| Completion (insert) | E2E headless + tmux | blink loads, sources, preselect+Tab, trigger `con` | blink config healthy; menu appeared in prior E2E (`float_wins=1`) |
| Statusline/tabline | headless eval | render, options set | custom UI renders |
| Plugins/modules | headless `require` | blink,snacks,which-key,gitsigns,flash,aerial,conform,lint,custom.ui | all load |
| Large file guard | headless 1.2M file | `large_file_mode`, LSP skipped | OK (from earlier E2E) |
| LSP hover + move | headless | hover float then CursorMoved | hover closed; our diag logic no longer kills all relative floats (correct) |

**Not fully automatable / needs real interactive pass:** snacks picker/explorer visual layout, which-key popup timing/overlap in complex key sequences, code-action/snacks.select UI, multi-dependency TS project with real `node_modules` (import resolution UI/progress bursts), terminal UI, split/window resize edge cases, theme picker live preview.

## Confirmed bugs (fixed)

### 1) `cmdline_show` / ui2 "Invalid window id" on `/` and `:` (FIXED)
- **Symptom:** `Error in "cmdline_show" UI event handler (ns=nvim.ui2): Lua: .../vim/_core/ui2/cmdline.lua:139: Invalid window id: 1019` (`nvim_win_set_cursor` in `cmdline_pos`), plus `vim.ui_attach() callback (ns=nvim.ui2)`. Reproduced in tmux when typing `/greet` and `:e`.
- **Cause:** `vim._core.ui2.enable()` (experimental 0.12) conflicted with cmdline stack (snacks.input, `CmdlineChanged` wildtrigger, wildmenu pum).
- **Fix:** disabled ui2 in `lua/config/options.lua`. Re-enable only when upstream stable with this config.

### 2) Cmdline completion not auto-selecting in `/` and `:` (FIXED)
- **Request:** "make the auto completion auto select in the search as well and : if they are not".
- **Cause:** `wildmode = 'noselect:full,full'`.
- **Fix:** `wildmode = 'full,full'` (`lua/config/options.lua`); comments updated in `options.lua` and `lua/config/autocmds.lua`. First match auto-selected; arrows/`<C-n>`/`<C-p>` move, `<C-e>` aborts.

### 3) Mason tool-installer startup error: `Cannot find package "vts"` (FIXED)
- **Symptom:** `mason-registry` "Cannot find package \"vts\"" from mason-tool-installer (hit-enter noise in tmux).
- **Cause:** `lua/plugins/lsp.lua` ensured `'vts'`; registry package is `vtsls`.
- **Fix:** ensure `vtsls` in `lua/plugins/lsp.lua`.

### 4) Diagnostic popup did not disappear when moving off a diagnostic line (FIXED)
- **Symptom:** "diagnosis popups dosent disapear when i move from them and focus on other lines".
- **Cause:** previous implementation scheduled opens and closed **all** relative floats; win tracking/capture was fragile and movement churn could leave/race floats.
- **Fix:** `lua/config/autocmds.lua` now tracks the diagnostic float **window id** (`vim.diagnostic.open_float` returns `bufnr, winid`), closes only that tracked float on `CursorMoved`, debounces open by **60ms** (reduces scroll churn), and keeps `close_events`. Verified: diag→open, clean→closed, diag→open.

## Observed (not config regressions / low risk)
- **Mason install notifications overlap cmdline area in tmux captures** while packages install — snacks notifier behavior; cosmetic during installs. If annoying, consider notifier position/filtering, not a functional UI break.
- **Initial probe false-positive:** `diag_float_closes_on_move` failed when target line also had diagnostics (expected to show that line’s float). Corrected test confirms clean-line close works.

## Implemented from plan (follow-up pass)

| Item | Change | File |
|---|---|---|
| P2 DiagnosticChanged coalescing | `DiagnosticChanged` now debounced (80ms), normal-mode only, shares timer/reset; avoids stream spam | `lua/config/autocmds.lua` |
| P2 CursorMovedI reset | `CursorMovedI` stops timer + closes tracked diag float + resets throttle (no open in insert) | `lua/config/autocmds.lua` |
| P3 ghost text clarity | `ghost_text.show_with_menu=false` (still shows with selection) to reduce menu/preselect confusion | `lua/plugins/completion.lua` |
| P2 hover/signature coexistence | Kept targeted diag-float close (not all relative floats); hover self-closes on move in probe | verified; monitor in real project |

## Remaining (manual / environment-dependent)

| Priority | Issue | Action | Validation |
|---|---|---|---|
| P3 | Snacks notifier / hit-enter during async errors | ui2 disabled; most noise fixed (`vts` package). Watch mason/lazy/plugin errors in real use. | Fresh startup, `:messages` clean enough |
| P3 | Real TS multi-dependency project pass | Imports from `node_modules`, path aliases, project references, multiple buffers/splits — vtsls progress/diagnostics volume. | Open your actual project; check statusline progress, diag popups, completion, `gd/gr/ca` floats, hover/signature |

## Validation checklist (after changes)
```sh
cd ~/.config/nvim && stylua --check .
```
- Restart Neovim (or `<leader>ur` / reload) so autocmds/options apply.
- `/pattern` Enter, `:e <partial><Tab/auto>`, `:messages` — no ui2/cmdline_show errors.
- TS buffer with diagnostics: land on error → popup appears; move to clean line → disappears; rapid scroll → no spam/stacking.
- Completion: type identifier trigger → menu appears, first item selected, `<Tab>` accepts (no unwanted auto-insert before Tab).
- Hover `<K>`, code action `<leader>ca>` / picker UI — floats behave, no orphans after move/close.
- Multi-buffer TS project: statusline/tabline stable, no duplicate vtsls clients.

## Files changed
- `lua/config/options.lua` — disabled ui2; `wildmode=full,full`.
- `lua/config/autocmds.lua` — cmdline comment; diagnostic float debounce + tracked win id + targeted close; debounced `DiagnosticChanged`; `CursorMovedI` reset.
- `lua/plugins/lsp.lua` — mason `vts` → `vtsls`.
- `lua/plugins/completion.lua` — `ghost_text.show_with_menu=false`.
- `docs/superpowers/plans/2026-11-07-nvim-ui-bugs-plan.md` — this report/plan.