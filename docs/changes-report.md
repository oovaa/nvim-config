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
