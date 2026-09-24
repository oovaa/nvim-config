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
| `<leader>e` | Toggle File Explorer | `snacks.nvim` |
| `<leader>ty` | Switch Theme (snacks colorschemes picker; boot default tokyonight-night) | snacks.nvim |
| `t` | Open file in new tab (in explorer) | `snacks.nvim` |
| `<C-t>` | Open file in new tab (in picker) | `snacks.nvim` |
| `<leader>tt` | Toggle bottom terminal | built-in |
| `<leader>tf` | Toggle floating terminal | built-in |
| `<leader>tm` | Toggle floating terminal with tmux (multi-tab) | built-in |
| `<leader>ht` | Toggle floating Herdr terminal | built-in |
| `<C-\>` | Toggle Terminal (Any mode) | `toggleterm.nvim` |
| `<leader>tn` | New terminal window | `toggleterm.nvim` |
| `<leader>t1/2/3`| Switch to Terminal 1, 2, or 3 | `toggleterm.nvim` |
| `<S-h>` | Previous Buffer | built-in |
| `<S-l>` | Next Buffer | built-in |
| `<leader>bd` | Delete Current Buffer | built-in |
| `s` | Fast Jump (Flash) | `flash.nvim` |
| `S` | Fast Jump Treesitter Mode | `flash.nvim` |
| `<C-h/j/k/l>` | Switch focus between windows (editor, terminal, explorer) | built-in |

### 🗂️ Explorer Tricks

Press `<leader>e` to toggle the file explorer (`:Neotree` fallback). Inside it:

| Key | Action |
| :--- | :--- |
| `?` | Show explorer help |
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

## 🔍 Searching (snacks picker)

| Keybinding | Action |
| :--- | :--- |
| `<leader>sf` | Search Files (also `<leader><leader>`) |
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
| `<leader>ls` | List functions/symbols in current file (picker, needs LSP) |
| `<leader>lS` | List symbols in workspace (picker, needs LSP) |
| `<leader>sn` | Search Neovim config files |
| `<leader>st` | Search todo comments |
| `<leader>/` | Fuzzily search in current buffer |

**Picker shortcuts (inside the picker):**

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
| `<leader>ff` | Format buffer | `conform.nvim` |
| `<leader>fe` | File explorer | `snacks.nvim` |
| `<leader>fE` | File explorer (reveal current file) | `snacks.nvim` |
| `:StartupTime` | Profile startup (native timing + lazy.nvim plugin stats) | config |

### 💬 Messages & Notifications (snacks notifier)

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>n` | Notification history | `snacks.nvim` |
| `<leader>un` | Dismiss all notifications | `snacks.nvim` |
| `:messages` | Raw message history | built-in |

## 🌿 Git Integration

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>fg` | Open LazyGit (floating window) | `lazygit.nvim` |
| `[c` | Previous Hunk | `gitsigns` |
| `]c` | Next Hunk | `gitsigns` |

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

## 📝 Markdown

`render-markdown.nvim` renders Markdown directly in the buffer — no keybinding needed, it just works when you open a `.md` file. Headings, bold, code blocks, etc. are displayed with proper formatting and colors.

## ✨ QoL Plugins

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>gb` | Toggle inline git blame | `blame.nvim` |
| `<leader>rr` | Refactoring menu (normal + visual) | `refactoring.nvim` |
| `<leader>tr` / `<leader>ts` / `<leader>to` | Run test / summary / output panel | `neotest` |
| `<leader>hr` | Send HTTP request (in `.http` files) | `rest.nvim` |
| `<leader>o` | Toggle outline sidebar | `aerial.nvim` |
| `<leader>fr` | Project find & replace | `grug-far.nvim` |

`snacks.nvim` (`vim.ui.input`) and `nvim-bqf` (quickfix preview) have no keybindings — they improve existing UI automatically.

### 🔁 grug-far (project find & replace)

Press `<leader>fr`, fill the fields, matches preview live below:

| Key | Action |
| :--- | :--- |
| `<localleader>s` | Apply replacement to all matches |
| `<localleader>l` | Apply replacement to matches on current line only |
| `<localleader>c` | Close the panel |
| `<localleader>t` | Browse/reuse search history |

Limit scope with the files filter (e.g. `*.py`); `<CR>` on a match jumps to it.

## 🐚 Terminal Navigation

When inside the terminal:
* `<Esc>` or `jk`: Exit terminal mode (return to normal mode).
* `<C-h/j/k/l>`: Switch directly to another window from terminal mode.

---
*Generated based on your `init.lua` settings.*
