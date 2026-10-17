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
:checkhealth config          # verify external tools
:Mason                       # confirm LSPs/linters installed
```

## Dependencies

Checked by `:checkhealth config`. Install what's missing:

| Tool | Why | Install |
| :--- | :--- | :--- |
| `git` | plugins, blame, lazy updates | OS package manager |
| `rg` | snacks grep, grug-far | `brew install ripgrep` |
| `fd` | Fast file finding (snacks pickers) | `brew install fd` |
| `bun` | JS/TS runs, vtsls install | `curl -fsSL https://bun.sh/install \| bash` |
| `node` | LSP servers | `brew install node` |
| `python3` + `pynvim` | molten, neotest-python | `pip install pynvim jupyter ipykernel` |
| `make`, C compiler | tree-sitter grammar builds (the CLI compiles) | OS package manager |
| `tree-sitter` | builds every nvim-treesitter parser (see below) | `brew install tree-sitter` |
| `biome` | JS/TS format + lint (not via Mason) | `bun add -g @biomejs/biome` |
| `@vtsls/language-server` | TypeScript LSP (not via Mason) | `bun add -g @vtsls/language-server` |
| `ty` / `pyrefly` / `pyright-langserver` | Python LSP, first on `PATH` wins (not via Mason) | `brew install pyrefly` |

Nerd Font required (`vim.g.have_nerd_font = true`); kitty terminal for image rendering.

Not via Mason, and deliberately so:

- **tree-sitter CLI** — mason prepends its `bin` to `PATH`, so a mason-installed
  `tree-sitter` would silently shadow the homebrew one. No grammar ships
  prebuilt on the `main` branch: each `:TSInstall` runs `tree-sitter build`.
- **Python LSP trio** — mason is skipped for all three; `:NvimCheckPythonLsp`
  reports which ones this machine has.
- **`prettierd`** — see AGENTS.md trap 5; `prettier` is the fallback formatter.

## Molten keys

`<leader>m*` only exist once the remote-plugin manifest lists molten:

```
:UpdateRemotePlugins     # once, per machine
# then restart nvim — the spec's cond is evaluated once at lazy.setup()
:command Molten          # should list MoltenEvaluateLine etc.
```

## Daily keys

Leader is `<Space>`. Essentials:

| Key | Action |
| :--- | :--- |
| `<leader>sf` / `<leader>sg` / `<leader><leader>` | Find files / grep / buffers |
| `<leader>e` | File explorer |
| `<leader>ff` | Format buffer (auto-formats on save) |
| `<leader>fg` | LazyGit |
| `<leader>gb` | Git blame |
| `<leader>fr` | Project find & replace |
| `<leader>o` | Code outline |
| `<leader>tr` / `<leader>ts` | Run tests / summary |
| `:StartupTime` | Profile startup (native + lazy.nvim) |

## Manage plugins, themes, LSPs

- **Plugins**: edit specs (`lua/plugins/` by section, `lua/custom/plugins/` for personal), then `:Lazy sync`. Check load cost with `:Lazy profile`.
- **Themes**: `<leader>ty` to pick (snacks colorscheme picker with live preview); choice persists in `stdpath('data')/theme.txt`. To add one, add its plugin spec in `lua/custom/plugins/themes.lua`, then `:Lazy sync`.
- **LSPs**: Mason auto-installs most servers on demand (`:Mason`). Exceptions installed manually: `vtsls` and the Python ladder (`ty`/`pyrefly`/`pyright-langserver`, see table above).
- **Formatters**: conform.nvim per filetype in `lua/plugins/formatting.lua`; biome leads the JS/TS/JSON chain only in a repo with its own `biome.json`, prettier covers the rest. Auto-format skips files >1MB (`large_file_size` in `lua/config/options.lua`), manual `<leader>ff` always works.
- **Tests**: plenary.busted suites in `tests/` — `nvim --headless -c 'lua require("plenary.busted").run("tests/test_qol.lua")' -c 'qa!'`

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| Icons are boxes | Install a Nerd Font, set terminal to use it |
| No completions for TS/Python | `:Mason` — server missing? `vtsls` on `PATH`? `:NvimCheckPythonLsp`, `:LspInfo` |
| No syntax highlighting for a language | `tree-sitter` CLI missing — `:TSInstall` cannot compile (`brew install tree-sitter`) |
| Format-on-save silent on big file | Expected >1MB; use `<leader>ff` |
| `<leader>m*` says `E492` | `:UpdateRemotePlugins`, then **restart** (see above) |
| Slow startup | `:StartupTime`, then `:Lazy profile` for the culprit |
| Plugin errors after update | `:Lazy sync`, restart, `:checkhealth config` |
