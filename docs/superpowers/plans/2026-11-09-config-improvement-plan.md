# Neovim config improvement plan (2026-11-09)

Based on: completed config analysis (`ses_e3e881677`, 64 plugins, native `vim.lsp`/blink/snacks/conform+nvim-lint/main-branch treesitter/builtin UI/DAP/large-file guards) and online research subagent (`ses_e3e83a600`, 2025/2026 ecosystem). Target: **gaps + high-leverage tweaks**, not rewrites. Config: `~/.config/nvim`, nvim 0.12.6.

## Constraints (must keep)
- `stylua --check .` is CI gate (`.stylua.toml`: `call_parentheses=None`, `collapse_simple_statement=Always`, `column_width=160`). Run after any Lua change.
- `<leader>ur` reload needs named augroups with `clear=true`.
- No lockfile committed policy (if applicable) — don’t add one unless intentional.
- Mason cannot install Python packages without `ensurepip`; **do not** install `debugpy`/`jdtls` via Mason (network/403/history). `ty`, `pyrefly`, `rust-analyzer`, `nginx_language_server`, `nginxfmt` remain manual/optional per current health checks.
- `vim._core.ui2` stays **disabled** (cmdline_show invalid-window bug with this stack).
- Keep blink cmdline off (native wildmenu + `wildtrigger` chosen deliberately).
- Large-file guards must remain: skip expensive features when `vim.b[args.buf].large_file_mode` / >200KB where already guarded.
- Biome wins only in biome-configured repos (never `$HOME`) via `config.health.biome_root`.

## Phase 1 — high impact, low risk

### 1. Auto-enable inlay hints + codelens on `LspAttach`
- **File:** `lua/plugins/lsp.lua` (inside `LspAttach` callback, ~where `has` is defined).
- **Change:** if client supports `textDocument/inlayHint` and `vim.lsp.inlay_hint` exists, `vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })` (respect user toggle if you later persist state; initial enable is fine). If supports `textDocument/codeLens` and `vim.lsp.codelens` exists, enable + refresh on `BufEnter,CursorHold,InsertLeave` in a named augroup (`clear=true`, buffer-scoped where appropriate), and run initial refresh.
- **Why:** inlay hints currently only toggle (`<leader>th`); codelens never shown. Native 0.12 supports both.
- **Risk:** some servers spam codelens; guard by capability. Large-file buffers: skip when `vim.b[event.buf].large_file_mode`.
- **Verify:** open Go/Rust/TS file with capable server; hints visible; `:lua vim.lsp.codelens.refresh()` shows lenses; `stylua --check .`.

### 2. Bash + Markdown LSPs (and shfmt)
- **Files:** `lua/plugins/lsp.lua`, `lua/plugins/formatting.lua`, `lua/config/health.lua` (if tool list needs update).
- **Change:** register `bashls` (`sh`, `bash`, `zsh`) and `marksman` (`markdown`, `markdown.mdx` if desired) via `vim.lsp.config/enable` + filetype map. Add `marksman` to `ensure_installed`; `bash-language-server` already present in mason — confirm package name. Add conform: `sh = { 'shfmt' }`, `bash = { 'shfmt' }` (install `shfmt` via mason if desired; manual-only acceptable if mason issues). Keep prettier for markdown.
- **Why:** bash scripts and markdown get diagnostics/completion/hover/navigation.
- **Risk:** marksman is heavier; acceptable if used. Zsh support varies.
- **Verify:** `:LspInfo` in `.sh`/`.md`; format sh buffer.

### 3. Missing language servers (stack gaps)
- **File:** `lua/plugins/lsp.lua` (servers + filetypes + ensure_installed), `lua/plugins/formatting.lua` if formatters needed.
- **Candidates:** `taplo` (toml), `tailwindcss` (css/html/js/ts/jsx/tsx/vue/svelte/astro — **gate by root markers**: `tailwind.config.*`, `postcss.config.*`, `@tailwind`/`tailwindcss` usage patterns where practical), `svelte`, `astro`, `prismals`/`prisma-language-server`, `graphql` (`graphql`, `gql`, `typescriptreact`/`javascriptreact` only when schema config present — be conservative).
- **Mason names:** verify exact registry names before adding (`taplo`, `tailwindcss-language-server`, `svelte-language-server`, `astro-language-server`, `prisma-language-server`, `graphql-language-service-cli`).
- **Risk:** medium (node-based installs, PATH self-heal exists). Tailwind noise outside Tailwind projects — root gating is mandatory.
- **Verify:** open representative files; no attach in non-project dirs; `:checkhealth config`/`:Mason` status.

### 4. Live rename preview (`inc-rename.nvim`)
- **File:** `lua/plugins/lsp.lua` or `lua/plugins/formatting.lua` (near LSP UX) — small spec.
- **Change:** add `smjonas/inc-rename.nvim`, `cmd='IncRename'`/lazy on LspAttach; map `grn` to `:IncRename <word>` (or function wrapper) with fallback to `vim.lsp.buf.rename` when not available.
- **Risk:** very low; keep fallback.
- **Verify:** `grn` on symbol shows inline preview.

### 5. Enable more `mini.nvim` modules (already installed)
- **File:** `lua/plugins/editing.lua` (mini.nvim config).
- **Change:** add `require('mini.move').setup{}` (check Alt keymaps; remap if terminal conflicts), `require('mini.splitjoin').setup{}`, `require('mini.align').setup{}` (starts with `ga` — check collisions), `require('mini.operators').setup{}` (exchange/sort/replace/multiply — verify default prefixes don’t clash with existing maps). Do **not** add `mini.comment` (ts-comments already used).
- **Risk:** keymap collisions (`ga`, `<M-hjkl>`, `g=`/`gm` family etc.). Audit with `:verbose map`.
- **Verify:** `:checkhealth mini` if available; test move/splitjoin on sample code.

### 6. Treesitter textobjects (main branch, careful)
- **File:** `lua/plugins/treesitter.lua` (new dependency/spec) — follow **current main-branch** API, not legacy module config.
- **Change:** add `nvim-treesitter/nvim-treesitter-textobjects` (branch compatible with treesitter `main`); configure select/move/swap for `@function.*`, `@class.*`, `@parameter.*`, `@conditional.*`, `@loop.*` using its current setup style. Complements `mini.ai`.
- **Risk:** **main-branch API churn** — pin commit/tag if instability observed; test after treesitter updates.
- **Verify:** `vaf`/`daf`/`]m`/`[m`/parameter swap in TS/Lua/Python.

### 7. Neotest Go (+ optional Rust)
- **File:** `lua/custom/plugins/qol.lua` (neotest spec).
- **Change:** add `nvim-neotest/neotest-go` (or current maintained fork name — verify) and `rouge8/neotest-rust` only if Rust tests are used; wire into adapters.
- **Risk:** low; lazy on keys.
- **Verify:** `<leader>tr` in a Go test file.

## Phase 2 — medium impact

1. **Native foldtext polish** (no `nvim-ufo`): custom `foldtext` showing first line + `(N lines)` in `options.lua` or autocmd; keep treesitter foldexpr + large-file manual fallback.
2. **DAP virtual text guard:** extend large-file handling to disable `nvim-dap-virtual-text` behavior when `large_file_mode`.
3. **Signature help fallback:** insert `<C-s>` → `vim.lsp.buf.signature_help()` (blink signature already enabled).
4. **Git blame overlap:** consider removing `blame.nvim` if gitsigns blame suffices (keep if full-buffer blame view needed).
5. **Optional coverage:** `andythigpen/nvim-coverage` on demand.

## Phase 3 — only if workflow demands
- `diffview.nvim` for PR/branch review.
- AI inline completion via `vim.lsp.inline_completion` (0.12) + copilot-language-server, or `copilot.lua`/`supermaven` — evaluate separately.
- Additional neotest adapters.

## Do not do (anti-recommendations for this config)
- No telescope/fzf-lua, nvim-cmp, none-ls, lspsaga, nvim-tree, bufferline/lualine/alpha/toggleterm/auto-session, Comment.nvim, nvim-autopairs, hop/easymotion, noice, nvim-ufo (unless fold preview required), blink cmdline re-enable, Mason debugpy/jdtls, prettierd in conform chain, outline plugin overlapping aerial+snacks symbols.

## Execution order
1. Phase 1.1, 1.4, 1.5 (tiny, local). Verify `stylua` + smoke.
2. Phase 1.2, 1.3 (LSP/mason). Verify network/mason names + `:LspInfo`/`:checkhealth config`.
3. Phase 1.6, 1.7 (API-sensitive/testing). Pin if needed.
4. Phase 2 selectively.

## Verification checklist (after each batch)
```sh
cd ~/.config/nvim && stylua --check .
nvim --headless "+qa"  # smoke
# targeted tests if present:
# nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/test_config_modules.lua" -c qa
```
- `:checkhealth config`, `:LspInfo` for touched filetypes, large-file buffer still guarded.
- No new `cmdline_show`/ui2 regressions; no duplicate formatter/linter behavior; no `<leader>ur` augroup errors.

## Risks / unknowns
- Treesitter-textobjects **main-branch API churn** — validate against installed treesitter commit.
- Mason package names may differ from common docs — confirm in `:Mason`/registry before coding.
- Tailwind LSP can attach broadly — root gating required.
- Alt-key maps (`mini.move`) depend on terminal/tmux; provide fallback mappings.
- JDK/Eclipse reachability affects jdtls only (already handled separately; not part of this plan).

*Skipped: running full test suite and startup benchmarks here (planning only). Run your harness after implementation.*