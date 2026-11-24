# Nvim Config Repair — Design

Date: 2026-11-24 · Scope: correctness, test safety, measured performance, and terminal UX.

## Intent

Repair verified defects in the existing Neovim configuration without changing its visual identity, adding dependencies, or turning the audit into a broad refactor. Preserve the user's current uncommitted work, reconcile the newer `origin/master`, verify behavior with real regressions, and push the completed result.

The audit found green tests that hide runtime errors, startup paths that skip intended setup, several LSP/lifecycle bugs, and small but measurable redraw and laziness problems. Startup is already healthy (about 48 ms headless), so startup optimization is a guard against regression, not a redesign target.

## Goals

- Eliminate destructive or collision-prone test fixtures.
- Fix verified LSP, Treesitter, diagnostics, Markdown, session, terminal, and command behavior.
- Replace skipped or manufactured tests with behavioral regressions.
- Make CI reject hidden tracebacks and failed child processes.
- Restore intended lazy loading and avoid unnecessary work on large files and frequent redraws.
- Correct misleading commands, labels, and documentation.
- Keep all existing tests, stress checks, formatting gates, and plugin count within current constraints.

## Non-goals

- No new plugins or dependencies.
- No colorscheme, layout, or visual redesign.
- No broad module reorganization.
- No changes to intentional format-on-save timeouts, Python LSP ladder, Mason exclusions, Treesitter API choice, or byte-offset handling.
- No speculative optimization without a before/after measurement.
- No changes to unrelated user configuration outside this repository.

## Constraints

- Neovim 0.12.6 is the supported and CI-pinned version.
- Preserve the eight currently dirty files and their intended fixes; do not overwrite them during rebase or implementation.
- `origin/master` is three commits ahead of local `HEAD`; reconcile it before pushing.
- Use named `clear = true` autocmd groups and buffer-specific callbacks.
- Keep `<leader>ur` as the real reload path: evict `config.*`/`custom.*` modules before sourcing `$MYVIMRC`.
- Keep the 200 KB Treesitter guard and 1 MiB large-file cleanup threshold unless measurements justify changing them.
- Do not reintroduce prettierd, async format-on-save, or lower the 2000 ms formatting timeout.
- Keep Biome root rejection for `$HOME` and lint cwd pinning.
- Keep session logic in `config.sessions`; the dashboard consumes that module rather than `_G` aliases.
- Stylua must pass on touched files.

## Approaches considered

1. **Surgical repair — selected.** Fix verified defects, add regressions, then apply measured optimizations while preserving the current UI and architecture.
2. **Performance-only pass.** Rejected because it leaves known crashes, broken LSP startup, unsafe fixtures, and false-green tests.
3. **Broad UI redesign.** Rejected because startup is already fast, the existing interface is coherent, and the user asked for optimization rather than a new visual direction.

## Scope and sequence

### 1. Preserve and reconcile existing work

- Snapshot the current dirty diff before changing Git state.
- Safely stash or otherwise preserve it, rebase local `master` onto `origin/master`, then restore it.
- Resolve the overlapping `tests/stress_child.lua` changes deliberately: retain the user's intent while removing skips that mask fixed bugs.
- Keep documentation for `<leader>nn` and temporary-subtree session suppression.

### 2. Make tests safe and truthful

- Replace fixed fixture directories and repo-root probe files with unique paths owned by each test.
- Refuse pre-existing paths and delete only files/directories created by that test.
- Move session fixtures outside suppressed temporary subtrees without using predictable shared names.
- Add a child-process Markdown regression that edits and wipes a buffer while CodeLens is active; fail on `Invalid buffer id`, tracebacks, or command errors.
- Assert child exit codes and clean stderr in E2E helpers.
- Replace required-tool `pending()` results with explicit capability assertions where CI is expected to provide the tool.
- Extend CI to reject stray tracebacks and failed child execution while still allowing intentional optional skips.
- Exercise the real `<leader>ur` callback/module eviction rather than bare `:source`.

### 3. Repair startup and language tooling

- Tailwind: call `on_dir(root)` only when a project root exists; preserve single-file behavior.
- Treesitter: factor the FileType starter, invoke it for already-loaded normal buffers, and explicitly stop Treesitter in oversized buffers. Add fresh-process tests for `nvim file.py` and a 256 KB Lua file.
- Java: attach JDTLS per buffer/root through a named FileType autocmd, including the already-open first Java buffer.
- Class navigation: make `[C`/`]C` and selection wrappers inert when no parser is available; restore stress coverage.
- CodeLens: disable the buffer's capability on `BufWipeout` before Neovim invalidates the buffer.
- Large files: gate native and direct LSP startup before process creation while retaining detach as a safety net.
- Multi-client document highlight: use client-specific cleanup or clear only after the final supporting client detaches.

### 4. Repair diagnostics, Markdown, and sessions

- Close tracked diagnostic floats before returning when the current line has no diagnostics; also invalidate on diagnostic changes.
- Use `vim.diagnostic.count` in the statusline and map counts into the existing severity cache.
- Apply Markdown buffer-local options to `args.buf`, not whichever buffer happens to be current.
- Detect oversized Markdown by filetype/buffer validity rather than only `*.md`.
- Share one normalized session-suppression predicate across writes, lookups, and project listings; cover trailing slashes, sibling prefixes, custom temp roots, and `TMPDIR='/'`.
- Filter stale temporary sessions from dashboard and conditional Resume choices.
- Make `:DiffOrig` diff the current buffer's file rather than the alternate buffer.

### 5. Restore intended laziness and redraw behavior

- Stop autoloading Blink from Mason/VTSLS setup before `InsertEnter`; verify default LSP capabilities and snippets still work.
- Disable redundant Snacks Words highlighting because the config already provides `<leader>uH` and has no Snacks Words jump mappings.
- Apply the existing insert/select/replace mode guard to lint-on-write; keep the final InsertLeave lint and manual lint.
- Invalidate and throttle statusline redraw on `LspProgress`/`Progress`.
- Reuse the existing terminal float toggle for dashboard LazyGit instead of creating untracked buffers/jobs.
- Preserve all measured behavior with tests or focused probes.

### 6. Correct UX and documentation

- Make `<leader>sp` open the existing Snacks projects picker.
- Truncate long dashboard Resume labels and narrow-window content without changing actions; fix home-prefix matching.
- Default remote Markdown image downloads to off. Document the explicit opt-in; this intentionally stops automatic network requests from untrusted Markdown.
- Move the Node dependency check before system package installation.
- Correct stale vtsls, session, tips, `<leader>h`, `gy`, and startup-report documentation.
- Make `:StartupTime` clear and sort its log; document that headless runs omit UI/VimEnter stages.

### 7. Deferred unless measurement proves value

- Session metadata caching/pruning.
- Theme-preview write debouncing.
- Snacks indent animation changes.
- Removing eager Actions Preview/Inc Rename attach hooks.
- Statusline search-count, documentation-resolution, checktime, TODO/Aerial large-file, and allocation micro-optimizations.

## Verification and acceptance

Before pushing:

1. `stylua --check .` passes.
2. All regular Plenary suites pass with no failures/errors, stray tracebacks, or unexpected pending results.
3. New regressions prove:
   - fixtures cannot overwrite or recursively delete pre-existing paths;
   - startup Python gets Treesitter and oversized Lua does not;
   - Tailwind and per-buffer Java roots attach;
   - parserless class motions are inert;
   - diagnostic floats close and CodeLens buffer wipes are quiet;
   - large files do not spawn LSP clients;
   - Blink remains unloaded before InsertEnter;
   - statusline diagnostic counting uses the non-copying API;
   - lint respects raw editing modes;
   - progress redraws and multi-client highlight cleanup work;
   - dashboard LazyGit reuses its float and `<leader>sp` opens projects.
4. Fresh-process startup and lazy-load probes pass; before/after startup medians are recorded and do not regress beyond noise.
5. Full stress harness completes with zero failures; warnings are reviewed rather than hidden.
6. Interactive terminal smoke checks cover dashboard, sessions, notifications/tips, completion, LSP progress, diagnostics, LazyGit, and narrow windows.
7. The complete diff is reviewed, commits are logical and conventional, and `git push` succeeds after remote reconciliation.

## Risks

- Upstream plugins have no lockfile, so behavior must be re-probed after synchronization.
- Lazy-load changes can accidentally affect snippets or LSP capabilities; fresh-process tests are required.
- Headless tests cannot fully validate interactive rendering; terminal smoke checks remain necessary.
- Disabling automatic remote-image downloads changes visible Markdown behavior but removes an internal-network request risk.
- The dirty worktree and remote branch overlap in `tests/stress_child.lua`; reconciliation must preserve both sets of intended changes.

## Builder discretion

Exact helper boundaries, test fixture naming, throttling constants, and commit granularity are left to the builder as long as the scope, constraints, and acceptance criteria above are met.
