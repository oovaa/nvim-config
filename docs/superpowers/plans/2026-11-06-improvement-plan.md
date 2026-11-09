# Neovim Config — Full-Scope Improvement Plan (2026-11-06)

**Date:** 2026-11-06 · **Branch:** master · **Host:** nvim 0.12.6, brew python 3.15, stylua 2.5.2
**Input:** 2026-11-03 perf plan (already shipped: commits `b6cd7f0` + `e482ae8`), full health probe, JS/TS/Python/Lua audit, Rust/Go/Java/misc audit.

## 0. What is true today (measured, read-only)

**Health:** nvim 0.12.6 OK, `large_file_size` OK, core PATH OK (`git/rg/node/bun/python3/make/fd/lazygit/pyrefly/vtsls/biome/nginx-language-server/jupyter/tree-sitter/prettier/stylua/ruff`), clipboard OK, blink Rust fuzzy `.so` present, all 64 plugins on disk OK (lazy-lock.json).
**FAIL:** Python imports missing — `debugpy`, `jupyter_client`, `ipykernel`; `docker`, `ty` not on PATH.
**WARN:** `nginxfmt`, `oxlint` mason-only (not on PATH); `jupytext`, `ueberzugpp` missing; `jdtls`/`rust-analyzer`/`clangd` mason packages missing.
**Root cause:** brew python 3.15 has no `ensurepip` (dormant), so mason cannot install any Python package (`debugpy`, `nginxfmt`, `jupytext`, `ipykernel` deps). Affects formatting (nginx), lint, DAP, and molten — read-only probe confirms the binaries are simply absent.

**Language gaps found:**
- JS/TS: only `vtsls`; `maxTsServerMemory = 1536` (lowered in the 2026-11-09 audit; was 2048); biome only where repo has `biome.json` (correct, `$HOME` excluded); React/HTML/CSS = 2 servers/buffer (`vtsls`+`emmet`/`cssls`+`emmet` — emmet is lightweight, acceptable).
- Vue: **no LSP, no linter, no treesitter parser in bootstrap** — biggest functional gap.
- Python: ladder `ty→pyrefly→pyright` (`config/python_lsp.lua` correct), but `lsp.lua` can double-attach when both `ty` and `pyrefly` are installed; `ruff` runs twice per save (conform `ruff_organize_imports`+`ruff_format` + lint `ruff`).
- Lua: `lua_ls` only (correct); `on_init` adds full runtime library outside own config dir → slow, noisy.
- Rust: `rust-analyzer` via rustup (correct choice, not mason) + clippy-on-save + `allFeatures` = slowest possible; binaries missing on this host.
- Go: `gopls` heavy (staticcheck + gofumpt + 6 analyses); binaries missing.
- Java: `jdtls` needs JDK 21; binaries missing.
- YAML: no generic `yamlls`.
- Parsers: `dockerfile`, `nginx`, `markdown_inline` not in bootstrap list.
- Perf/robustness: LSP attaches on >1 MiB files; DAP `debugpy` path claim dangling (absent).

**Already good / do not touch:** `updatetime 350`, `documentHighlight` opt-in + `<leader>uH`, diag-float throttle, large-file guards (snacks/gitsigns/lint/render-markdown), `mini.ai 250`, statusline/tabline caches, `health.is_large()`, blink `prefer_rust` + 300ms docs, treesitter `main` pin, python ladder order, biome rule.

---

## Phase 0 — Environment fixes (install missing tools, no code change)

**0-1.** Install Python deps via `uv` (works without `ensurepip`):
```bash
uv tool install debugpy --from debugpy
uv pip install --system --break-system-packages debugpy jupyter_client ipykernel jupytext
uv tool install jupytext
python3 -c "import debugpy, jupyter_client, ipykernel"  # verify
uv tool run nginx-config-formatter  # or: uv tool install nginx-config-formatter
```
Unblocks: DAP (`<leader>dc`), molten, `<leader>dc` health row.
**0-2.** `brew install docker` (or accept WARN; `dockerls`/`compose` LSP stay dormant without it). Optional `ty`: `brew install ty` or `uv tool install ty` — only needed if you want the fastest Python LSP.
**0-3.** `uv tool install nginx-config-formatter` → `nginxfmt` on PATH; then set `nginx = true` in `formatting.lua:129`.
**0-4.** Shell: add mason bin to PATH (so mason-only tools resolve):
```zsh
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
```
Unblocks: `oxlint`, `nginxfmt`, `prettier`, `stylua`, `ruff` when launched from GUI/terminal without mason PATH prepend.
**0-5.** `brew install ueberzugpp` for image backend (else kitty fallback — already OK).
**0-6.** Optional deps: `rustup component add rustfmt` + `rust-analyzer` via `rustup component add rust-analyzer` (correct source, not mason); `brew install openjdk@21` for `jdtls`; `brew install go` + `go install golang.org/x/tools/gopls@latest` if Go/Java/Rust used. Document in README if not needed.
*Verify: `:checkhealth config` — FAIL→OK on python imports; WARN counts drop.*

## Phase 1 — Bugs (small, targeted fixes)

**1-1 Python double-attach.** `lsp.lua` iterates `servers` and spawns every entry in `lsp_filetypes`. If both `ty` and `pyrefly` are registered for `python`, both attach. Fix: in the FileType autocmd, skip any python server whose `name ~= require('config.python_lsp').resolve().name`. File: `lsp.lua` (~line 330+ enable block). *Verify: `test_python_tools.lua` + manual `:LspInfo` shows exactly one python client.*
**1-2 Ruff twice per save.** nvim-lint `ruff` (lint) + conform `ruff_organize_imports` + `ruff_format` = 3 `ruff` spawns (organize+format in conform already re-run server; lint adds another). Fix: keep conform organize+format; drop `ruff` from `lint.linters_by_ft.python` and rely on `ruff` diagnostics via LSP or conform-only. Alternatively set `ruff` linter to `linters = { 'ruff' }` with `--fix` and remove conform organize step. Pick one; document choice. Files: `ui.lua` + `formatting.lua:154`. *Verify: save a bad python file — one round of diagnostics, no duplicate spawns (check `:ConformInfo` + lint log).*
**1-3 vtsls not in mason.** `vtsls` is declared lazily (see `lsp.lua` FileType) but absent from `ensure_installed` — clean machines silently lack TS LSP. Fix: add `vtsls` (or `typescript-language-server` fallback) to `ensure_installed` in `lsp.lua:286` region, or document the `bun`/`npm i -g @vtsls/language-server` path in README. *Verify: fresh `:Mason` shows vtsls present.*
**1-4 DAP path claim.** `debugpy` path in dap config claims a mason venv path that doesn't exist. Fix path to `python3 -m debugpy` (user-install from 0-1) or remove the hard-coded mason path. Files: `lua/plugins/debugging.lua` (if present). *Verify: `<leader>dc` launches debugpy.*

## Phase 2 — Large-file + LSP guards (robustness)

**2-1.** Skip LSP attach on `large_file_mode` buffers: in `lsp.lua` LspAttach/enable autocmd, `if vim.b[buf].large_file_mode then return end`. Prevents `vtsls`/`gopls`/`rust-analyzer` choking on >1 MiB files. *Verify: open 2 MiB file — no LSP clients.*
**2-2.** Document the two-tier threshold (200 KB TS, 1 MiB general) in `AGENTS.md` or `health.lua` comment — already true, just make it explicit. *Verify: `grep large_file` shows one predicate + comment.*

## Phase 3 — Language coverage gaps

**3-1 Vue.** Add `vue` parser to bootstrap list in `treesitter.lua`; add `vue-ts`/`volar`-style LSP (`vue-ts-language-server` or `vtsls` with vue plugin) in `lsp.lua` `servers` + `lsp_filetypes`; add oxlint/biome handling — oxlint does not lint `.vue` SFC templates, so either enable `eslint` (mason) for `vue` only or document as prettier-only. Files: `treesitter.lua`, `lsp.lua`, `ui.lua`, `formatting.lua`. *Verify: open `.vue` — highlighting + LSP attach.*
**3-2 YAML.** Add `yamlls` to `servers` + mason `ensure_installed` + `filetypes = { 'yaml' }`. *Verify: yaml opens with schemas.*
**3-3 Parsers.** Add `'dockerfile'`, `'nginx'`, `'markdown_inline'` to bootstrap loop in `treesitter.lua` (lines 45-69). *Verify: those fts highlight without manual `:TSInstall`.*
**3-4 Mason list audit.** `mason/bin` shows only 17 pkgs. Add missing servers (`jdtls`, `clangd` if C++ used, `yamlls`, `vue` LSP) to `ensure_installed` **only if** you use those languages; otherwise delete unused entries (`sqls`, `nginx_language_server`, etc.) to cut mason time. *Verify: `:Mason` list matches `lsp.lua` servers + formatters.*

## Phase 4 — Perf tuning (measured, low-risk)

**4-1 vtsls memory.** Lower `maxTsServerMemory 2048 → 1024` (or `1536`) in `lsp.lua`; measure RSS + completion latency on one large TS repo. Revert if lag. *Verify: `:profile` + `ps` snapshot in plan notes.*
**4-2 rust-analyzer.** Turn off clippy-on-save and `allFeatures` by default; enable per-project via `rust-analyzer.toml` (`checkOnSave = false`, `features = "minimal"`). File: `lsp.lua` rust server block. *Verify: rust file open <2s cold.*
**4-3 gopls.** Disable `staticcheck` if not used; reduce `analyses` list to `unused` + `shadow` only; keep `gofumpt`. File: `lsp.lua` gopls block. *Verify: go file open latency.*
**4-4 Lua workspace.** In `lua_ls` `on_init`, only add full runtime library when `path == stdpath('config')` or `.luarc` present; otherwise `checkThirdParty = false` + `library = {}`. File: `lsp.lua:~286`. *Verify: lua file outside config opens <100ms, no `lua_ls` workspace scan.*
**4-5 Emmet/duplicate servers.** Leave as-is (emmet is lightweight, ~10ms). If you want it lower, gate emmet to `html` only and drop `css/scss/less` (cssls already covers).

## Phase 5 — Optional / network-dependent

**5-1.** Rust fuzzy already done (`prefer_rust`). No further blink work.
**5-2.** Align thresholds (200 KB vs 1 MiB) to a single value only if you measure real pain; otherwise keep two-tier + document (Phase 2-2).
**5-3.** Add two stress checks: (a) large file sets `b:large_file_mode` and skips formatter/lint/treesitter/LSP; (b) no duplicate CursorHold after `<leader>ur`. Files: `tests/stress.lua`.

## Phase 6 — Verify + lock in

**6-1.** Run: `stylua --check .`, plenary suites (`test_performance`, `test_config_modules`, `test_startup`, `test_python_tools`, `test_lint`), full `tests/stress.lua`. Gate: 0 FAIL.
**6-2.** Update `README.md`/`CHEATSHEET.md`: new tool installs (0-1..0-5), Vue/YAML support, single-Python-LSP behavior, `maxTsServerMemory`, clippy/gopls defaults.
**6-3.** Commit per phase (Phase 0 = docs only; Phase 1 = bugs; Phase 3 = gaps; Phase 4 = tuning). Push after each phase stays green.

## Execution order

| # | Phase | Why first |
|---|---|---|
| 1 | 0-1 (python deps) | Unblocks DAP + molten; trivial |
| 2 | 1-1, 1-2, 1-3, 1-4 | Small bugs, high correctness value |
| 3 | 2-1 (LSP large-file guard) | Prevents stalls |
| 4 | 3-1..3-3 (Vue/YAML/parsers) | Biggest missing features |
| 5 | 4-1..4-4 (tuning) | Perf polish, measure first |
| 6 | 6-1..6-3 | Lock in |

## Risks / open questions

- `ty` + `pyrefly` coexistence: removing double-attach changes which server you get — `ty` wins by ladder order; make sure you want that.
- Dropping `ruff` from lint changes diagnostic UX (fewer, slower updates); measure first.
- `vtsls` memory cut can lag on very large TS monorepos — measure before committing.
- `vue` LSP (`vue-ts-language-server` / `volar`) is a new dependency (npm/bun global, not mason) — may need a manual install step like `vtsls`.
- Mason cannot install Python packages (no `ensurepip` on brew 3.15) — `uv pip install --user` is the workaround; re-test after system python upgrade.
- All thresholds are host-specific; do not overfit — measure on the machine you ship to.

## Explicitly out of scope

- Leader key, Python ladder order, provider disables, `format_on_save` sync, treesitter `main` pin, `lazy-lock.json` policy, dashboard, startup micro-opts (<400ms gate already met).
