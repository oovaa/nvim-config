# Neovim Config — Full-Scope Performance Plan (2026-11-03)

**Date:** 2026-11-03 · **Branch:** master · **Measured on:** nvim 0.12.6, stylua 2.5.2
**Baseline:** `stylua --check .` green · headless boot smoke clean · stress test `0 FAIL · 2 WARN · 916 PASS` in 121824 ms · startup `init.lua` sourcing 261.987 ms (cold, `--startuptime`) · 57 registered plugins.

This plan is scoped to **performance only** (startup + runtime + large-file + autocmd churn). It does not re-litigate the 2026-10-29 improvement plan's UI/QoL/docs tasks; where those touch perf (CursorHold, large-file guards) they are referenced, not duplicated.

---

## 0. Executive summary

The config is already well-optimized (lazy defaults, bytecode cache, builtin UI, native LSP, deferred mason/treesitter). The remaining headroom is **runtime**, not startup:

| Area | Current state | Opportunity | Expected gain |
|---|---|---|---|
| Statusline/tabline redraw | cached diagnostics + search count; still calls `vim.lsp.status()`/`vim.ui.progress_status()` and iterates all buffers every redraw | cache progress + buffer list; invalidate on events | fewer redraw allocations; smoother typing |
| CursorHold (250 ms) | single idle handler runs `checktime` + diagnostic float + LSP `documentHighlight` (per buffer, on LspAttach) | throttle diagnostic float; make documentHighlight opt-in/throttled | lower idle CPU; less LSP chatter |
| Large-file mode | guards in treesitter (200 KB), colorizer (200 KB), conform (1 MiB) | extend to render-markdown, snacks indent/scope, gitsigns, nvim-lint, todo-comments, aerial, snacks words | no stalls on >1 MiB files |
| mini.ai | `n_lines = 500` scans half a thousand lines per textobject | reduce to 200–250 | faster `va)`/`ii` on big files |
| LSP | lua_ls adds full runtime library only in config dir (good); vtsls `maxTsServerMemory = 2048`; multiple servers per html/css buffer | consolidate where safe; lower memory cap experimentally | lower peak RAM in TS projects |
| blink.cmp | `fuzzy.implementation = 'lua'` (no network fetch) | optional rust fuzzy when prebuilt binary present | faster completion ranking |
| updatetime | 250 ms drives CursorHold frequency | raise to 350–400 ms (measured) | lower idle wakeups |
| Snacks indent scope | TS field-climbing on every render | keep scope but disable on large files; optionally disable chunk | less TS work per redraw |

No change to: leader key, Python LSP ladder, provider disables, `format_on_save` sync (Trap 11), treesitter main-branch pin, `lazy-lock.json` policy.

---

## 1. Baseline (measured, do not overfit)

| Metric | Value | How |
|---|---|---|
| Cold boot, `init.lua` sourcing | 261.987 ms | `nvim --startuptime` |
| Opening a `.lua` file (cold) | 90.883 ms init + 82.525 ms buffer open | `--startuptime file.lua` |
| Registered plugins | 57 | `lazy.core.config.plugins` |
| Stress test | 0 FAIL / 2 WARN / 916 PASS | `tests/stress.lua` (121824 ms) |
| `updatetime` | 250 ms | `options.lua:197` |
| large-file threshold | 1 MiB | `options.lua:225` |
| treesitter/colorizer cap | 200 KB | `treesitter.lua:81`, `appearance.lua:41` |

Top cold-boot consumers (self+sourced, ms): tokyonight colorscheme 17.8, rplugin.vim 19.3, config.options 16.9, config.autocmds 15.3, vim.lsp 30.0, vim.filetype 7.9. These are mostly one-time and already deferred where possible; do not micro-optimize them (gate is 400 ms).

---

## 2. Hotspot analysis

### 2.1 Startup
- `vim.loader.enable()` + lazy cache already on. `rocks = { enabled = false }`, `defaults = { lazy = true }`.
- `mason` + `mason-tool-installer` deferred 250 ms and gated on UI/TTY. Good.
- treesitter bootstrap deferred 250 ms, gated on `tree-sitter` executable. Good.
- `colorizer`/`image.nvim` ft-gated. Good.
- Remaining: `config.options` launch-path self-heal globs `~/.local/share/pi-node/*/bin` at startup (minor). `vim.filetype` 7.9 ms (runtime, unavoidable).

### 2.2 Runtime / redraw
- `_builtin_statusline()` runs on every redraw. Already caches `_diag_counts`, `_lsp_name`, `_search`. Still calls `vim.lsp.status()`, `vim.ui.progress_status()`, `vim.fn.reg_recording()`, `vim.fn.reg_executing()`, `vim.b.gitsigns_status_dict` each redraw. Most are cheap but allocate strings.
- `_builtin_tabline()` iterates `vim.api.nvim_list_bufs()` and calls `_count_diags` for every listed buffer on every redraw. Cache was warmed on `BufEnter` (recent commit), but a tabline redraw before warm-up computes for all buffers.
- Snacks indent/scope/chunk: TS-based, recomputed on scroll. `scope = { cursor = false, edge = false }` already limits work.
- Snacks words: highlights word under cursor across the buffer on CursorMoved; can be heavy in large files.
- `cursorline = true`, `list = true`: redraw cost, but user-visible; keep.

### 2.3 CursorHold / idle
- `updatetime = 250` → idle handler fires ~4/s while idle.
- `idle-upkeep` (autocmds.lua:56): `checktime` + (if not large_file) `vim.diagnostic.get(0,{lnum})` + `nvim_list_wins()` + conditional `open_float`. The `list_wins` loop runs every idle tick even on clean lines (returns early after get, but get still runs). Minor.
- LSP `documentHighlight` registered on `CursorHold`/`CursorHoldI` per buffer (lsp.lua:104) → server request every 250 ms idle. For lua_ls/pyright this is non-trivial and happens even when the cursor rests on a keyword. This is the biggest idle cost.
- `snacks.words` also updates on CursorMoved (not idle) — keep but gate on large files.

### 2.4 Large-file mode gaps
`large_file_mode` is set at 1 MiB (BufReadPre) and honored by: conform (format_on_save returns nil), autocmds (swapfile/undofile/synmaxcol/diagnostics off). **Not honored by:**
- treesitter: has its own 200 KB cap (stricter) — OK, but inconsistent threshold.
- colorizer: 200 KB cap — OK.
- render-markdown (ft=markdown): no guard.
- snacks indent/scope: no guard.
- gitsigns: no guard (attaches on BufReadPost/BufNewFile regardless of size).
- nvim-lint: runs on BufWritePost/InsertLeave regardless of size.
- todo-comments: VeryLazy, scans buffer.
- aerial: global attach.
- snacks words: no guard.
- mini.ai `n_lines=500`: scans 500 lines even in huge files.

### 2.5 LSP
- lua_ls: `workspace.library` = all runtime files (heavy) only when editing config dir and no `.luarc`. Acceptable; needed for config editing.
- vtsls: `maxTsServerMemory = 2048`, `includePackageJsonAutoImports = 'auto'` (already optimized), `watchOptions` useFsEvents (already optimized).
- Multiple servers attach to the same buffer: html + emmet + (cssls for css). For a single html file, 2–3 servers. Each runs its own process. Could be acceptable; consolidating emmet into html? emmet is separate binary. Keep.
- `jsonls` attaches to every json/jsonc. Fine.
- Mason `ensure_installed` includes 12 tools; deferred. Fine.

### 2.6 Editing plugins
- mini.ai `n_lines = 500`: textobject search scans up to 500 lines. Reduce to 200.
- mini.pairs `skip_ts = { 'string' }`: TS check on every typed char. Minor.
- auto-save: `TextChanged` deferred save (1 s debounce). Fires timer reset on every normal-mode edit. OK.
- todo-comments: scans buffer on load. Minor.
- render-markdown: renders entire buffer on open. For large markdown, heavy.

### 2.7 Completion
- blink `fuzzy.implementation = 'lua'` avoids network but is slower than the rust matcher. Optional upgrade when network is available.
- `documentation.auto_show = true`, delay 300 ms. LSP doc fetch. Keep but could raise delay to 500.

---

## 3. Plan (phased)

### Phase A — Measure (no code)
**A-1** Capture per-plugin startup profile with `:Lazy profile` and record top 10 in this doc's §1. Verify: numbers committed; no code change.
**A-2** Profile statusline redraw cost with `:profile start /tmp/opencode/profile.txt` + `:profile func _builtin_statusline` while scrolling a 1k-line file; record. Verify: profile saved.
**A-3** Profile CursorHold cost: `:profile func` on idle 5 s in a lua buffer with lua_ls attached; record LSP documentHighlight request count. Verify: numbers recorded.

### Phase B — Runtime redraw (high impact, low risk)
**B-1** Statusline progress cache. In `custom/ui/statusline.lua`, cache `vim.lsp.status()` + `vim.ui.progress_status()` result for 100 ms (keyed by changedtick or time bucket) and only recompute when the bucket changes; reuse last string otherwise. Verify: stress statusline checks pass; manual scroll feels same.
**B-2** Tabline buffer-list cache. In `custom/ui/tabline.lua`, cache the list of buflisted buffer numbers and invalidate on `BufAdd`/`BufDelete`/`BufWipeout`; only recompute diagnostics for buffers whose `changedtick` changed. Verify: reload idempotency + tabline stress pass.
**B-3** Idle diagnostic-float throttle. In `config/autocmds.lua` `idle-upkeep`, skip `vim.diagnostic.get` when the cursor line equals the last checked line (cache `M._last_diag_line` per window). Verify: stress passes; float still opens on a new error line.
**B-4** updatetime experiment. Raise `updatetime` to 350 in `options.lua` and measure CursorHold frequency + LSP responsiveness. Keep 250 if documentHighlight latency regresses. Verify: `:StartupTime`/manual check; document as decision.

### Phase C — Idle/LSP chatter
**C-1** Make LSP documentHighlight opt-in. Add a global `vim.g.lsp_document_highlight = false` default (or keep true) and gate the `CursorHold`/`CursorHoldI` registration in `lsp.lua` behind it; expose `<leader>uH` toggle. Default to **off** to cut idle LSP traffic, on-demand via toggle. Verify: LSP attach stress passes; reference highlight still works when toggled on.
**C-2** snacks.words gating. Disable snacks.words on large files (in `ui.lua` opts or via autocmd) and document. Verify: stress words checks pass.
**C-3** blink documentation delay. Raise `documentation.auto_show_delay_ms` from 300 to 500. Verify: completion still shows docs; no test asserts the exact value.

### Phase D — Large-file coverage (biggest robustness win)
**D-1** Centralize large-file predicate. Add `M.is_large(bufnr)` to `config/health.lua` (or a new `config/large_file.lua`) returning `vim.b[bufnr].large_file_mode` or size check; reuse everywhere instead of ad-hoc. Verify: unit test for the predicate.
**D-2** render-markdown guard. In `appearance.lua`, add `cond`/ft gate so it does not attach above 200 KB (or returns early in config). Verify: stress render-markdown checks pass.
**D-3** snacks indent guard. Disable indent + scope above 200 KB via autocmd or opts; document. Verify: stress snacks checks pass.
**D-4** gitsigns guard. In `visual.lua`, make gitsigns skip attach above 1 MiB (use `cond` or BufReadPre early return). Verify: gitsigns stress checks pass.
**D-5** nvim-lint guard. In `ui.lua`, make `try_lint` no-op when `large_file_mode`. Verify: lint stress checks pass.
**D-6** todo-comments guard. Add size guard in config or ft autocmd.
**D-7** aerial guard. Disable above 1 MiB.
**D-8** mini.ai `n_lines`. Reduce 500 → 250 in `editing.lua`. Verify: textobject tests pass.
**D-9** treesitter/colorizer threshold alignment. Either lower large_file_size to 200 KB for consistency or document the two-tier (200 KB for TS/colorizer, 1 MiB for everything else). Prefer documenting the two-tier; do not change thresholds without measurement.

### Phase E — LSP / tooling
**E-1** vtsls memory experiment. Temporarily set `maxTsServerMemory = 1536` on a large TS repo and measure peak RSS + completion latency; revert if regression. Verify: manual; document result.
**E-2** lua_ls library scope. Keep current conditional; add a comment that the runtime library is only added for the config dir. (No code change unless profiling shows it dominates.)
**E-3** Mason ensure_installed audit. Remove any tool not actually used (check `formatters_by_ft`, `linters_by_ft`, LSP servers). Verify: `:checkhealth config` still green for used tools.

### Phase F — Optional upgrades (network-dependent)
**F-1** blink rust fuzzy. If `blink.cmp`'s prebuilt fuzzy binary is fetchable, switch `fuzzy.implementation` to `'prefer_rust'` with a fallback to `'lua'`; keep `'lua'` as default when offline. Verify: completion ranking tests pass; stress passes.
**F-2** blink documentation delay already in C-3.

### Phase G — Verification & lock-in
**G-1** Add a stress check: large file (2 MiB) sets `b:large_file_mode` and skips formatter/lint/treesitter/colorizer.
**G-2** Add a stress check: no duplicate CursorHold handlers after `<leader>ur`.
**G-3** Re-run full suite + stress; confirm 0 FAIL.
**G-4** Update `README.md`/`CHEATSHEET.md` startup claims if any number changed (D-1 from 2026-10-29 plan).

---

## 4. Execution order

| # | Task | Why first |
|---|---|---|
| 1 | A-1..A-3 (measure) | Honest baseline before edits |
| 2 | B-3, B-4 (idle throttle + updatetime) | Low-risk, immediate idle CPU win |
| 3 | C-1 (documentHighlight opt-in) | Biggest idle LSP win |
| 4 | D-1..D-9 (large-file guards) | Robustness, prevents stalls |
| 5 | B-1, B-2 (redraw caches) | Typing smoothness |
| 6 | C-2, C-3, E-1..E-3 (gating + audits) | Polish |
| 7 | F-1 (optional rust fuzzy) | Network-dependent, last |
| 8 | G-1..G-4 (verify + docs) | Lock in |

Each step ends with: plenary green, stress green, `stylua --check .` clean, headless boot silent.

---

## 5. Risks and open questions

- **Measured numbers are host-specific** (trap from 2026-10-29 plan). Do not overfit thresholds to this machine.
- **documentHighlight default-off** changes visible behavior (no reference highlight at rest). Mitigation: toggle `<leader>uH` + document in CHEATSHEET; keep opt-in easy.
- **Large-file guards** must not break the features' manual triggers (e.g. `<leader>ff` still formats, `:ColorizerToggle` still works). Guard only auto-attach/auto-run paths.
- **Redraw caches** risk staleness if invalidation is wrong; invalidate conservatively (on the events that already drive the cache).
- **updatetime raise** affects CursorHold-driven features (documentHighlight, diagnostic float, checktime). Measure before committing.
- **rust fuzzy** requires network on first use; keep lua fallback.

---

## 6. What this plan intentionally does not change

- Leader key, core keymap groups, Python LSP ladder, provider disables.
- `format_on_save` synchronicity (Trap 11).
- Custom dashboard (vs snacks.dashboard).
- treesitter main-branch pin and CLI requirement.
- `lazy-lock.json` policy (gitignored by design).
- Startup micro-optimization beyond measured hot spots (already under 400 ms gate).
