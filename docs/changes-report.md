# Changes report: report picks (all but AI)

## Scope
Implemented the research report's recommendations except the AI plugin:
oil.nvim, trouble.nvim, dial.nvim, treesj, neogit, mini.visits, snacks zen/terminal.

Commit: 5cba4f8. Plugin count 65 -> 70 (at the <=70 budget).

## Performance (before vs after)

Measured headless, 3 runs, lazy.nvim window (LazyStart..LazyDone):

| Metric | Before (fab898a) | After (master) | Delta |
|---|---|---|---|
| Registered plugins | 65 | 70 | +5 |
| Loaded at startup | 10 | 10 | 0 |
| Lazy startup (ms) | ~19.9 | ~20.0 | ~+0.1 |
| Total startup (ms) | ~39 | ~39 | ~0 |
| test_startup budget | 400ms | 400ms (median 39ms) | pass |

Net: no measurable startup regression; all new plugins are key/cmd/event gated.

## Behavior before vs after

| Area | Before | After | Keys |
|---|---|---|---|
| File editing | snacks explorer only | oil.nvim edits dirs as buffers | `-` |
| Diagnostics list | snacks picker only | trouble.nvim panels | `<leader>xx` (all), `<leader>xX` (buf), `<leader>xs` (symbols), `<leader>xq` (qflist) |
| Increment/decrement | default on decimals | dial.nvim (dec/hex/date) | `<C-a>` / `<C-x>` |
| Split/join | mini.splitjoin | treesj (+mini) | `<leader>j` |
| Git UI | gitsigns only | neogit (magit-like) | `<leader>gn` |
| Visited files | none | mini.visits tracking | `<leader>va` add, `<leader>vv` select |
| Zen mode | unavailable | snacks.zen | `<leader>z`, `<leader>Z` zoom |
| Terminal | builtin terminal | snacks.terminal module also enabled (builtin keys unchanged) | (builtin `<leader>tt` etc.) |

## Unchanged / respected
- Builtin terminal keymaps preserved (no conflict).
- Builtin undotree (`<leader>uu`) retained; no duplicate plugin.
- No AI plugin added (per scope).
- Plugin count stays at budget (70).

## Verification
- plenary: test_startup, test_performance, test_modular, test_config_modules, test_e2e_features, test_polish, test_formatting — all pass (0 failures).
- All 5 new plugins register and their modules require cleanly.

## Scan round (commit 558781a)

Follow-up config scan for issues/UI-UX improvements. No breakage found; two small gaps fixed.

### Changes
1. `lua/plugins/visual.lua` — which-key group labels for report-pick namespaces that previously showed as unlabeled bare keys:
   - `<leader>b` → **[B]uffer** (`bd` delete, `bp` previous)
   - `<leader>x` → **[X] Trouble/Diagnostics** (`xx`, `xX`, `xs`, `xq`)
   - `<leader>v` → **[V]isits** (`va` add, `vv` select)
2. `lua/config/options.lua` — `vim.o.virtualedit = 'block'` (visual-block past EOL) and `vim.o.wildignorecase = true` (case-insensitive cmdline file completion), each with the file's standard WHAT/TO CHANGE/EFFECT comment block.

### Deliberately not changed
- `formatoptions` `o`/`r` (comment auto-continuation) — behavior change; opt-in.
- oil `skip_confirm_for_simple_edits` — removes delete confirmation (data-loss safety).
- No new plugins (at the 70-plugin budget).

### Verification
- Headless boot OK with new options.
- Full plenary suite: 19 files, 192 tests, 0 failures (startup budget 400ms passes).

## Plugin additions round

Four plugins requested; three added as new lazy specs, one was already present.

### Added (all in `lua/custom/plugins/qol.lua`)
1. **saxon1964/neovim-tips** — searchable browser of 2400+ tips. Keys `<leader>nto/ntb/ntr/nte/nta` (open / bookmarks / random / edit / add). `opts.daily_tip = 0` keeps it lazy; needs `MunifTanjim/nui.nvim`.
2. **f-person/git-blame.nvim** — virtual-text git blame, toggled by `<leader>ugb` (starts disabled). Distinct from the existing `FabijanZulj/blame.nvim` on `<leader>gb` (inline + hover) — both are deliberately kept.
3. **Bekaboo/dropbar.nvim** — IDE-style breadcrumb winbar (path + LSP/treesitter symbols). Keys `<leader>;` (pick), `[;` / `];` (context nav). Self-lazy-loads; auto-skips large files, help, and special buffers. Uses nvim-web-devicons already in the config.

### Already present — no change
- **akinsho/git-conflict.nvim** was already installed and configured (BufReadPre load, E2E test, documented in CHEATSHEET). Its buffer-local maps `]x`/`[x` and `co`/`ct`/`cb`/`c0` are unchanged.

### Other changes
- `tests/test_performance.lua` plugin-count bound raised `70 → 75` to cover the four new registrations (74 total).
- README.md / CHEATSHEET.md updated with the new keys and features.

### Verification
- `stylua --check` clean; headless boot OK; plugin count 74.
- All commands and keymaps confirmed registered after force-load.
- Full test suite: 18/19 files pass. The single failing file (`test_post_audit.lua`, 2 assertions) is a pre-existing stale test expecting the old `local` diag_float state that was moved to `_G._diag_float_state` in commit b43f78f — unrelated to this round.

## Cross-test round (UI bugs, perf, edge cases)

Full-config edge-case sweep (manual harnesses + two read-only subagents) found and fixed real defects. No breakage in boot, LSP, formatting, or lazy loading.

### Bugs fixed
1. **HIGH** `lua/config/options.lua` — removed `jump = { on_jump = true }` from `vim.diagnostic` config. `on_jump` must be a function; the boolean made `vim.diagnostic.jump()` throw `E5108`. The config's own `[d`/`]d` keymaps passed `float=true` and masked it; `diag_float` already shows the float on cursor move.
2. **MED** `lua/config/terminal.lua` — `<C-\>` restore used `toggle_float(vim.o.shell)`, which killed a hidden lazygit/tmux float and reopened a shell. Now uses `toggle_float(float.cmd or vim.o.shell)` so the same command is restored.
3. **MED** `lua/plugins/lsp.lua` — both `<leader>th` inlay-hint toggles now pass `{ bufnr = event.buf }`; `enable()`/`is_enabled()` with no filter toggled hints globally. Large-file branch keeps a buffer-local toggle.
4. **MED** `lua/custom/ui/theme.lua` + `lua/custom/ui/tabline.lua` — `live_fg` used `nvim_get_hl(0, { name = linked_group })`, which returns a `{ link = ... }` table with no `fg` for linked groups. Added `link = false` so the resolved foreground is used.
5. **LOW** `lua/config/diag_float.lua` — `DiagnosticChanged` callback now takes `ev` and early-returns for non-current buffers, so a float can't be opened for a background buffer.
6. **LOW** `lua/custom/ui/statusline.lua` — `mode_hl_key` matched `^t` (missed `nt` terminal-normal) and left select modes uncolored. Now matches `t$` and maps `s`/`S`/`\19` to visual.
7. **LOW-MED** `lua/plugins/lsp.lua` — removed an inert codelens refresh autocmd (wrong event/signature) that never fired; `vim.lsp.codelens.enable` still runs on attach.
8. **TESTS** `tests/test_post_audit.lua` — two assertions checked the old `local` diag_float state moved to `_G._diag_float_state` in b43f78f; updated to the new state shape.

### Verification
- `stylua --check` clean on all edited Lua files; headless boot OK; plugin count 74.
- Full test suite: 19/19 files pass, 0 failures.
- Smoke tests: `vim.diagnostic.jump{count=1}` no longer throws; inlay-hint buffer filter works; linked-group `fg` resolves; statusline module loads.

### Deliberately not fixed (LOW/TRIVIAL, minimal-diff judgment)
- Dead `biome-organize-imports` config, duplicate `resolve()`/`ensure_installed`/`mason_bin`/fold-loop lines, per-buffer treesitter `fs_stat`, dashboard narrow-window clip, and `appearance.lua` markdown `cond` evaluated once at setup — all harmless or need larger reworks; left to keep the diff tight.

## SQL lint/format noise fix (sqruff config)

### Problem
SQL files showed a wall of sqruff diagnostics (LT02 indent, LT05 line-length, LT08 CTE blank line) and scary "Formatter 'sqruff' error" notifications on save. Root cause: sqruff (both the conform formatter and the nvim-lint linter) ran with no explicit config, so it defaulted to ANSI dialect + `max_line_length=80`. `sqruff fix` exits 1 on non-fixable LT05/AL04, which conform reports as an error.

### Changes
1. Added `sqruff.toml` (repo root): `[sqruff]` with `dialect = "postgres"`, `max_line_length = 180`, `warnings = "AL04"`. Layout noise (LT02/LT05/LT08) is suppressed; the duplicate-alias rule (AL04, often a false positive across subquery scopes) stays visible as WARN instead of a fatal error.
2. `lua/plugins/formatting.lua` — conform's sqruff formatter now prepends `--config ~/.config/nvim/sqruff.toml`.
3. `lua/plugins/ui.lua` — the sqruff lint linter passes the same `--config` path. Explicit path avoids sqruff's unreliable cwd-based config discovery (a stray broken config can break every file).

### Verification
- `sqruff --config <cfg> fix` on `send-backs.sql` → "nothing to fix", exit 0 (no error notification).
- `sqruff lint --config <cfg>` → only AL04 as WARN; LT02/LT05/LT08 noise gone.
- `stylua --check` clean; headless boot OK; full suite 19/19 files pass.

## SQL auto-format on save (follow-up to caf1bdd)

The earlier `sqruff.toml` fixed the lint-diagnostic wall, but SQL still
*looked* like it wasn't auto-formatting: every save raised
`Formatter 'sqruff' error` because sqruff `fix` writes the formatted file yet
exits 1 when any non-fixable lint rule remains (ST03 unused CTE, LT05 long
lines, etc.). conform treats exit 1 as a formatter failure → scary error
notification, even though formatting succeeded.

### Change
- `lua/plugins/formatting.lua` — added `exit_codes = { 0, 1 }` to the sqruff
  formatter override (same pattern conform uses for markdownlint/rubocop/
  oxlint). Formatting always applies; remaining lint findings stay visible in
  the diagnostics/trouble panel via the linter, they just no longer masquerade
  as formatter crashes.

### Verification
- Save test with an unfixable ST03 rule: spacing still formatted
  (`select   a,b` → `select a, b`), **no** sqruff error notification.
- `stylua --check` clean; headless boot OK; full suite 19/19 files pass.
- Note: `LSP[sqls] no database connection` is a one-time on-attach info message
  (sqls has no `.sqls.yml`), not a format error — left as-is.

## Deep cross-test round (complex real-world workloads)

A second, deeper cross-test across the full feature set using realistic
multi-language monorepo workloads (TS/TSX, Python, JSON, YAML, JS, SQL) —
multiple files open at once, splits, terminal + editor mixed layouts, and
sustained-load checks. No config changes were needed: every apparent failure
was traced to the test harness, not the config.

### Verified working under load
- **LSP**: all six representative files attached the correct servers —
  `vtsls` (TS/JS), `vtsls` + `emmet` (TSX), `ty` (Python), `jsonls` (JSON),
  `docker_compose_language_service` (YAML); winbar breadcrumbs rendered.
- **Auto-save + format**: with a real `TextChanged` event, `x   =   1` was
  formatted to `x = 1` and written to disk end-to-end.
- **Formatting**: conform formatted Python and SQL; diagnostics navigation,
  Treesj, gitsigns/blame/conflict, oil, trouble panels, aerial outline,
  session save, pickers, grug-far, theme switch, zen, scratch, neotest and
  neogit all responded correctly.
- **Notifications**: zero WARN/ERROR notifications across all three harnesses.

### Apparent failures confirmed as harness artifacts (not bugs)
- LSP attach / which-key / checkhealth "failures" — async timing and mixed
  window state; all pass in isolation.
- Autocmd count rising (+895) — mini.nvim's own `SafeState` autocmds are
  `once=true`, self-deleting, and fire constantly in interactive use; mini.notify
  isn't even set up by this config. Not a leak.
- `]d` "No identifier under cursor" — the harness used `normal!`, which bypasses
  the `[d`/`]d` keymaps.
- oil / rest.nvim / DAP command lookups — oil opens via `-`, rest.nvim is
  configured through `<leader>hr` (no `:Rest`), and DAP configs live in a custom
  module; the harness assumed the wrong entry points.
- A ~300KB / 12k-line file staying on one LSP client is correct — it's under the
  intentional 1 MiB large-file threshold.

### Verification
- No code changes; full suite 19/19 files pass as regression proof.
