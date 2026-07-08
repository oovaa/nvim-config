# Neovim Cheatsheet

## File Search (Telescope)

| Keybinding | Action |
|------------|--------|
| `<leader>sf` (Space → s → f) | Fuzzy find files in project recursively |
| `<leader>fe` | File explorer (browse files in tree) |
| `<leader>fE` | File explorer (from current file's dir) |
| `<leader>sg` | Live grep (search text in all files) |
| `<leader>sw` | Search word under cursor |
| `<leader><leader>` | Switch between open buffers |
| `<leader>s.` | Search recent files |
| `<leader>/` | Fuzzy find in current buffer |
| `<leader>s/` | Grep in open files only |

## File Explorer

| Keybinding | Action |
|------------|--------|
| `<leader>e` | Toggle Neo-tree file explorer |

## Navigation

| Keybinding | Action |
|------------|--------|
| `<C-h/j/k/l>` | Switch between split windows |
| `<S-h>` / `<S-l>` | Previous / Next buffer |
| `s` | Flash jump (fast motion) |
| `S` | Flash treesitter |

## LSP

| Keybinding | Action |
|------------|--------|
| `K` | Hover (show docs, signature, args) |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grd` | Go to definition |
| `grr` | References |
| `gri` | Implementation |

## Git (Neogit)

| Keybinding | Action |
|------------|--------|
| `<leader>gs` | Git status |
| `<leader>gc` | Git commit |
| `<leader>gp` | Git push |

## Run Code

| Keybinding | Action |
|------------|--------|
| `<leader>r` | Run code |
| `<leader>rf` | Run file |

## Commenting

| Keybinding | Action |
|------------|--------|
| `gcc` | Toggle comment of current line |
| `gc{motion}` | Toggle comment of a motion (e.g. `gcap` for paragraph) |
| `gc` (visual) | Toggle comment of selected lines |
| `:10,20gcc` | Comment lines 10 through 20 (any range) |

## Other

| Keybinding | Action |
|------------|--------|
| `<leader>f` | Format buffer |
| `<leader>tt` | Toggle terminal |
| `<C-\>` | Open terminal (toggleterm) |
| `<C-r>` | Open recent projects |
| `<leader>ty` | Switch theme (persisted across restarts) |
| `:StartupTime` | Profile Neovim startup time |
