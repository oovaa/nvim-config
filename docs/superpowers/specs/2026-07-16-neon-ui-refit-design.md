# Neon UI Refit — Design Spec

**Date:** 2026-07-16
**Scope:** Visual polish pass for `~/.config/nvim` (kickstart-based, single `init.lua`).
**Direction:** Polished & Colorful
**Approach:** Option A — Lualine + Bufferline polish + custom highlights + dashboard
**Remote:** `https://github.com/oovaa/nvim-config` (remote name `oovaa`)
**Branch:** `feature/neon-ui` (created off local `master`, pushed for you to test; NOT merged without your say-so)
  (Note: earlier message used `feature-neon-ui` by mistake — canonical name is `feature/neon-ui`.)

---

## Goal

Make the editor *look* cooler without changing any muscle memory: same keybindings,
same plugins where possible, same file structure conventions. We change the visual
surface (statusline, winbar, startup screen, color saturation, scroll feel, cursor
pop) and leave behavior untouched.

---

## What We Keep (no removals)

- tokyonight-night colorscheme
- bufferline (gets a brighter config, no removal)
- neo-tree, telescope, gitsigns, which-key, hlchunk, render-markdown, lazygit, toggleterm
- All SECTION comments (WHAT/TO CHANGE/EFFECT/LOADING) — this is your house style, preserved
- Performance plan (`disabled_plugins`, VeryLazy loading, `on_key` defer)

---

## What We Add

| Plugin | Role | Load strategy | Est. cost |
|---|---|---|---|
| `nvim-lualine/lualine.nvim` | Statusline (mode/branch/file/diagnostics) | `VeryLazy` | ~5ms |
| `echasnovski/mini.starter` | Startup dashboard (ASCII banner + recent projects) | `BufReadPre *` (empty buf only) | ~3ms |
| `norcalli/nvim-colorizer.lua` | Inline hex color previews | `BufRead` | ~6ms |
| `karb94/neoscroll.nvim` | Smooth animated scroll on wheel | `VeryLazy` | ~2ms |

No extra dependencies for tokyonight accents — we extend the existing
`tokyonight.nvim` setup inline.

---

## File Layout (new module pattern, mirrors `lua/custom/plugins/`)

```
lua/custom/ui/init.lua     -> required from init.lua (wires the rest)
lua/custom/ui/theme.lua    -> tokyonight extras, winblend, colorizer config
lua/custom/ui/spec.lua     -> lualine config + bufferline tuning + winbar
```

`init.lua` calls `require('custom.ui').setup()` in SECTION 5 autocommands block.

### Existing inline edits in `init.lua`
- **SECTION 6.6 (Colorscheme, ~977–1006):** remove dead/stray block at lines
  1001–1006 (orphan `vim.cmd.colorscheme` + loose `}, end,`) and extend the
  `tokyonight.setup` with brighter `on_colors`/`on_highlights` accents.
- **SECTION 6.9 (UI Components, ~1183):** ensure bufferline opts get diagnostic
  + filetype icons through `custom.ui.spec`.
- **SECTION 6.16 (Visual Enhancements, ~1483):** add neoscroll + colorizer entries.
- **SECTION 3 (Neovim Options, ~110):** add `winhl` cursorline pop + `CursorMoved`
  autocmd for the "smooth cursor" highlight (no plugin).
- **SECTION 8 (Project Switching, ~1602):** mini.starter reads `project.nvim`
  recent projects.

---

## Component Detail

### 1. Statusline (lualine)
- Theme: `tokyonight` built-in lualine theme (matches colorscheme exactly).
- Sections:
  - left: mode, git branch, diff, diagnostics
  - center: filename + filetype icon
  - right: encoding, file format, cursor position, lsp status
- `winblend = 10` so floats feel translucent.
- Disabled on neo-tree/telescope/dashboard buffers (`disabled_filetypes`).

### 2. Winbar
- Shown only in normal buffers: filetype icon + filename + modified flag + LSP
  diagnostics count. Bufferline tabs stay at top; winbar sits just under them.

### 3. Smooth cursor
- Pure autocmd: on `CursorMoved`, set `CursorLine` highlight brighter and reset
  after `updatetime`. Avoids a heavy plugin while giving the "alive" feel.

### 4. Dashboard (mini.starter)
- ASCII banner: default to a TokyoNight-tinted "NVIM" block; swappable later.
- Recent sessions from `auto_session` directory.
- Quick links: `e` neo-tree, `ff` telescope find, `fg` lazygit.
- Only renders when launching with no file argument.

### 5. Colorizer
- Highlights `#rrggbb` and named colors in any buffer. Toggle with `<leader>uc`.

### 6. Neoscroll
- Smooth wheel + `Ctrl-u`/`Ctrl-d`/`gg`/`G`. Lines-per-scroll eased.

---

## Performance Budget

Total added startup cost < ~16ms, all deferred (VeryLazy/BufRead). No change to
`disabled_plugins`. Keeps your existing rtp discipline.

---

## Risks & Rollback

- **Dead block at 1001–1006:** currently unreachable; removing it cannot change
  runtime behavior, only removes a copy-paste trap.
- **lualine clobber:** nothing else sets `vim.opt.statusline`, so no conflict.
- **mini.starter guard:** only fires when `argc()==0` and buffer is empty — safe.
- **Rollback:** branch is isolated. `git reset --hard oovaa/master` on the branch,
  or `git revert <merge>` after merge. `:Lazy clean` removes added plugins.

---

## Out of Scope (YAGNI)

- Palette swap to catppuccin/heirline (Option B) — not chosen.
- True transparent background requiring terminal alpha (Option C) — not chosen.
- Custom completions or LSP behavior changes — untouched.
