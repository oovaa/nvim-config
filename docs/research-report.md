# Research report — taking this Neovim config further

Sources: r/neovim monthly config-review threads, r/neovim "show off your statusline", dotfyle trending, "best Neovim plugins 2026" (devresources, nvimcolors, howtogeek), LazyVim extras, awesome-neovim. Cross-checked against this repo's plugin list and `AGENTS.md` traps.

## Where this config already is strong

- 0.12-native builtin UI (statusline/tabline/dashboard) instead of lualine/bufferline/alpha — ahead of most.
- blink.cmp, conform, nvim-lint, mason, snacks picker+explorer, flash, render-markdown, mini.* suite, treesitter, dap, molten/image, gitsigns, grug-far, aerial, bqf, inc-rename, todo-comments, rustaceanvim, vtsls, python ladder.
- Performance discipline: ~150-190ms startup, large-file guards, FileType-gated LSP, headless-tested.
- CI: stylua + plenary + stress harness.

This is already top-decile. Gaps below are additive, not foundational.

## High-value additions (recommended)

### 1. AI assistant — avante.nvim or codecompanion.nvim
Trending heavily (avante 18k stars, codecompanion 6.9k). You review a lot of AI-generated code; an in-editor chat/edit loop (Cursor-style inline diffs) fits. codecompanion is lighter and provider-agnostic; avante is more Cursor-like. Add as `lua/plugins/ai.lua`, gate behind env var for API key, lazy on `<leader>a`.

### 2. oil.nvim — buffer-native file ops
Trending (6.9k stars). Complements snacks explorer: rename/move/delete by editing text. Low risk, pairs with snacks. Add to `editing.lua` or new `files.lua`.

### 3. trouble.nvim — diagnostics/quickfix UI
Prettier diagnostics than the snacks picker list. Use for `<leader>xx` (workspace diagnostics) and `<leader>xq` (quickfix). Still maintained (last commit Oct 2025).

### 4. snacks.terminal + snacks.zen
You already depend on snacks but don't enable `terminal` or `zen`. Enabling `terminal = { enabled = true }` gives a managed terminal (replaces ad-hoc `<leader>tm` tmux float); `zen` gives distraction-free writing (useful for markdown/notes).

### 5. Neogit (magit-style git UI)
You have LazyGit (`<leader>fg`). Neogit adds in-buffer staging/hunk review that's faster for small commits. Optional alongside, not replacing.

### 6. harpoon2 (or mini.visits) — pinned files per project
Fast switching between 4-6 "hot" files. Harpoon2 is the standard; mini.visits is lighter and already in the mini family. Strong fit for your multi-language work.

### 7. dial.nvim — semantic increment/decrement
Numbers, dates, booleans, hex. Small, high daily value. Add to editing.lua.

### 8. treesj — split/join code blocks
Collapse/expand arrays/objects/functions. Pairs with treesitter. Low cost.

### 9. undotree (or mini.diff) — undo timeline
You have persistent undo (`undofile = true`) but no visual timeline. `mbbill/undotree` or `mini.diff` (diff hunks). Add `<leader>u` toggle.

### 10. snacks.image for non-molten previews
You already use image.nvim for molten. snacks.image can preview images in markdown/docs without a kernel. Enable if you view images often.

## Medium-value / situational

- **vim-tmux-navigator**: only if you run nvim inside tmux daily (you have terminal.lua tmux float). Your `<C-h/j/k/l>` window nav already works in terminal mode.
- **markdown-oxide LSP**: you use marksman; markdown-oxide adds backlinks/rename like Obsidian. Swap if you want Obsidian-style vault features (see linkarzu's video).
- **mini.diff**: per-hunk accept/reject in buffer; complements gitsigns.
- **grug-far** already present — good.
- **aerial** present — good.
- **inc-rename** present — good.

## What to skip (and why)

- **diffview.nvim** — stale (last commit June 2024). Use snacks.diff or mini.diff.
- **packer.nvim / nvim-cmp / telescope** — you've already migrated to lazy/blink/snacks; don't regress.
- **markdown-preview.nvim** — stale; render-markdown.nvim (you have it) is the 2026 standard.
- **vim-startify / alpha-nvim** — you have a builtin dashboard; no need.
- **noice.nvim** — you deliberately disabled ui2; noice is heavy and its author is quiet. Keep builtin cmdline.
- **Migrating lazy.nvim → vim.pack** — optional. vim.pack is built-in in 0.12 and simpler, but you'd lose lazy loading ergonomics and the plugin ecosystem assumes lazy. Only worth it if you want a "tiny config" aesthetic. Your config is large; stay on lazy.
- **Copilot/Codeium inline completion** — blink.cmp + LSP is already strong; add only if you want ghost-text AI. Consider codecompanion instead (chat + edits, not just completion).

## Suggested order of attack

1. oil.nvim + dial.nvim + treesj (low risk, high daily value, ~1 hour).
2. trouble.nvim + harpoon2/mini.visits (navigation/diagnostics).
3. snacks.terminal + snacks.zen (config-only, no new deps).
4. AI plugin (avante or codecompanion) — biggest workflow change; do last.
5. Neogit + undotree if git/undo friction shows up.

## Notes on your existing traps

- Keep `biome_root` rejection of `$HOME` (trap 12) — tests guard it.
- Go tools stay gated behind `go` (recent fix) — don't re-add unconditionally.
- Python mason packages stay excluded (trap 4).
- Don't lower the 2000ms format_on_save timeout (trap 5).

## Quick wins you can do today (config-only)

- Enable `terminal = { enabled = true }` and `zen = { enabled = true }` in snacks opts.
- Add `<leader>z` for zen, `<leader>tt` for terminal toggle.
- Bind `vim.keymap.set('n', '-', '<CMD>Oil<CR>')` if you add oil.nvim (netrw-style).
- Add `mini.visits` tracking + `<leader>fv` for recent/visited files.

---
Generated 2026-11-18. Re-run research when the ecosystem shifts (check dotfyle trending + awesome-neovim).
