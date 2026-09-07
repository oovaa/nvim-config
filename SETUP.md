# SETUP

Operational guide for this config. Full background lives in `README.md`;
every keybinding lives in `CHEATSHEET.md`.

## Bootstrap

```sh
git clone https://github.com/oovaa/nvim-config.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
nvim  # lazy.nvim installs all plugins on first launch
```

Then inside Neovim:

```
:checkhealth config.health   # verify external tools
:Mason                       # confirm LSPs/linters installed
```

## Dependencies

Checked by `:checkhealth config.health`. Install what's missing:

| Tool | Why | Install |
| :--- | :--- | :--- |
| `git` | plugins, blame, lazy updates | OS package manager |
| `rg` | Telescope grep, grug-far | `brew install ripgrep` |
| `bun` | JS/TS runs, vtsls install | `curl -fsSL https://bun.sh/install \| bash` |
| `node` | LSP servers | `brew install node` |
| `python3` + `pynvim` | molten, neotest-python | `pip install pynvim jupyter ipykernel` |
| `make`, `cmake`, C compiler | telescope-fzf-native build | OS package manager |
| `@vtsls/language-server` | TypeScript LSP (not via Mason) | `bun add -g @vtsls/language-server` |
| `pyrefly` | Python LSP (not via Mason) | `brew install pyrefly` |

Nerd Font required (`vim.g.have_nerd_font = true`); kitty terminal for image rendering.

## Daily keys

Leader is `<Space>`. Essentials:

| Key | Action |
| :--- | :--- |
| `<leader>sf` / `<leader>sg` / `<leader><leader>` | Find files / grep / buffers |
| `<leader>e` | File explorer |
| `<leader>f` | Format buffer (auto-formats on save) |
| `<leader>fg` | LazyGit |
| `<leader>gb` | Git blame |
| `<leader>fr` | Project find & replace |
| `<leader>o` | Code outline |
| `<leader>tr` / `<leader>ts` | Run tests / summary |
| `:StartupTime` | Profile startup (native + lazy.nvim) |

## Manage plugins, themes, LSPs

- **Plugins**: edit specs (`init.lua`, `lua/custom/plugins/`), then `:Lazy sync`. Check load cost with `:Lazy profile`.
- **Themes**: `<leader>ty` to pick; choice persists. All except tokyonight load lazily.
- **LSPs**: Mason auto-installs most servers on demand (`:Mason`). Exceptions installed manually: `vtsls`, `pyrefly` (see table above).
- **Formatters**: conform.nvim per filetype in `init.lua`; auto-format skips files >1MB (`large_file_size` in `lua/config/options.lua`), manual `<leader>f` always works.
- **Tests**: plenary.busted suites in `tests/` — `nvim --headless -c 'lua require("plenary.busted").run("tests/test_qol.lua")' -c 'qa!'`

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| Icons are boxes | Install a Nerd Font, set terminal to use it |
| No completions for TS/Python | `:Mason` — server missing? `vtsls`/`pyrefly` on `PATH`? `:LspInfo` |
| Format-on-save silent on big file | Expected >1MB; use `<leader>f` |
| Slow startup | `:StartupTime`, then `:Lazy profile` for the culprit |
| Plugin errors after update | `:Lazy sync`, restart, `:checkhealth config.health` |
