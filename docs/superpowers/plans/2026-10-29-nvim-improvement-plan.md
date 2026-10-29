# Neovim Config — Improvement Plan (2026-10-29)

**Date:** 2026-10-29 · **Branch:** master · **Measured on:** nvim 0.12.6, stylua 2.5.2
**Baseline:** `stylua --check .` green · headless boot smoke clean · `tests/test_*.lua` all pass · stress test 0 FAIL / 2 WARN (914 PASS) · startup median 126.3 ms (gate 400 ms).

This plan is scoped to the request: performance, UI/UX, QoL, docs, modularity, and cleanliness. It does **not** repeat the P0 safety-net work already tracked in `docs/superpowers/plans/2026-10-15-improvement-and-e2e-plan.md`; that plan's rot-gate tasks (CI loop, revived e2e, mutations) are assumed to land first or in parallel.

---

## 0. Executive summary

| Sev | Finding | Where | Effort |
|---|---|---|---|
| P1 | README advertises ~20–30 ms headless startup; measured median is 126.3 ms. | `README.md` | S |
| P1 | Dashboard `<CR>` on a recent row computes its target from a magic row formula (`pad_top + 2 + 6 + 1 + #buttons + 1 + 1`); any layout change silently opens the wrong file. | `lua/custom/ui/dashboard.lua:234` | S |
| P1 | C/C++ runner compiles to `/tmp/<basename>`: same-named files in different dirs collide, stale binaries linger, and a leftover binary can be executed after a source change. | `lua/config/runner.lua:23,26` | S |
| P1 | Dashboard `g` (LazyGit) opens an in-place `:terminal` instead of reusing the configured `<leader>fg` float, so it hijacks the current window and loses dashboard context. | `lua/custom/ui/dashboard.lua:68` | S |
| P2 | `have_nerd_font = false` is documented as an escape hatch but the custom UI emits PUA glyphs unconditionally. | `lua/config/options.lua:90-95` + UI modules | S |
| P2 | Modularity drift: `_G._builtin_*` shims remain the real API for dashboard, terminal state, statusline/tabline, and tests; `custom/ui/spec.lua` is only a compat facade. | `lua/config/sessions.lua`, `lua/config/terminal.lua`, `lua/custom/ui/*` | M |
| P2 | Docs drift: README feature list, SETUP, CHEATSHEET, and AGENTS.md describe behavior that has since changed (startup time, dashboard, session restore). | `README.md`, `SETUP.md`, `CHEATSHEET.md`, `AGENTS.md` | M |
| P3 | Performance headroom exists in CursorHold-driven work and autocmd churn; needs measurement before editing. | `lua/config/autocmds.lua` | M |

**Not a bug:** stress test is green (0 FAIL). The treesitter "main branch rewrite" warning is expected and tracked separately; do not "fix" it by downgrading plugins.

---

## 1. Scope guardrails

Do **not** do these — they were already evaluated and rejected or are out of scope:

- No rewrite to `snacks.dashboard`; keep the custom dashboard.
- No startup micro-optimization beyond measured hot spots (already under the 400 ms gate).
- No new dependencies or plugins.
- No `prettierd` (forbidden on this host).
- No changes to the Python LSP ladder (`ty` → `pyrefly` → `pyright`).
- No changes to leader key or core keymap groups.
- No removal of the `_G` shims until callers/tests are migrated in the same commit.

---

## 2. Performance

### 2.1 Measure before editing
**Task P-1** — Capture a real startup profile and identify the top 5 time consumers.
- Run `nvim --startuptime /tmp/opencode/startup.log` on a cold boot and a warm boot.
- Run `:StartupTime` inside an interactive session.
- Record the top consumers in this plan's `## 9. Risks` section before any edit.
- **Verify:** numbers committed as a baseline table; no code change yet.

### 2.2 CursorHold and autocmd churn
**Task P-2** — Audit `updatetime = 250` (options.lua:190) and CursorHold handlers.
- List every `CursorHold`/`CursorHoldI` autocmd in `lua/config/autocmds.lua`.
- For each, confirm it is cheap or gated behind `vim.g.large_file_mode`.
- If a handler shells out or does filesystem work, move it to `CursorMoved` throttling or an `Idle` autocommand.
- **Verify:** `nvim --startuptime` delta ≤ 0 ms regression; add a stress check for no duplicate autocmds after `<leader>ur`.

### 2.3 Large-file mode coverage
**Task P-3** — Ensure every expensive feature honors `vim.g.large_file_size`.
- Grep for `large_file` and confirm colorizer (200 KB guard), treesitter, and render-markdown all disable above threshold.
- Add the missing guards (if any) rather than lowering the threshold.
- **Verify:** stress test opens a 2 MiB file and asserts `b:large_file_mode` + no formatter run.

### 2.4 Async boundaries (keep as-is unless measured)
**Task P-4** — Do **not** convert `format_after_save` to async (Trap 11 rationale). Only revisit if profiling shows it dominates startup or save latency above 400 ms.
- **Verify:** n/a — documentation-only decision.

---

## 3. UI/UX

### 3.1 Dashboard row tracking (fix magic math)
**Task U-1** — Replace `first_recent` formula with an explicit row variable captured during render.
- In `setup_starter`, record `recent_start_row` when recent lines are appended (instead of recomputing from `pad_top + 2 + 6 + 1 + #buttons + 1 + 1`).
- Update the `<CR>` handler to use that variable.
- **Verify:** existing dashboard stress checks still pass; add a check that pressing `<CR>` on the first recent row opens `recent[1].path` in a 3-recent fixture.

### 3.2 Dashboard LazyGit should reuse the float
**Task U-2** — Make the `g` button call the same float as `<leader>fg`.
- Export `toggle_float` from `lua/config/terminal.lua` (or add `M.toggle_float`).
- Change dashboard action to `require('config.terminal').toggle_float('lazygit')`.
- **Verify:** stress `terminal: <leader>fg (lazygit) without error` still passes; manual check that `g` opens and closes the float.

### 3.3 Nerd-font escape hatch
**Task U-3** — Either honor `vim.g.have_nerd_font = false` or correct the comment.
- Preferred: gate PUA glyphs in statusline/tabline/dashboard behind the flag, falling back to ASCII.
- If too invasive, change the comment to state the UI assumes a Nerd Font.
- **Verify:** boot with `have_nerd_font = false` and assert no U+FFFD in rendered statusline/tabline.

### 3.4 Dashboard empty states and accessibility
**Task U-4** — Improve dashboard UX without changing layout philosophy.
- Cap recent paths at ~60 display cells (already done in `collect_recent`; verify no regression).
- Add a visible empty state when there are zero recents (currently silent).
- Ensure every button key is reachable and described in `which-key` groups.
- **Verify:** dashboard stress checks + manual 60/80/120 column check.

### 3.5 Statusline/tabline polish
**Task U-5** — Apply the documented polish items.
- Escape `%` in branch name, filename, and tabline buffer name (one shared helper).
- Drop `enc`/`ff` segments (9 cells of noise) unless a test asserts them.
- Add a which-key group for `<leader>l` (`ls`, `lS`, `lr`).
- **Verify:** golden statusline snapshot update is deliberate (`UPDATE_GOLDEN=1`) and reviewed.

### 3.6 Theme mode-colored line numbers
**Task U-6** — Cache palette per colorscheme (already partially done); verify no ModeChanged re-runs tokyonight setup.
- Confirm `pal_cache` is keyed by colorscheme and cleared on `ColorScheme`.
- Replace hardcoded tokyonight hexes in `tabline.lua` with live highlights where feasible.
- **Verify:** `:StartupTime`/ModeChanged profiling shows no repeated `tokyonight.colors.setup`.

---

## 4. QoL

### 4.1 Runner temp binary safety
**Task Q-1** — Fix C/C++ runner output path.
- Use `vim.fn.tempname()` for the output binary instead of `/tmp/<basename>`.
- Append cleanup (`rm -f`) so the binary does not linger.
- Keep `shellescape` on both source and output.
- **Verify:** run two same-named `.cpp` files in different dirs; both succeed; no stale binary remains.

### 4.2 Runner UX
**Task Q-2** — Small runner improvements.
- Reuse the bottom split terminal buffer when possible (like terminal module).
- Add a "No runner for filetype" message that lists supported filetypes.
- **Verify:** manual run of JS/TS/Python/C/C++.

### 4.3 Terminal module exports
**Task Q-3** — Replace `_G` terminal state with module state plus a documented export.
- Export `M.toggle_horiz`, `M.toggle_float`, `M.toggle_last` (and keep `_G` shim one release).
- Update dashboard and tests to call the module.
- **Verify:** reload idempotency test still passes; no orphaned terminal buffers.

### 4.4 Session hygiene
**Task Q-4** — Prune stale session files.
- Add a best-effort prune of `sessions/*sandbox*` and files whose `cd` target no longer exists.
- Run only on `VimLeavePre` or a manual command; never on startup.
- **Verify:** stress session tests unchanged; manual check in a temp data dir.

---

## 5. Docs

### 5.1 Correct startup claim
**Task D-1** — Update `README.md` to state the measured median (~126 ms) or remove the number.
- Also update `SETUP.md` if it repeats the claim.
- **Verify:** grep for "20-30ms" / "30-60 ms" returns no stale claims.

### 5.2 Sync docs with current behavior
**Task D-2** — Audit and update `README.md`, `SETUP.md`, `CHEATSHEET.md`, `AGENTS.md`.
- Dashboard keys and recent-project picker.
- Session restore via `s` (no auto-restore on VimEnter).
- Python LSP ladder and `mason` limitations (no Python packages).
- Terminal toggles and runner keys.
- **Verify:** every documented key exists (`tests` integrity check passes).

### 5.3 Module READMEs
**Task D-3** — Add a one-paragraph header to each `lua/config/*.lua` and `lua/custom/ui/*.lua` (many already have them; fill gaps).
- Standardize the "WHAT / TO CHANGE / EFFECT" comment block.
- **Verify:** `stylua --check .` still green.

---

## 6. Modularity & cleanliness

### 6.1 Remove compat shims (phased)
**Task M-1** — Migrate callers off `_G._builtin_*`.
- Dashboard → `require('config.sessions')`, `require('config.terminal')`.
- Tests (`test_e2e_features.lua`, `stress_child.lua`, `test_config_modules.lua`) → module requires.
- Then delete the `_G` assignments in `sessions.lua`, `terminal.lua`, `statusline.lua`, `tabline.lua`, `dashboard.lua`.
- **Verify:** full test suite + stress test green after each sub-step.

### 6.2 `custom/ui/spec.lua` facade
**Task M-2** — Either make `spec.lua` a real aggregator or delete it.
- If no external caller needs it, remove and update `init.lua`/tests.
- **Verify:** `require('custom.ui.spec')` either works (aggregator) or is unused (grep).

### 6.3 Standardize ponytail comments
**Task M-3** — Ensure every shortcut comment follows `shortcut: <limit>, <when to upgrade>`.
- Grep for `ponytail:` comments and convert free-form ones.
- **Verify:** a small lint script (or manual review) confirms format.

### 6.4 Remove dead code
**Task M-4** — Delete confirmed-dead branches.
- Dashboard `sessions.lua:83` never returns nil: remove the fallback that builds the legacy `%2F` name (Trap 10 drift).
- Any other branch guarded by a condition that can never be false.
- **Verify:** tests pass; no `_G` fallback needed.

---

## 7. Tests & verification

### 7.1 New/updated tests
- Dashboard `<CR>` recent-row opens the correct file (unit + stress).
- Runner C/C++ temp path collision (stress child with two same-named files).
- Nerd-font false mode renders no PUA (boot test).
- Terminal float reuse from dashboard `g`.
- Docs key existence (already in integrity test; ensure README keys are covered).

### 7.2 Keep the safety-net work in sync
- Re-run the 2026-10-15 plan's rot gates after these changes.
- Mutation seeds from that plan must still go red.

### 7.3 Verification commands (run after every task)
```sh
stylua --check .
nvim --headless -c qa
nvim --headless -c 'luafile tests/test_config_modules.lua' -c qa
nvim --headless -c 'luafile tests/stress.lua' -c qa
```

---

## 8. Execution order

| # | Task | Why first |
|---|---|---|
| 1 | D-1 startup claim + P-1 profiling | Establishes honest baseline and measurement |
| 2 | U-1 dashboard row tracking + U-2 float reuse | Highest-risk UI correctness bugs |
| 3 | Q-1 runner temp binary | Data-safety adjacent |
| 4 | U-3 nerd-font hatch decision | Small, user-visible |
| 5 | M-1 shim migration (phased) | Enables later cleanup |
| 6 | U-5 statusline/tabline polish + U-6 theme | UI freeze after correctness |
| 7 | Q-2/Q-3/Q-4 terminal/runner/session QoL | Quality improvements on stable base |
| 8 | D-2/D-3 docs + M-2/M-3/M-4 cleanup | Last, after behavior is settled |
| 9 | 7.1 new tests + rot gates | Lock in the result |

Each step ends with: plenary green, stress green, `stylua --check .` clean, headless boot silent.

---

## 9. Risks and open questions

- **Measured numbers are host-specific.** 126.3 ms median depends on this machine's plugins/cache; do not overfit to it.
- **Dashboard `<CR>` fix** must preserve the existing row math for the current layout; add a regression test before changing it.
- **Runner cleanup** using `rm -f` assumes a POSIX shell; on Windows (not this host) the command needs adjustment. Marked `[unverified]` for other platforms.
- **`toggle_float` export** changes terminal module's public surface; check `tests/test_config_modules.lua` expectations before removing shims.
- **Nerd-font gating** touches many UI modules; may be larger than estimated — the fallback (correct the comment) is acceptable.
- **Docs updates** must not claim features that are not implemented; verify each statement against code before committing.

---

## 10. What this plan intentionally does not change

- Leader key, core keymap groups, Python LSP ladder, provider disables.
- `format_after_save` synchronicity (Trap 11).
- Custom dashboard (vs snacks.dashboard).
- treesitter main-branch pin and its CLI requirement.
- `lazy-lock.json` policy (gitignored by design).
