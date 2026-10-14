# Neovim Config Improvement Plan — Performance, Tooling, QoL, UI/UX, Modularity

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `/home/omar/.config/nvim` across performance, faster external tooling, QoL, UI/UX, and code cleanliness/modularity without changing daily keymap behavior or letting the measured startup budget regress.

**Architecture:** Work in narrow, behavior-preserving slices. Baseline first (stress suite, startup median, external binary state), then refactor the largest unwieldy modules behind tests, then add faster tool backends only as an additive fallback (keep prettier and current LSP paths working), then harden optional-tool health. Each slice is independently reversible and ends with plenary + stress + stylua + headless boot.

**Tech Stack:** Neovim 0.12.6 LuaJIT, lazy.nvim, plenary.busted, stylua, snacks.nvim, conform.nvim, nvim-lint, blink.cmp, vtsls, pyrefly/ty, biome/oxlint/prettier, Mason, Tree-sitter (main branch).

**Spec:** User request: "do a deep scan and analysis into my nvim config and create a plan for improvement in terms of performance, tooling update with faster tools, QoL, ui/ux improvemnts, and code cleannes and modularity improvemnts. construct a plan and we review before executing."

## Global Constraints

- Neovim floor remains effectively 0.11+; CI pins 0.12.6. 0.12-only options (`smoothscroll`, `winborder`, `pumborder`) stay as they are.
- Startup median stays below the existing 400ms gate. Target no practical increase; preferred steady state ≤ 75ms warm.
- `stylua --check .` stays green (`column_width=160`, `call_parentheses=None`, `collapse_simple_statement=Always`); every code edit gets reformatted.
- No autocmd growth across a 4x `:source $MYVIMRC` reload: every new/changed `nvim_create_autocmd` needs `group = ...` with `clear = true`.
- No lockfile required by repo policy, but model versions stay noted; CI's `lazy.sync()` decides new plugin releases.
- `matchit`/`netrw` etc. builtin disables remain in `lua/config/options.lua` (source of truth) and `init.lua`.
- Never reintroduce `prettierd` (measured 850–2300ms cold start in this repo); the 2000ms synchronous `format_on_save` timeout is required.
- Never add Python packages to Mason `ensure_installed` (host python lacks `ensurepip`). Install with `uv`/system pip and make them optional + health-checked.
- New optional binaries must have `:checkhealth config` rows.
- Keep `ponytail:` comment style for intentional shortcuts: `shortcut: <limit>, <when to upgrade>`.
- Tree-sitter is on the `main` branch rewrite; never use removed master-branch APIs (`nvim-treesitter.configs`, query configs, autotag programming).
- Keybinding behavior remains unchanged unless the task says otherwise.
- Each phase ends with: plenary suite passes, stress suite passes (or known, documented warning), stylua clean, and `nvim --headless -c 'qa'` emits no E5108/traceback.

## Current Baseline (read before changing)

- Headless boot median: `20ms` (3 runs; budget 400ms).
- Stress harness: `880` pass, `1` fail, `3` warnings.
  - Failure: Molten remote plugin commands were never registered on the python3 host (`jupyter_client` / `IPython` missing).
  - Warnings: Tree-sitter `main` API compatibility, shared `gc` vs `gcc` prefixes, `nginx-language-server` not on PATH.
- Formatters: `prettier` cold start measured 270–470ms; `prettierd` deliberately removed.
- Linters: `oxlint` + `ruff`, both mason/PATH installed.
- Installed accelerators already available locally: `biome` 1.x at `~/.bun/bin/biome`, `fd`, `rg`, `bun`, `python3 3.15`.
- External targets missing on PATH (optional or degraded now): `pyrefly`, `basedpyright`, `ty`, `nginx-language-server`, Python `jupyter_client`.
- Health gate already covers `git`, `rg`, `node`, `fd`, `bun`, `lazygit`, etc.; does not cover `biome`, Python jupyter imports, or server binary resolution.

## Review Focus (likely behavior the current tests underspecify)

1. Editor data loss during fast typing: auto-save + `format_on_save` must keep the mid-insert guard (`format_on_save` returns nil in insert/select/replace) and timeout at 2000ms.
2. Autocmd stacking on config reload (`<leader>ur`) and repeated source (`tests/stress.lua` calls 4x): every new autocmd must have an idempotent named group.
3. Remote-plugin registration (`Molten*`) is environment-dependent; either install the Python deps or hide those keymaps cleanly.
4. Keyboard prefix collisions (`gc` prefix shadows `gcc`): commands like `git blame` / `gc` motion should resolve to longest prefix; avoid new single-letter overlays.
5. Tree-sitter compatibility on the `main` branch: `mini.ai`, `mini.surround`, autotag degrade silently and current tests only warn rather than fail.
6. LSP available binary check (optional servers have no fallback): health and stress should report it clearly.

## File Map (intended changes)

- `lua/custom/ui/spec.lua` — split the 634-line builtin module into focused statusline/tabline/dashboard/theme files.
- `lua/custom/ui/init.lua` — wire the split modules; keep API route stable.
- `lua/plugins/ui.lua` — de-duplicate the three identical exclude arrays by naming one table.
- `lua/config/autocmds.lua` — extract the embedded markdown list logic into `lua/config/markdown.lua` (or `lua/config/lists.lua`), register one named augroup.
- `lua/config/health.lua` — add optional binary/import checks for `biome`, `pyrefly`, `ty`, `python jupyter_client`.
- `lua/plugins/formatting.lua` — add biome as additive backend with prettier fallback + benchmark baseline.
- `lua/plugins/lsp.lua` — Python LSP targeting (`root_markers`, install instructions, optional `ty`), Pyrefly health and, if desired, Biome LSP.
- `lua/plugins/editing.lua`, `lua/custom/plugins/qol.lua` — optional UX additions only after core phases land.
- `lua/custom/ui/*.lua` — reduce custom UI duplication; possibly adopt `snacks.dashboard` after behavior tests.
- `README.md`, `AGENTS.md`, `SETUP.md` — keep docs as behavior truth, not prose drift.
- Tests to update/add: `tests/test_cleanup.lua` style behavior assertions; `tests/test_fmt.py`? No, Lua tests only.

## Phase A — Baseline And Safety Net

### Task A1: Record hard baselines before changing anything

**Files:**
- Modify: `docs/superpowers/plans/2026-10-14-nvim-improvement-plan.md` (this plan) only if the baseline numbers change on rerun.

- [ ] Re-run `tests/test_startup.lua`, `tests/test_performance.lua`, and `tests/stress.lua` on the exact current commit.
- [ ] Check `~/.config/nvim` working tree clean; use the commit SHA for comparison.
- [ ] Save the output durations and stress report SHA / queue count.
- [ ] Verify health state: `:checkhealth config` missing row count is exactly the known optional misses (`pyrefly`, `nginx-language-server`, `jupyter_client`).
- [ ] Commit nothing — this is the control point for every later measurement.

### Task A2: Add a regression assertion for autocmd count

**Files:**
- Create: `tests/test_autocmd_idempotency.lua`
- Modify: `tests/stress.lua` only if it must call the new assertion.

**Interfaces:**
- Consumes: `vim.api.nvim_get_autocmds {}` and `package.loaded`.
- Produces: a documented helper `H.autocmd_count()` or inline count used by tests.

- [ ] Write failing test that counts autocmds before and after sourcing `$MYVIMRC` four times and asserts no increase per named augroup.
- [ ] Run test and confirm failure only on cases intentionally exercised by later phases.
- [ ] Implement the test helper (counts `augroup` names, not raw callbacks).
- [ ] Run full plenary suite and confirm pass.
- [ ] Commit `test: add config-source idempotency baseline`.

## Phase B — Code Cleanliness And Modularity

### Task B1: Split `custom/ui/spec.lua` into focused modules

**Files:**
- Create: `lua/custom/ui/statusline.lua`
- Create: `lua/custom/ui/tabline.lua`
- Create: `lua/custom/ui/dashboard.lua`
- Modify: `lua/custom/ui/spec.lua` to become thin facade or be removed after callers updated
- Modify: `lua/custom/ui/init.lua`
- Tests: `tests/test_modular.lua`

**Interfaces:**
- Preserves: `_G._builtin_statusline`, `_G._builtin_tabline`, `_G._builtin_tabclick`, `_builtin_start` as dashboard entry, `_G._builtin_find_session`, `_G._builtin_session_files`, `_G._builtin_session_file`.
- `custom.ui.init.setup()` calls the same setup functions, in the same order.

- [ ] Write failing test that requires `custom.ui.statusline`, `custom.ui.tabline`, and `custom.ui.dashboard` independently and calls their setup with the same identifiers imported.
- [ ] Move statusline logic exactly first, with no behavior change; run statusline/tabline/status/redraw/unit tests.
- [ ] Move tabline logic next; run tabline interaction and mouse tab click tests.
- [ ] Move dashboard logic last; run dashboard build, keymap, recent-file tests.
- [ ] Wire `custom.ui.init.setup()` to the new modules; remove the monolithic file only after everything is green.
- [ ] Verify reload count: `<leader>ur` four times leaves augroup counts stable.
- [ ] Commit `refactor: split custom ui into focused modules`.

Note: split should reduce the largest file without changing global function names because the dashboard depends on session helper functions.

### Task B2: Extract markdown list formatter and de-duplicate snacks excludes

**Files:**
- Create: `lua/config/markdown.lua`
- Modify: `lua/config/autocmds.lua`
- Modify: `lua/plugins/ui.lua`
- Create/modify: `lua/config/snacks_excludes.lua`
- Modify: `lua/config/options.lua` only if the table genuinely belongs to core options
- Tests: `tests/test_markdown_lists.lua`, `tests/test_ui.lua` if present

- [ ] Move the markdown numbering/continuation block verbatim into `lua/config/markdown.lua`, preserving `renumber_below`, `item` and all event ordering.
- [ ] Retain one augroup named clearly; `autocmds.lua` calls `require 'config.markdown'.setup()`.
- [ ] Extract the repeated `node_modules`, `dist`, `.git`, etc. list to one named table and reference it with `vim.tbl_deep_extend` in `files`, `explorer`, and `grep` sources.
- [ ] Add byte-offset assertions already covered by tests; no line logic changes.
- [ ] Commit `refactor: extract markdown lists and snacks excludes`.

### Task B3: Normalize session and terminal globals into a module-local API

**Files:**
- Modify: `lua/config/sessions.lua`
- Modify: `lua/custom/ui/dashboard.lua` (after B1)
- Modify tests that read `_G` globals directly.

**Interfaces:**
- Change `_G._builtin_*` calls to `require('config.sessions')` accessors behind a stable function name (for example `M.find_session`, `M.session_files`, `M.session_file_for`) without changing behavior.

- [ ] Write failing test through the old global access path, then through the new module path.
- [ ] Move all `find_session_for`, `session_files`, `session_file_for` implementations into module-visible functions, retain a zero-width compatibility shim for existing dashboard/health/plugins, and log its use.
- [ ] Update dashboard to require the module.
- [ ] Run session and dashboard real-path tests.

Risk: The dashboard Lua copy currently references `_G` directly. Accessors must preserve Lua module caches and `require('config.sessions')` nil behavior after `<leader>ur` reload.

### Task B4: Health checks for optional tools and imports

**Files:**
- Modify: `lua/config/health.lua`
- Modify tests for health text if any.

**Interfaces:**
- Adds `check_binary`, `check_python_import`, and pyrefly diagnostic helpers in the same file.

- [ ] Add optional rows: `biome`, `pyrefly`, `ty`, `nginx-language-server`, Python import `jupyter_client`, Python import `ipykernel`.
- [ ] Mark missing Python imports specifically as optional unless Molten is specifically in use; then mark as warn plus setup command (`pip install --user jupyter_client ipykernel`).
- [ ] Add explanation text pointing to `:MoltenInit` and `:UpdateRemotePlugins`.
- [ ] Commit `feat: richer config health checks`.

## Phase C — Performance (runtime, not startup)

### Task C1: Preinstall Tree-sitter parsers and stop on-demand installs from feeling interactive

**Files:**
- Modify: `lua/plugins/treesitter.lua`
- Tests: `tests/test_performance.lua`, `tests/stress.lua`

- [ ] Option 1: keep `main` branch but move from ad-hoc `TSInstall` on `FileType` to an explicit, install-on-startup-once cache.
- [ ] Create a list of target languages actually used (`lua`, `vim`, `javascript`, `typescript`, `tsx`, `html`, `css`, `python`, `json`, `yaml`, `markdown`, `bash`, `c`, `cpp`, `rust`, `go`), gated by executable detection (`node` for LSP files) and `vim.o` trigger.
- [ ] Move parser install to a scheduled background job (avoid blocking first keystroke), log failures with debug, and never try again in the session after failure for that lang.
- [ ] Keep 200KB/minified guards for `vim.treesitter.start`.
- [ ] Test with a large mixed-language buffer and assert editor remains responsive (>=? no freeze), with the current large-file mode.
- [ ] Commit `perf: schedule baseline treesitter parsers`.

Note: this is likely a net performance and QoL change, not an attempt to fix the Tree-sitter `main` warning itself.

### Task C2: Background Mason `ensure_installed` from `FileType` entry path

**Files:**
- Modify: `lua/plugins/lsp.lua`
- Tests: `tests/test_startup.lua`, new runtime perf note only.

- [ ] Change mason spec from `event = 'FileType'` to a non-blocking initialization that still runs only after startup.
- [ ] Use `vim.schedule` / `vim.defer_fn` with a 250ms delay, and check `vim.fn.has 'gui_running'` / terminal.
- [ ] Skip when `vim.g.nvim_disable_mason` or headless mode.
- [ ] Ensure first opening of a managed filetype still works when installation takes time; LSP enable triggers only after server resolves or 5s.
- [ ] Keep current python/binary exclusions documented.
- [ ] Commit `perf: defer mason bootstrap out of file open`.

### Task C3: Session save and terminal helpers transaction cost

**Files:**
- Modify: `lua/config/sessions.lua`, `lua/config/terminal.lua`

- [ ] Remove duplicated directory scanning logic from session builder (one read per file already optimized) and prevent `mksession` from firing when dashboard active.
- [ ] Cache terminal width/height calculation and stop reading editor dimensions on every shell tab open.
- [ ] Check that no new OS calls happen on raw navigation.

Validation: measure in normal/buffer terminal mode.

## Phase D — Faster Tooling

### Task D1: Add Biome as additive formatter for JS/TS/JSON

**Files:**
- Create: `lua/plugins/tooling.lua` (or integrate into `lua/plugins/formatting.lua`)
- Modify: `lua/plugins/formatting.lua`, `lua/config/health.lua`
- Tests: `tests/test_performance.lua`; add `tests/test_formatting.lua`

**Interfaces:**
- `conform` still accepts `prettier` fallback.
- Formatting function signature unchanged: `conform.format { async = true }`.
- Define `formatters_by_ft` for `javascript`, `typescript`, ... use `{ 'biome', 'prettier' }` first-use (Biome first, prettier fallback).

- [ ] Write failing test asserts `conform` registry includes `"biome"` as formatter for JavaScript, and fallback prettier still exists.
- [ ] Implement `{ 'biome', 'biome-organize-imports', 'prettier' }` in appropriate file (Biome must use stdin path). Since conform's built in biome defaults usually include `--stdin-file-path`.
- [ ] Do not remove `prettier.config.json`; Biome reads `biome.json` if present, otherwise built defaults.
- [ ] Keep timeout_m 2000.
- [ ] Measure save time before/after with hyperfine and only enable if >= 30% improvement; otherwise leave opt-in toggle `<leader>tb` (or similar) but no default.
- [ ] Health in `checkhealth config` marks biome optional.
- [ ] Commit `feat: optional biome formatting backend (prettier fallback)`.

### Task D2: Linting and diagnostics with Biome (cleaner tool chain)

**Files:**
- Modify: `lua/plugins/ui.lua` (nvim-lint config)
- Modify health checks.

- [ ] Add Biome diagnostics for JS/TS/JSON only when project has `biome.json` or `biome.jsonc`, otherwise remain `oxlint` + ruff.
- [ ] Ensure no overlapping duplicate diagnostic messages, or define preference rule: Biome if config file, else oxlint.
- [ ] Health check says which linter is active based on cwd.

### Task D3: Python LSP/toolchain decision

**Files:**
- Modify `lua/plugins/lsp.lua`
- Modify setup docs.

- [ ] Promote `pyrefly` or choose `ty`/`basedpyright` based on Python 3.12 support and current 3.15 host. Use a small ladder:
  - If `ty` (Astral) available on PATH, prefer it as fast LSP.
  - Else prefer pyrefly.
  - Else fall back to python3 `pyright` if available.
  - Else no server + `:checkhealth config` explicit warning.
- [ ] Add native root markers to Python LSP config instead of relying on all default behavior: `pyproject.toml`, `setup.cfg`, `requirements.txt`, `.git`; proper `filetypes` mapping trigger only when executable.
- [ ] Do not auto-install any Python LSP through Mason.
- [ ] Add Neovim command `:NvimCheckPythonLsp` or extend health.
- [ ] Run stress/lsp tests.
- [ ] Commit `feat: make python lsp fallback and health explicit`.

### Task D4: Java/TS server cleanup tradeoff

- [ ] Keep `vtsls` as canonical TypeScript LSP (measured already reduced cost).
- [ ] Lower maximum `maxTsServerMemory` to `2048` only if project tests show TypeScript types degrade, and set optional `maximumMemory` to `4096` for large monorepos via local override.
- [ ] Preserve watch options.
- [ ] No plugin changes other than docs.

## Phase E — Quality Of Life And UI/UX

### Task E1: Replace handmade dashboard with snacks.dashboard (carefully)

**Files:**
- Modify: `lua/custom/ui/dashboard.lua`
- Modify: `lua/custom/ui/init.lua`

- [ ] Prototype `snacks.dashboard` with equivalent header, buttons, recent/session picker.
- [ ] Preserve existing commands and paths:
  - `s` Recent Sessions
  - numbers recent files
  - session restore behavior
  - footer with version.
- [ ] Only switch implementation once byte/highlight and mouse tests pass.
- [ ] Delete 500+ lines of custom painting if the snack version passes a stress comparison.
- [ ] Commit `refactor: use snacks dashboard behind existing key contract`.

Risk: snacks dashboards differ from bespoke visual layout; keep old dashboard behind a git tag/commit so rollback is trivial.

### Task E2: Molten either works or is explicit (QoL decision)

**Files:**
- Modify `lua/custom/plugins/init.lua`
- Modify `lua/config/health.lua`
- Possibly setup docs / setup.sh

- [ ] A: Install `jupyter_client` + `ipykernel` with uv, run `:UpdateRemotePlugins`, verify commands.
- [ ] B: If not installing Python jupyter, disable `molten.nvim` with `enabled=false` in environments lacking import and put a visible health warning instead of stress failure.
- [ ] Do not change key wording in `CHEATSHEET.md` without confirmation.
- [ ] Ensure `<leader>m*` mapping failure is no longer an unresolved stress error.
- [ ] Commit `fix: make molten registration explicit`.

### Task E3: UI alignment and accessibility polish

**Files:**
- `lua/custom/ui/statusline.lua`, `lua/custom/ui/tabline.lua`
- formatting spec.

- [ ] Verify statusline truncation (`%<`) correct under narrowing windows.
- [ ] Color contrast review with flexoki and light themes; use fallback palette, not hardcoded per-theme.
- [ ] Disable `winblend`/`pumblend=10` if `NOTERMGUI` or accessibility flag; alternatively make configurable.
- [ ] Use `winborder` for all plugin popups (blink docs, snacks picker is already).
- [ ] Commit only after `test_ui` and dialog tests.

### Task E4: Better shell session QoL

**Files:**
- Modify keymaps/config only as needed.

- [ ] Add `undo` picker? Specifically command `:Undotree` using builtin `undotree` perhaps; if no plugin needed.
- [ ] Add buffer pinning mappings (`<leader>bp`) using `vim`,
- Maybe add `vim.ui.select` to use snacks (currently noted plain).
- Mark all optional.

## Phase F — Docs, Tests, Rollout

### Task F1: Update docs from actual config and health

**Files:**
- `AGENTS.md`, `README.md`, `SETUP.md`, `CHEATSHEET.md`, `health.lua`

- [ ] Remove stale plugin and key binding claims.
- [ ] Ensure Molten deps plus Python jupyter install instructions.
- [ ] Keep trap comments synchronized.
- [ ] Run documentation-only workflow.

### Task F2: Enforce new tests and baseline

- [ ] `tests/test_autocmd_idempotency.lua` added in Phase A.
- [ ] Add behavior assertion for markdown spacing, bufferline states, restore.
- [ ] Add `test_formatting.lua` (after D1) measuring only registration/modes, not benchmark output.
- [ ] Add `test_python_tools.lua` to check resolver function behavior (mock executable).
- [ ] Update `tests/test_performance.lua` with concur pair checks.

### Task F3: Final validation and report

- [ ] `stylua .`
- [ ] Plenary all suites
- [ ] Stress harness baseline versus current
- [ ] Manual smoke: opening `.py`, `.ts`, `.md`, fugitive/Gitsigns, HTTP, dungeon? 
- [ ] Review diff for repeated code and keymap changes
- [ ] Check tree of files no huge ones.
- [ ] Commit each logical task; push only when asked.

## Risks And Intentional Deferrals

- Tree-sitter `main` warning from stress is mostly plugin-side, not config-specific. We can't eliminate without either pinning incompatible plugins or replacing mini modules.
- Python on this host is bleeding-edge (3.15), so Mason's pynvim/Python package support is degraded. Host-local install (`uv tool`/`python -m pip --user`) is necessary.
- Molten may fail due to service dependencies, so Phase E2 includes explicit fallback; don't pay the dependency setup only to keep unused plugin.
- Biome readconfig and formatter changes could diverge from project style; fallback backend protects data and history.
- Statusline/dashboard refactor carries visual risk; move in small slices and keep fallback available one commit at a time.
- LSP choice among pyrefly/ty/basedpyright depends on security and hard data; benchmark actual servers before promoting.

## Estimated Scope

- Estimated meaningful files modified: 15-22.
- Estimated lines reduced / moved: 700-1100 (largest reductions come from B1/E1).
- Estimated added: 250-450 (tests, backends, health).
- First target: modularity, health, baseline tests. Second target: performance and tooling swaps. Last target: dashboard aesthetics and optional QoL.

### Final Review Requirement

Do not execute implementation until the user has reviewed this document. Wait for "go ahead" or a requested phase scope.