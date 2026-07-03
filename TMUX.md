# Tmux Cheat Sheet

Used inside Neovim's floating terminal via `<leader>tm`.

## Sessions

| Command | Action |
| :--- | :--- |
| `tmux new -s name` | New session |
| `tmux attach -t name` | Attach to session |
| `tmux ls` | List sessions |
| `Ctrl+b d` | Detach from session |

## Tabs (Windows)

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+b c` | New tab |
| `Ctrl+b ,` | Rename tab |
| `Ctrl+b p` | Previous tab |
| `Ctrl+b n` | Next tab |
| `Ctrl+b w` | List all tabs |
| `Ctrl+b &` | Close tab |
| `Ctrl+b 0-9` | Go to tab 0-9 |

## Panes (Splits)

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+b %` | Vertical split |
| `Ctrl+b "` | Horizontal split |
| `Ctrl+b o` | Next pane |
| `Ctrl+b x` | Close pane |
| `Ctrl+b arrows` | Resize pane |

## Copy Mode

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+b [` | Enter copy mode |
| `v` | Start selection |
| `y` | Copy selection |
| `Ctrl+b ]` | Paste |

## Misc

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+b ?` | List all keybindings |
| `Ctrl+b :` | Enter tmux command |
