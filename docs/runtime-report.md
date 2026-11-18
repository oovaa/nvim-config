# Runtime performance audit (multi-language monorepo)

Measured with headless harnesses against `~/GuardtowerIQ-version-2` (agent / frontend / backend node_modules, marketing Tailwind package, Python + JSON + YAML files). Focus: **editing/runtime**, not boot.

## Baseline

| Action | Cold | Warm |
|---|---|---|
| LSP attach — Lua (`lua_ls`) | 221 ms | — |
| LSP attach — TS `.ts` (`vtsls` + **tailwindcss**) | 967 ms | — |
| LSP attach — TSX (`tailwindcss` + emmet + vtsls) | 1072 ms | — |
| LSP attach — Python (`ty`) | 455 ms | — |
| LSP attach — `langgraph.json` (`jsonls`) | 2298 ms | warm 604 → 327 → 344 ms |
| LSP attach — docker-compose YAML | 765 ms | — |
| Format (conform) — TS | 1377 / 1086 / 1077 ms | — |
| Format — JSON | 1106 / 1468 / 815 ms | — |

- JSON cold 2.3 s is a one-time schema fetch; warm settles ~330 ms. No action.
- `rg --files`: 1,505 files / 76 ms with dependency excludes vs 229,782 files / 1353 ms raw. `snacks_excludes.lua` already handles node_modules/dist/build — no action.
- Large-file `TS_PARSE` 234 ms was an artifact of the harness forcing `parser:parse()`; real opens skip highlighting >200 KB via the treesitter guard. The 1 MiB `large_file_mode` threshold is intentional — left untouched.

## Issue found + fixed

**tailwindcss attached to every TS/TSX file, including packages with no Tailwind config.** `lsp_servers.lua` set `root_markers` but no `root_dir`; Neovim falls back to `root_dir = cwd` when no marker is found, so the server started in `agent/` where the only Tailwind config lives in the sibling `marketing/` package. That is wasted LSP CPU/diagnostics on every TS buffer.

Fix (`lua/config/lsp_servers.lua`): shared `tailwind_markers` table; `tailwindcss.root_dir = function(fname) return vim.fs.root(fname, tailwind_markers) end`. Returning `nil` aborts the attach when there is no Tailwind config in the file's project tree.

## After

| Action | Before | After |
|---|---|---|
| LSP attach — TS `.ts` | 967 ms (`vtsls` + tailwindcss) | **568 ms** (`vtsls` only) |
| LSP attach — TSX | tailwindcss + emmet + vtsls | emmet + vtsls (tailwindcss gone) |

Verified both directions: no tailwind attach in `agent/` TS; `root_dir()` still resolves to `.../marketing` for a marketing TSX file. Note: tailwindcss does not currently start in the marketing package either — pre-existing (`invalid "tailwindcss" config ... not executable` in `:LspLog`), confirmed identical with old and new `root_dir`. The fix removed only the spurious attach, not a working feature.

## Verification

- `stylua --check lua/config/lsp_servers.lua` clean.
- Full plenary suite: 19/19 files pass, 0 failures / 0 errors.
- Benchmark re-run: clean, attach fan-out reduced.

## Deliberately not changed

- large-file threshold (1 MiB) vs treesitter 200 KB guard — documented mismatch, intentional.
- Formatter choice: no repo-level `biome.json`, so conform uses prettier (correct; `$HOME/biome.json` intentionally ignored).
- tailwindcss server start error — pre-existing, unrelated to perf; needs separate investigation of `cmd` validation in `:LspLog`.
