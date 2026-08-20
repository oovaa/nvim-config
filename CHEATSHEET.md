# Neovim Configuration Cheat Sheet

This repository is based on `kickstart.nvim`, customized with several plugins to provide a familiar, VS Code-like experience.

**Leader Key:** `<Space>`

## 🐍 Python Development

| Tool | Purpose |
| :--- | :--- |
| `pyrefly` | LSP (autocomplete, type checking, goto definition, etc.) |
| `ruff` | Linting + formatting (replaces flake8, isort, black) |
| Treesitter | Syntax highlighting for Python |

- **Autoformat on save** is enabled for Python (ruff).
- LSP and formatters are auto-installed via Mason (pyrefly is installed globally via brew).
- Works with virtualenvs automatically.

## 🚀 Session Management

- Sessions are saved/restored automatically via `auto-session.nvim` (excluded in `~/`, `~/Downloads`, `/etc`).
- Switch projects with `<leader>sp`.

## 🗂️ UI & File Navigation

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>e` | Toggle Floating File Explorer | `neo-tree.nvim` |
| `<leader>ty` | Switch Theme (Telescope colorscheme, choice persisted across restarts) | config |
| `t` | Open file in new tab (in neo-tree) | `neo-tree.nvim` |
| `<C-t>` | Open file in new tab (in Telescope) | `telescope.nvim` |
| `<leader>tt` | Toggle bottom terminal | `toggleterm.nvim` |
| `<leader>tf` | Toggle floating terminal | `toggleterm.nvim` |
| `<leader>tm` | Toggle floating terminal with tmux (multi-tab) | `toggleterm.nvim` |
| `<leader>ht` | Toggle floating Herdr terminal | `toggleterm.nvim` |
| `<C-\>` | Toggle Terminal (Any mode) | `toggleterm.nvim` |
| `<leader>tn` | New terminal window | `toggleterm.nvim` |
| `<leader>t1/2/3`| Switch to Terminal 1, 2, or 3 | `toggleterm.nvim` |
| `<S-h>` | Previous Tab / Buffer | `bufferline.nvim` |
| `<S-l>` | Next Tab / Buffer | `bufferline.nvim` |
| `<leader>bd` | Delete Current Buffer | `bufferline.nvim` |
| `s` | Fast Jump (Flash) | `flash.nvim` |
| `S` | Fast Jump Treesitter Mode | `flash.nvim` |
| `<C-h/j/k/l>` | Switch focus between windows (editor, terminal, explorer) | built-in |

### 🗂️ neo-tree (Floating Explorer) Tricks

Press `<leader>e` to toggle the floating file explorer. Inside it:

| Key | Action |
| :--- | :--- |
| `?` | Show neo-tree help |
| `<CR>` / `o` | Open file (or expand/collapse folder) |
| `h` / `l` | Collapse / expand folder |
| `<C-v>` | Open file in vertical split |
| `s` | Open file in horizontal split |
| `t` | Open file in new tab |
| `a` | Create file/folder |
| `d` | Delete file/folder |
| `r` | Rename |
| `R` | Refresh tree |
| `x` / `y` / `p` | Cut / copy / paste |
| `q` | Close the explorer |

## 🔍 Searching (Telescope)

| Keybinding | Action |
| :--- | :--- |
| `<leader>sf` | Search Files |
| `<leader>sp` | Search Projects (Switch project) |
| `<leader>sg` | Search by Grep (Search across entire codebase) |
| `<leader>sw` | Grep word under cursor |
| `<leader>s/` | Grep in currently open files |
| `<leader>sh` | Search Help tags |
| `<leader>sk` | Search Keymaps |
| `<leader>sd` | Search Diagnostics |
| `<leader>sr` | Search Resume (resume last search) |
| `<leader>s.` | Search Recent Files |
| `<leader>sc` | Search Commands |
| `<leader>ls` | List functions/symbols in current file (Telescope, needs LSP) |
| `<leader>lS` | List symbols in workspace (Telescope, needs LSP) |
| `<leader>sn` | Search Neovim config files |
| `<leader>s/` | Search in Open Files |
| `<leader>fr` | Search & replace (VS Code style) | `nvim-spectre` |
| `<leader><space>` | Search Existing Buffers |
| `<leader>/` | Fuzzily search in current buffer |

**Telescope picker shortcuts (inside the picker):**

| Key | Action |
| :--- | :--- |
| `<CR>` | Open in current window |
| `<C-x>` | Open in horizontal split |
| `<C-v>` | Open in vertical split |
| `<C-t>` | Open in new tab |

## 💻 Code & Editing

| Keybinding / Command | Action | Plugin/Feature |
| :--- | :--- | :--- |
| `:e <file>` | Open / create a file | built-in |
| `:wa` | Save all files | built-in |
| `:%s/old/new/g` | Find & replace all in file | built-in |
| `:%s/old/new/gc` | Find & replace with confirmation | built-in |
| `:%s/old/new/gi` | Find & replace (case-insensitive) | built-in |
| `<Tab>` | Accept Autocompletion Suggestion | `blink.cmp` |
| `<S-Tab>` | Previous Autocompletion Suggestion | `blink.cmp` |
| `<C-space>` | Force show completion docs | `blink.cmp` |
| `<C-BS>` | Delete previous word | built-in |
| `<leader>q` | Open diagnostic quickfix list | built-in |
| `<leader>uc` | Toggle colorizer (inline color previews) | `colorizer` |
| `<leader>mt` | Toggle bookmark on current line | `vim-bookmarks` |
| `<leader>mc` | Annotate bookmark | `vim-bookmarks` |
| `<leader>mj` | Jump to next bookmark | `vim-bookmarks` |
| `<leader>mk` | Jump to previous bookmark | `vim-bookmarks` |
| `<leader>mb` | List all bookmarks | `telescope-vim-bookmarks` |
| `<leader>f` | Format buffer | `conform.nvim` |
| `<leader>fe` | File browser (Telescope) | `telescope-file-browser` |
| `<leader>fE` | File browser in current dir | `telescope-file-browser` |
| `:StartupTime` | Profile Neovim startup and list the 15 slowest sources | config |

## 🌿 Git Integration

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>fg` | Open LazyGit (floating window) | `lazygit.nvim` |
| `[c` | Previous Hunk | `gitsigns` |
| `]c` | Next Hunk | `gitsigns` |
| `<leader>hs` | Stage Hunk | `gitsigns` |
| `<leader>hr` | Reset Hunk | `gitsigns` |
| `<leader>hp` | Preview Hunk | `gitsigns` |
| `<leader>hb` | Blame Line | `gitsigns` |

## 🧠 LSP (Language Server Protocol)

| Keybinding | Action |
| :--- | :--- |
| `K` | Hover (show function signature, args, return type, docs) |
| `grd` | Go to Definition |
| `grr` | Go to References |
| `gri` | Go to Implementation |
| `grt` | Go to Type Definition |
| `grD` | Go to Declaration |
| `gra` | Goto Code Action |
| `grn` | Rename symbol |
| `gO` | Open Document Symbols |
| `gW` | Open Workspace Symbols |
| `<leader>th` | Toggle Inlay Hints |

## ✂️ Text Objects & Surround (`mini.nvim`)

* **`mini.ai`**: Enhanced text objects (e.g., `va)` to visually select around parens, `ci'` to change inside quotes).
* **`mini.surround`**:
    * `gsaiw)` - **S**urround **A**dd **I**nner **W**ord **)** Paren
    * `gsd'` - **S**urround **D**elete **'** quotes
    * `gsr)'` - **S**urround **R**eplace **)** with **'**
    * Visual mode: select text, then `gsa` + character to surround

## 🎬 Macros

| Keybinding | Action |
| :--- | :--- |
| `q{letter}` | Start recording macro to register (e.g. `qa`) |
| `q` | Stop recording |
| `@{letter}` | Play macro from register (e.g. `@a`) |
| `@@` | Repeat last played macro |
| `{count}@{letter}` | Play macro N times (e.g. `10@a`) |

## 🐛 Python Debugging (DAP)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>db` | Toggle Breakpoint | `nvim-dap` |
| `<leader>dc` | Continue / Start Debugging | `nvim-dap` |
| `<leader>di` | Step Into | `nvim-dap` |
| `<leader>do` | Step Over | `nvim-dap` |
| `<leader>dO` | Step Out | `nvim-dap` |
| `<leader>dr` | Toggle REPL | `nvim-dap` |
| `<leader>dl` | Run Last | `nvim-dap` |
| `<leader>dt` | Terminate Debugging | `nvim-dap` |
| `<leader>dn` | Debug Nearest Test (pytest) | `nvim-dap-python` |
| `<leader>df` | Debug Test File | `nvim-dap-python` |
| `<leader>ds` | Debug Selection (visual mode) | `nvim-dap-python` |

## 📓 Jupyter Notebooks (Molten)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>mi` | Initialize Jupyter Kernel | `molten-nvim` |
| `<leader>ml` | Evaluate Current Line | `molten-nvim` |
| `<leader>mv` | Evaluate Visual Selection | `molten-nvim` |
| `<leader>mr` | Re-evaluate Cell | `molten-nvim` |
| `<leader>mh` | Hide Output | `molten-nvim` |
| `<leader>md` | Delete Cell Output | `molten-nvim` |
| `<leader>mn` | Next Cell | `molten-nvim` |
| `<leader>mp` | Previous Cell | `molten-nvim` |
| `<leader>mo` | Open in Browser | `molten-nvim` |

## 📝 Markdown Preview

`render-markdown.nvim` renders Markdown directly in the buffer — no keybinding needed, it just works when you open a `.md` file. Headings, bold, code blocks, etc. are displayed with proper formatting and colors.

## 🐚 Terminal Navigation

When inside the terminal:
* `<Esc>` or `jk`: Exit terminal mode (return to normal mode).
* `<C-h/j/k/l>`: Switch directly to another window from terminal mode.

---
*Generated based on your `init.lua` settings.*
