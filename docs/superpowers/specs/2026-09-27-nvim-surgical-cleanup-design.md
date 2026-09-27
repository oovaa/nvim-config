# Nvim Surgical Cleanup — Design

Date: 2026-09-27 · Scope: performance + modernization, no workflow changes.
Goal: remove dead/cmd-only plugins, migrate their last consumers to snacks/builtin,
fix stale config. Daily keys stay identical except `<leader>mb` (dropped, see M3).

## 1. Verified findings (headless checks on NVIM v0.12.5)

- `vim.o.lazyredraw` still readable → F1 flip candidate (Noice, the reason for
  `false`, is already removed).
- `vim.g.did_load_filetypes` is `1` by default → filetype.vim already skipped.
  The planned `do_filetype_lua` item is a no-op and is DROPPED.
- Installed `actions-preview.nvim` ships `backend/snacks.lua` → M1 is one line.
- Installed `todo-comments.nvim` registers `Snacks.picker.sources.todo_comments`
  (`lua/todo-comments/snacks.lua`) → M2 is one line.
- `snacks.nvim` has NO LSP-progress UI (no `LspProgress` refs anywhere) →
  correction to the approved premise: fidget is replaced by builtin
  `vim.lsp.status()` (confirmed `function` on 0.12) in the statusline, not snacks.
- `snacks.picker/source/` has no bookmarks source → M3 drops the section.
- `nui.nvim` is only required by neo-tree (actions-preview moves to snacks
  backend) → orphaned, removed by `:Lazy clean`. No action needed.
- `plenary.nvim` STAYS (todo-comments, neotest, rest.nvim, vtsls depend on it).
- Dashboard session picker already falls back to `vim.ui.select` → M5 just
  deletes the dead telescope branch.

## 2. Removals

- R1 `neo-tree.nvim` spec (`lua/plugins/ui.lua:14-46`). Delete
  `silent! Neotree close` in `sessions.lua:85`, `spec.lua:404,435`. Trim dead
  ft comparisons: `terminal.lua:78-84` guard, `spec.lua:180`
  (`neo-tree`/`TelescopePrompt` arms; keep `lazy`/`dashboard`).
  Options comment `options.lua:54-55` reworded (netrw replaced by snacks explorer).
- R2 `telescope.nvim` + `fzf-native` + `ui-select` (`lua/plugins/visual.lua:95-187`).
- R3 `telescope-vim-bookmarks.nvim` + `vim-bookmarks` — delete
  `lua/plugins/bookmarks.lua` entirely (auto-imported, no other refs).
  Toggle/nav keys go with it (list UI was the only discoverable part).
- R4 `fidget.nvim` dep (`lua/plugins/lsp.lua:29`).

## 3. Migrations (telescope consumers)

- M1 `formatting.lua:18`: actions-preview `backend = { 'telescope' }` →
  `{ 'snacks' }`. Keys `gra`/`<leader>ca` unchanged.
- M2 `editing.lua:17-18`: drop `cmd = 'TodoTelescope'`; `<leader>st` →
  `require('snacks').picker.todo_comments()`.
- M3 `<leader>mt/mc/mj/mk/mb` removed with R3. **Decision point:** if bookmark
  toggles are muscle memory, alternative is keeping `vim-bookmarks` cmds only
  (telescope-free) — default is full removal.
- M4 Statusline LSP segment (`spec.lua:267-269`): when
  `vim.lsp.status()` returns non-empty, show it (progress) instead of the
  client name. **Decision point:** alternative is keeping fidget (tiny,
  FileType-loaded) — default is removal + statusline.
- M5 Dashboard session picker (`spec.lua:439-445`): delete telescope branch,
  keep `vim.ui.select` fallback as-is (plain but functional).
- M6 `qol.lua:43-44` command-palette comment: reword (ui-select gone;
  `vim.ui.select` is now builtin until a picker override is chosen).

## 4. Fixes

- F1 `options.lua:157-158`: `lazyredraw` `false` → `true`; rewrite comment
  (Noice gone). Smoke-test: macro playback, snacks input, `:StartupTime`.
- F2 `completion.lua:23`: `vim.fn.has 'win32'` →
  `vim.uv.os_uname().sysname == 'Windows_NT'` (trivial, same semantics).
- F3 `health.lua`: `rg` line → "snacks grep, grug-far"; `fd` line → "snacks
  picker"; `make` line → "LuaSnip jsregexp build"; drop `cmake` line
  (fzf-native was its only consumer).
- F4 Stale-comment sweep (no behavior change): delete commented noice block
  (`visual.lua:39-51`, git history is the revert); `options.lua:210`
  "(noice, blink, telescope)" → "(blink, snacks)"; `ui.lua:62,85-86,201`
  telescope/neo-tree remarks; `lsp.lua:87,133` telescope remarks;
  `appearance.lua:57-59` telescope hint → snacks resume key; `spec.lua:153,221,248`
  "noice-style/parity" → plain wording.

## 5. Explicitly unchanged

blink, conform, nvim-lint, snacks opts/keys, gitsigns, which-key, flash, mini.*,
ts-comments, auto-save, vtsls, molten, image, render-markdown, colorizer, dap*,
neotest, blame, refactoring, rest, aerial, bqf, grug-far, guess-indent, themes,
colorscheme, sessions/terminal/runner modules, all keymaps except `<leader>st`
(same key, new backend) and `<leader>mb` group (removed). No new plugins.

## 6. Verification

1. `:StartupTime` + `lazy.stats()` before/after (expect fewer plugins, same ±ms).
2. `:checkhealth config` clean; `:Lazy clean` removes neo-tree/telescope/
   bookmarks/fidget/nui/fzf-native without touching plenary.
3. Smoke: `gra` code action (snacks UI), `<leader>st` todo picker,
   macro record/playback, dashboard `s` session pick, LSP attach + progress
   text in statusline, `:Mason` tools intact.

## 7. Out of scope

Aerial/bqf/grug-far retention debate, new QoL plugins, theme changes,
`vim.fn.has 'gui_running'` idiom (not deprecated), CI profiling.
