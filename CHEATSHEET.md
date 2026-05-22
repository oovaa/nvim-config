# Neovim Configuration Cheat Sheet

This repository is based on `kickstart.nvim`, customized with several plugins to provide a familiar, VS Code-like experience. 

**Leader Key:** `<Space>`

## 🗂️ UI & File Navigation

| Keybinding | Action | Plugin |
| :--- | :--- | :--- |
| `<leader>e` | Toggle File Explorer | `neo-tree.nvim` |
| `<S-h>` | Previous Tab / Buffer | `bufferline.nvim` |
| `<S-l>` | Next Tab / Buffer | `bufferline.nvim` |
| `<leader>bd` | Delete Current Buffer | `bufferline.nvim` |
| `s` | Fast Jump (Flash) | `flash.nvim` |
| `S` | Fast Jump Treesitter Mode | `flash.nvim` |

## 🔍 Searching (Telescope)

| Keybinding | Action |
| :--- | :--- |
| `<leader>sf` | Search Files |
| `<leader>sg` | Search by Grep (Search across files) |
| `<leader>sw` | Search current Word |
| `<leader>sh` | Search Help tags |
| `<leader>sk` | Search Keymaps |
| `<leader>sd` | Search Diagnostics |
| `<leader>sr` | Search Resume (resume last search) |
| `<leader>s.` | Search Recent Files |
| `<leader><space>` | Search Existing Buffers |
| `<leader>/` | Fuzzily search in current buffer |

## 💻 Code & Editing

| Keybinding | Action | Plugin/Feature |
| :--- | :--- | :--- |
| `<Tab>` | Accept Autocompletion Suggestion | `blink.cmp` |
| `<S-Tab>` | Previous Autocompletion Suggestion | `blink.cmp` |
| `<leader>f` | Format buffer | `conform.nvim` |
| `<leader>r` | Run Code | `code_runner.nvim` |
| `<leader>rf` | Run File | `code_runner.nvim` |

## 🧠 LSP (Language Server Protocol)

| Keybinding | Action |
| :--- | :--- |
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
    * `saiw)` - **S**urround **A**dd **I**nner **W**ord **)** Paren
    * `sd'` - **S**urround **D**elete **'** quotes
    * `sr)'` - **S**urround **R**eplace **)** with **'**

---
*Generated based on your `init.lua` settings.*