# Neovim Configuration Cheat Sheet

This repository is based on `kickstart.nvim`, customized with many plugins for a
VS Code-like experience. **Leader key:** `<Space>`.

> Generated from the config. For the live, authoritative list use `:map` or
> `<leader>sk` (search keymaps).

---

## 🐍 Python Development

| Tool | Purpose |
| :--- | :--- |
| `pyrefly` / `ty` / `pyright` | LSP (first found on `PATH`; `:NvimCheckPythonLsp`) |
| `ruff` | Linting + formatting |
| Treesitter | Syntax highlighting |

- Autoformat on save (ruff). Works with virtualenvs automatically.
- LSP servers installed via Mason except the Python LSP (checked, not installed).

## 🚀 Session Management

- Sessions saved on quit, restored from dashboard (`s`) via builtin `:mksession`
  (suppressed in `~/`, `~/Downloads`, `/etc`, `/tmp`).
- Switch projects: `<leader>sp`. Restore last session: `<leader>sr`.

## 🗂️ UI & File Navigation

| Keybinding | Action | Plugin/Feature |
| :--- | :--- | :--- |
| `<leader>e` / `<leader>fe` | Toggle file explorer | `snacks.nvim` |
| `<leader>fE` | File explorer (reveal current file) | `snacks.nvim` |
| `t` (explorer) / `<C-t>` (picker) | Open file in new tab | `snacks.nvim` |
| `<leader>ty` | Switch theme (persisted) | `snacks.nvim` |
| `<leader>tb` | Toggle dark/light background | built-in |
| `<leader>tt` / `<leader>tf` / `<leader>tm` | Toggle terminal (bottom / float / tmux) | built-in |
| `<leader>tn` / `<leader>t1` / `<leader>t2` / `<leader>t3` | New terminal (bottom / vertical / float) | built-in |
| `<leader>t-` / `<leader>tv` | Split window, new shell below / beside | built-in |
| `<C-\>` | Toggle terminal (any mode) | built-in |
| `<S-h>` / `<S-l>` | Prev / next buffer | built-in |
| `<leader>bd` / `<leader>bp` | Delete / pin buffer | built-in |
| `<leader>uu` | Undo tree (visual history) | built-in (0.12) |
| `<leader>gD` | DiffTool (two paths) | built-in (0.12) |
| `s` / `S` | Flash jump / treesitter mode | `flash.nvim` |
| `<C-h/j/k/l>` | Switch focus between windows | built-in |
| `<leader>o` | Toggle outline sidebar | `aerial.nvim` |
| `<leader>uc` | Toggle colorizer (inline colors) | `nvim-colorizer` |
| `<leader>us` / `<leader>uH` | Toggle spell / LSP document highlight | built-in |
| `<leader>uw` | Toggle line wrap | built-in |
| `<leader>ur` | Reload config | built-in |
| `<leader>fy` | Yank file path (count = absolute) | built-in |
| `<leader>.` / `<leader>S` | Toggle scratch buffer / select scratch | `snacks.nvim` |

Notes: hybrid relative line numbers on; `virtualedit=block` (visual-block past
EOL); case-insensitive cmdline file completion (`wildignorecase`);
`clipboard=unnamedplus` (unless over SSH).

### 🗂️ Explorer Tricks

Press `<leader>e` to toggle. Inside it: `a` add, `d` delete, `r` rename, `y/p`
copy/paste, `.` toggle hidden, `t` open in tab.

## 🔍 Searching (snacks picker)

| Keybinding | Action |
| :--- | :--- |
| `<leader>sf` / `<leader><leader>` | Search files |
| `<leader>sg` | Search by grep |
| `<leader>sw` | Search current word (n/x) |
| `<leader>s.` | Search recent files |
| `<leader>sr` | Resume last search |
| `<leader>ss` | Select picker |
| `<leader>sc` | Search commands |
| `<leader>sh` | Search help |
| `<leader>sk` | Search keymaps |
| `<leader>sn` | Search Neovim config files |
| `<leader>sd` | Search diagnostics |
| `<leader>s/` | Search in open files |
| `<leader>/` | Fuzzily search in current buffer |
| `<leader>sp` | Search projects |
| `<leader>st` | Search TODO comments |
| `<leader>ls` / `<leader>lS` | LSP symbols (file / workspace) |
| `<leader>n` / `<leader>un` | Notification history / dismiss all |

## 💻 Code & Editing

| Keybinding | Action | Plugin/Feature |
| :--- | :--- | :--- |
| `<Tab>` / `<S-Tab>` | Accept / prev completion | `blink.cmp` |
| `<C-j>` / `<C-k>` | Next / prev snippet placeholder | `blink.cmp` + `luasnip` |
| `<C-space>` | Force completion docs | `blink.cmp` |
| `<C-BS>` | Delete previous word (insert) | built-in |
| `<Esc>` | Clear search highlighting | built-in |
| `vv` (visual) | Select whole line | built-in |
| `<leader>q` | Open diagnostic location list | built-in |
| `gy` / `<leader>yd` | Yank nearest / all diagnostics on line | built-in |
| `[d` / `]d` | Prev / next diagnostic (with float) | built-in |
| `<leader>ff` | Format buffer | `conform.nvim` |
| `<leader>ca` / `gra` | Code action (preview) | `actions-preview.nvim` |
| `grn` | Rename symbol (live preview) | `inc-rename.nvim` |
| `K` | Hover | LSP |
| `<C-s>` (n/i) | Signature help | LSP |
| `grr` / `grd` / `gri` / `grt` / `grD` | References / def / impl / type-def / decl | LSP |
| `gO` / `gW` | Document / workspace symbols | LSP |
| `<leader>th` | Toggle inlay hints | LSP |
| `<leader>lr` | Restart LSP servers | built-in (0.12) |
| `<leader>fr` | Project find & replace | `grug-far.nvim` |
| `<leader>rr` | Refactoring menu | `refactoring.nvim` |
| `<leader>p` | Paste image from clipboard | `img-clip.nvim` |
| `<leader>hr` | Send HTTP request (`.http` files) | `rest.nvim` |
| `<leader>R` / `<leader>rf` | Run current file | built-in |
| `:DiffOrig` | Diff buffer vs saved file | built-in |

`auto-save.nvim` writes on `InsertLeave`/`TextChanged` (debounced); `ASToggle`
toggles it. `guess-indent.nvim` detects indent on `BufReadPost`.
`ts-comments.nvim` gives treesitter-aware comment strings. `todo-comments.nvim`
highlights `TODO`/`FIXME`/`NOTE`/`WARN`.

### ✏️ Spell checking (built-in, auto-on for markdown only)

| Key | Action |
| :--- | :--- |
| `]s` / `[s` | Next / prev misspelling |
| `z=` | Suggestions (numbered list, multi-digit safe) |
| `zg` / `zw` / `zug` | Add word / mark wrong / undo |
| `<leader>us` | Toggle spell for current window |

Statusline shows `SPELL` while on. Language: `en_us`.

### 💬 Messages & Notifications (snacks notifier)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>n` | Notification history | `snacks.nvim` |
| `<leader>un` | Dismiss all notifications | `snacks.nvim` |
| `:messages` | Raw message history | built-in |

## 🗂️ File editing & diagnostics (report picks)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `-` | Edit directory as a buffer | `oil.nvim` |
| `<leader>xx` / `<leader>xX` | Diagnostics (all / buffer) | `trouble.nvim` |
| `<leader>xs` | Symbols panel | `trouble.nvim` |
| `<leader>xq` | Quickfix panel | `trouble.nvim` |
| `<C-a>` / `<C-x>` | Increment / decrement (dec/hex/date) | `dial.nvim` |
| `<leader>j` | Split / join code block | `treesj` |
| `<leader>gn` | Neogit (magit-like git UI) | `neogit` |
| `<leader>va` / `<leader>vv` | Visit add / select | `mini.visits` |
| `<leader>z` / `<leader>Z` | Zen mode / zoom | `snacks.nvim` |

## 🌿 Git Integration

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>fg` | Open LazyGit | built-in |
| `[c` / `]c` | Prev / next hunk | `gitsigns` |
| `<leader>gd` / `<leader>gp` | Diff split / preview hunk | `gitsigns` |
| `<leader>gt` | Toggle showing deleted lines | `gitsigns` |
| `<leader>gb` | Toggle inline git blame | `blame.nvim` |
| `]x` / `[x` | Next / prev merge conflict | `git-conflict` |
| `co` / `ct` / `cb` / `c0` | Take ours / theirs / both / none | `git-conflict` |

## 🌐 Live Preview & Emmet (frontend)

| Keybinding | Action |
| :--- | :--- |
| `<leader>hs` | Start live preview (serves on 127.0.0.1:8000) |
| `<leader>hx` | Stop live preview |
| `<leader>ho` | Open served page in browser |
| `<leader>ht` | Toggle live reload (CSS hot-swaps) |

- Saving any file in the served project refreshes the page; servers stop on exit.
- Commands: `:KiteHost start|stop|status|toggle-live|open|reload`.
- Emmet: type an abbreviation, accept with `<Tab>` (or `<C-y>`) to expand.

## 🧠 LSP (Language Server Protocol)

| Keybinding | Action |
| :--- | :--- |
| `K` | Hover (signature, args, return type, docs) |
| `grd` / `grr` / `gri` / `grt` / `grD` | Definition / references / impl / type-def / decl |
| `grn` | Rename symbol (live preview) |
| `gra` / `<leader>ca` | Code action |
| `gO` / `gW` | Document / workspace symbols |
| `<leader>th` | Toggle inlay hints |
| `<leader>lr` | Restart LSP servers |
| `<C-s>` | Signature help |

## ✂️ Text Objects & Surround (`mini.nvim`)

- `mini.ai`: enhanced text objects (`va)`, `ci'`, `yiiq`, …); `aa`/`ii` for next
  around/inside.
- `mini.surround`: `gsa` add, `gsd` delete, `gsr` replace, `gsf`/`gsF` find,
  `gsh` highlight, `gsn` update lines. `gss` surrounds the current line.
- `mini.pairs`: auto-pair brackets/quotes (skips inside strings).
- `mini.bracketed`: `[b`/`]b` buffers, `[q`/`]q` quickfix, `[t`/`]t` treesitter,
  `[u`/`]u` undo states.
- `mini.move` / `mini.splitjoin` / `mini.align` / `mini.operators`: `gX` exchange,
  `g=` evaluate, `gM` multiply, `cr` replace, `gS` sort.
- `mini.visits`: `<leader>va` add, `<leader>vv` select.

Treesitter textobjects (in visual/operator-pending mode): `af`/`if` function
outer/inner, `ac`/`ic` class, `aP`/`iP` parameter. Motions: `]m`/`[m` next/prev
function start, `]M`/`[M` function end, `]C`/`[C` class start, `]a`/`[a` swap
next/prev parameter. Provided by `nvim-treesitter-textobjects`;
`nvim-ts-autotag` auto-closes/renames HTML tags.

## 🎬 Macros

| Keybinding | Action |
| :--- | :--- |
| `q{letter}` | Start recording macro |
| `q` | Stop recording |
| `@{letter}` / `@@` | Play macro / repeat last |
| `{count}@{letter}` | Play macro N times |

## 🐛 Debugging (DAP)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>db` / `<leader>dB` | Toggle breakpoint / conditional | `nvim-dap` |
| `<leader>dc` / `<leader>dl` | Continue / run last | `nvim-dap` |
| `<leader>di` / `<leader>do` / `<leader>dO` | Step into / over / out | `nvim-dap` |
| `<leader>dr` | Toggle REPL | `nvim-dap` |
| `<leader>dt` | Terminate | `nvim-dap` |
| `<leader>dn` / `<leader>df` / `<leader>ds` | Debug nearest / file / selection | `nvim-dap-python` |

Supports Python, Go, C/C++, Rust, TS/React, Java (`nvim-dap-go`, `nvim-jdtls`,
`rustaceanvim`, `nvim-vtsls`).

## 📓 Jupyter Notebooks (Molten)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>mi` | Initialize kernel | `molten-nvim` |
| `<leader>ml` / `<leader>mv` / `<leader>mr` | Eval line / visual / re-eval cell | `molten-nvim` |
| `<leader>mh` / `<leader>md` | Hide output / delete cell output | `molten-nvim` |
| `<leader>mn` / `<leader>mp` | Next / prev cell | `molten-nvim` |
| `<leader>mo` | Open in browser | `molten-nvim` |

Needs Python 3 + `pynvim` + Jupyter kernel. `image.nvim` renders plots.

## 📝 Markdown

`render-markdown.nvim` renders Markdown in-buffer (headings, bold, code blocks).
No keybinding needed. In Markdown buffers lists auto-continue on `<CR>` / `o` /
`O`; pressing `<CR>` on an empty item exits the list, and numbered items
renumber automatically (supports `-`/`*`/`+` and `1.`/`1)`).

## ✨ QoL Plugins

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>gb` | Toggle inline git blame | `blame.nvim` |
| `<leader>rr` | Refactoring menu | `refactoring.nvim` |
| `<leader>tr` / `<leader>ts` / `<leader>to` | Run test / summary / output | `neotest` |
| `<leader>hr` | Send HTTP request | `rest.nvim` |
| `<leader>o` | Toggle outline sidebar | `aerial.nvim` |
| `<leader>fr` | Project find & replace | `grug-far.nvim` |
| `<leader>p` | Paste image from clipboard | `img-clip.nvim` |
| `<leader>st` | Search TODO comments | `todo-comments.nvim` |

`snacks.nvim` (`vim.ui.input`/`select`) and `nvim-bqf` (quickfix preview) improve
existing UI automatically. `which-key.nvim` shows key hints (groups: `[B]uffer`,
`[X]` Trouble, `[V]isits`).

### 🔁 grug-far (project find & replace)

Press `<leader>fr`, fill the fields, matches preview live below:

| Key | Action |
| :--- | :--- |
| `<localleader>s` | Apply replacement to all matches |
| `<localleader>l` | Apply to matches on current line only |
| `<localleader>c` | Close the panel |
| `<localleader>t` | Browse/reuse search history |

Limit scope with the files filter (e.g. `*.py`); `<CR>` on a match jumps to it.

## 🐚 Terminal Navigation

When inside the terminal: `<Esc>` or `jk` exits terminal mode; `<Esc><Esc>` also
exits; `<C-h/j/k/l>` switches directly to another window.

## 🎨 Themes

Pick via `<leader>ty` (persisted): tokyonight (default), catppuccin, cyberdream,
dracula, everforest, flexoki, github-theme, gruvbox, kanagawa, melange, nightfox,
onedark, poimandres, rose-pine, and more. Nerd Font required (`have_nerd_font=true`).

## 📊 Options & Behavior (selected)

- `number` + `relativenumber` (hybrid) on; `signcolumn=yes`.
- `ignorecase` + `smartcase`; `grepprg` uses ripgrep.
- `undofile` on; `updatetime=350`; `timeoutlen=300`.
- `breakindent`, `termguicolors`, `synmaxcol=300`.
- `lazyredraw=true`; `pumheight=10`, `pummaxwidth=80`.
- `virtualedit=block`, `wildignorecase=true`.
- Large-file mode (>1 MiB) disables treesitter/LSP/lint/format.
- Automatic: yank highlight, cursor restored on file open, spell auto-on for
  prose filetypes, idle `checktime`, parent dir created on write, cmdline
  completion menu auto-shows, which-key hints stay visible while recording macros.

## 🔧 Mason / Tooling

- Mason installs LSP servers + formatters/linters. Go-based tools (`gopls`,
  `sqls`, `gofumpt`, `goimports`, `delve`) only when `go` is on `PATH`.
- `tree-sitter` CLI is required (not via Mason) for `:TSInstall`.
- `:StartupTime` profiles startup; `:NvimCheckPythonLsp` reports Python tooling.
- `:SudoWrite` writes a root-owned buffer via `sudo tee`; `:ASToggle` toggles auto-save.

---
*Generated from the config files; regenerate after adding keymaps.*
