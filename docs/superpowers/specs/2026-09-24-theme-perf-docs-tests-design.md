# Design: Theme picker swap, perf pass, docs, tests (2026-09-24)

## Goal

Single focused PR on `master` that: replaces Themery with the community-standard snacks colorscheme picker, lands only measured performance improvements, sweeps legacy APIs, updates all documentation, runs heavy e2e tests (including subagent bug hunts), fixes real findings, then reports what/why.

## Scope (approved approach: single PR)

### 1. Theme picker

- Remove `zaldih/themery.nvim` from `lua/custom/plugins/themes.lua`.
- Keep existing 13 lazy colorscheme plugins and eager `tokyonight` in `init.lua`.
- Bind `<leader>ty` to `Snacks.picker.colorschemes` (snacks.nvim already loaded for daily pickers).
- Remove duplicate Themery keymap in `lua/config/keymaps.lua` (keep one source of truth: snacks keys in plugin spec, or one keymap — match existing snacks key pattern).
- Persistence decision (verify during implementation):
  - If Themery currently restores the chosen colorscheme on startup → replace with a minimal state file under `stdpath('state')` written on picker confirm and read on `VimEnter`/colorscheme init (no new plugin).
  - If Themery does not restore on boot → do **not** add persistence; keep boot default `tokyonight-night` (YAGNI / match current behavior).
- Update comments in `lua/custom/ui/theme.lua` that say “persistence is owned by themery”.

### 2. Performance

- Capture a reliable baseline (`nvim --startuptime`) before edits; re-measure after.
- Ship only changes that show measurable improvement or are direct side effects of Theme removal (e.g. less setup work when opening the picker).
- Do not restructure `init.lua` or re-lazyload plugins without evidence — posture is already strong (`vim.loader`, lazy cache, disabled providers/plugins).

### 3. Legacy / API

- Re-grep after edits: `vim.loop`, `nvim_buf_get_option`, deprecated diagnostics, `buf_get_clients`, etc.
- Live code was clean pre-work; fix only real findings introduced or confirmed.

### 4. Tests (heavy e2e)

- Run all existing suites under `tests/test_*.lua` (performance, critical_fixes, qol, keymaps_autocmds, polish, lsp_servers) the same way CI does (plenary.busted).
- Headless boot: `nvim --headless "+qa"` must exit clean; fail on error output.
- `stylua --check .` must pass.
- New coverage:
  - `<leader>ty` maps to snacks colorschemes (not Themery).
  - `themery` absent from plugin spec / lazy plugins.
  - Persistence roundtrip only if persistence is implemented.
- After implementation: subagent pass to hunt bugs across changed paths; fix only reproducible issues.

### 5. Documentation (all user-facing docs)

Sweep every user-facing doc; edit where wording is wrong after the change (Themery, keys, tests, theme behavior). Expected hits:

- `README.md`, `SETUP.md`, `CHEATSHEET.md`
- `nvim-cheatsheet.md`, `vim-motions-cheatsheet.md`, `TMUX.md` (only if they mention themes/keys/tests)
- `doc/kickstart.txt` (only if it references themes/keys)
- `.github/pull_request_template.md` only if boilerplate is wrong for this repo

Do not invent new features in docs; only reflect shipped behavior. Grep for `Themery`/`themery`/`theme` across `*.md` and `doc/` so nothing is missed.

### 6. Ship

- Branch off `master` (e.g. `feat/snacks-theme-picker`).
- Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `perf:` as needed).
- `gh pr create` against `oovaa/nvim-config` `master`, using PR template structure (What / Why / How / Testing / Risk).
- Final user report: what changed and why.

## Out of scope

- Splitting `init.lua` into modules.
- New colorschemes or visual redesign.
- CI workflow redesign (reuse existing smoke-test + stylua).
- Changing default colorscheme unless persistence dictates restore of a prior choice.

## Success criteria

- PR opened; CI-relevant checks pass locally (boot, tests, stylua).
- No Themery references in code or docs.
- `<leader>ty` opens snacks colorschemes picker.
- Docs consistently describe the new picker and current keys.
- Startup baseline captured; no regression (or documented improvement).
- User receives a what/why change report.

## Risks / mitigations

| Risk | Mitigation |
|------|------------|
| snacks colorscheme source API differs from assumptions | Verify against installed snacks.nvim docs/source before coding keymap |
| Persistence half-broken like prior theme state | Verify actual boot behavior first; skip persistence if current doesn’t restore |
| Broad “update all docs” drifts from reality | Diff each doc claim against live config keys/plugins |
| Large PR | Keep code diff tight; docs bulk is acceptable per user request |
