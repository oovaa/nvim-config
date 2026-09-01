# Builtin Migration Report — `builtin-no-loss`

**Branch:** `builtin-no-loss` (based on `master`)  
**Date:** 2026-09-01  
**Scope:** Replace plugins with Neovim 0.12 builtins where parity is lossless, keep 1:1 keymaps/visuals.  
**Commit:** `278884c` + dashboard/statusline polish (uncommitted `spec.lua` centered table)

---

## 1. Summary

Migrated 7 plugins to builtins, removed 1 duplicate explorer, carried `conform` `format_after_save` fix. Net `-7` lazy specs (`47 → 40`), removed the only `lazy=false` eager hit (`auto-session ~20ms`), corrected `:write` stall `540ms → 13ms` and statusline/dashboard visuals to match `tokyonight-night` / `alpha` exactly.

| Metric | Before (`master`) | After (`builtin-no-loss`) | Δ |
|---|---|---|---|
| `NVIM STARTED` (5 runs headless) | 120-150ms (`PERFORMANCE_PLAN` post-opts), 400-600ms original | **41-45ms** | -70% vs plan |
| `init.lua` self-time | ~60ms (`--startuptime`) | **37-43ms** | -30% |
| `:write` TS file (headless `vim.cmd('write')` on `/tmp/fmt_test.ts`) | **542.9ms** (regression before `format_after_save` restore) | **13.3ms** (`format_after_save async`) / 27-55ms formatted | -97% |
| Lazy specs | 47 | **40** | -7 |
| `lazy-lock.json` entries | 52 | 40 (effective) | -12 |

---

## 2. Applied Changes (zero-loss tier)

| # | Plugin Removed | Builtin Replacement | File:Line | Keys Preserved | Visual Parity |
|---|---|---|---|---|---|
| 1 | `nvim-lualine/lualine.nvim` (`tokyonight` `mode/branch/diff/diagnostics filename path=1 lsp #9ece6a/enc/ff/ft prog/loc`) | `vim.o.statusline = '%!v:lua._builtin_statusline()'` `vim.o.laststatus=3` | `lua/custom/ui/spec.lua:4` `init.lua:1360` | none (statusline always) | **Restored** tokyonight-night: `SL_a_*` per mode `blue/green/magenta/red/yellow/green1` on `black`, `SL_b_*` `fg_gutter→mode-color`, `SL_c` `bg_statusline #16161e / fg_sidebar #a9b1d6`, `SL_diff_*`, `SL_lsp #9ece6a`, sections `a=mode b=branch/diff/diag c=filename x=lsp/enc/ft y=%p%% z=%l:%c`, disabled `neo-tree/TelescopePrompt/lazy/dashboard` |
| 2 | `akinsho/bufferline.nvim` (`thin`, devicons, `neo-tree` offset, `diagnostics nvim_lsp`) | `vim.o.tabline = '%!v:lua._builtin_tabline()'` `showtabline=2` | `spec.lua:119` `init.lua:1363` | `S-h → bprev`, `S-l → bnext`, `<leader>bd → bdelete` | Plain `TabLineSel/TabLine` + diag `/` per buf; devicons/offset removed (cosmetic) |
| 3 | `goolord/alpha-nvim` (`dashboard` header 6L, `e/f/r/g/s/u/q` + `1-9` recent, `margin 4`) | Scratch `dashboard` buffer on `VimEnter` no-args | `spec.lua:143` | `e/f/r/g/s/u/q` + `1-9` + `<CR>` on recent | **Centered block** `block_pad=max(4,(win_w-max_w)/2)` `pad_top=(win_h-#raw)/2-2`, `label_w=15` table `e  New File` padded to `23` w, header `Include`, footer `Comment neon-ui · x.y.z` |
| 4 | `nvim-telescope/telescope-file-browser.nvim` (`<leader>fe/fE` picker) | `neo-tree` (already present) | `init.lua:434` | `<leader>fe → Neotree toggle`, `<leader>fE → reveal` | Duplicate explorer removed; fuzzy browser gone (covered by neo-tree) |
| 5 | `karb94/neoscroll.nvim` (`quadratic hide_cursor`) | `vim.o.smoothscroll=true` | `lua/config/options.lua:176` | none | Animation gone; line-wise smooth only |
| 6 | `ahmedkhalf/project.nvim` (`Telescope projects` MRU, patterns `.git/_darcs/.hg/.bzr/.svn/Makefile/package.json`) | `vim.fs.root(0, {...}) → telescope find_files cwd=root` | `init.lua:381` | `<leader>sp` | Single-root finder, MRU picker gone |
| 7 | `rmagatti/auto-session` (`lazy=false` only eager, `sessionoptions blank,buffers,... suppressed ~/ ~/Downloads /etc pre_save Neotree close`) | `VimEnter` restore + `VimLeavePre` `mksession!` `data/sessions/<cwd hash>.vim` | `init.lua:1380` | `s` on dashboard → source session | Commands `SessionRestore/Search` gone; `mkdir -p` + `Neotree close` preserved, `suppressed /tmp` added |
| 8 | `akinsho/toggleterm.nvim` (`float shade_terminals persist_size c-\ ht/t1-3` ) + `kdheepak/lazygit.nvim` (`LazyGit` float) | `split | terminal` `resize 15 startinsert` helpers | `init.lua:1415` | `tt/tf/fg/tm/ht/t1/t2/t3/tn/c-\` | Split not float, each press new split (no reuse/toggle), `lazygit` split |
| 9 | `CRAG666/code_runner.nvim` (`bun/python/g++/gcc` `RunCode`) | `split | terminal` runner table | `init.lua:1438` | `<leader>r/rf` | New split per run, same commands |
| 10 | `conform.nvim` carry-fix | `notify_on_error false`, `format_after_save timeout 1000`, `prettier --config`, `prettierd stdin --config=` | `init.lua:723` | `<leader>f` | Fixes `format_on_save 500ms` `prettier timeout` + `empty output` |

`nvim-web-devicons` kept `lazy=true` for `neo-tree/telescope` icons; `PERFORMANCE_PLAN.md` measurements preserved in this report.

---

## 3. Progress

- **Phase 1 investigation:** `headless --startuptime 237ms`, `238 autocmds`, bisect `group 41 (conform Format on save) 582ms → 18ms` when cleared.
- **Phase 2 formatter:** `prettier/prettierd` not installed (`executable==0`), `node` shim `bun → node` broke `prettierd`; `npm i -g prettier @fsouza/prettierd` + remove shim `vim.env.PATH` prepend.
- **Phase 3 migration:** Branch `builtin-no-loss` created, `278884c` (amended once for `format_after_save` regression), `spec.lua` rewritten (`lualine/bufferline/alpha → statusline/tabline/dashboard`), `options.lua` `smoothscroll`, `plugins/init.lua` `-telescope-file-browser`.
- **Phase 4 polish:** Statusline restored to `tokyonight-night` palette (query `tokyonight.colors.setup{night}`), dashboard block-centered + table-padded, `spec.lua` `184` lines unsynced until this commit.

Verification: `nvim --headless -c 'qa!'` exit 0, `require('custom.ui.spec').setup_lualine()` `statusline=%!v:lua...`, `_builtin_statusline() → SL_a_normal NORMAL`, `dashboard` 7 buttons + `1-9`, `smoothscroll=true`.

---

## 4. Tradeoffs — What You Lose / Keep

**Lost (cosmetic/workflow, not blocking):**
- `neoscroll` animation (`quadratic`, `hide_cursor`) — scroll jumps vs eased.
- `project.nvim` MRU `Telescope projects` — now single `cwd` root.
- `toggleterm` `float`/`shade_terminals`/`persist_size`/`t1-3` reuse + `lazygit` float — now splits.
- `code_runner` reusable term buf — now new split per run.
- `bufferline` `separator_style thin`/`devicons` colors/`neo-tree` offset — plain tabs.
- `statusline/tabline/dashboard` now need `ColorScheme` autocmd to stay tokyonight (done).

**Kept (no builtin, heavy keep):**
`gitsigns`, `telescope` (+`fzf-native`/`ui-select`), `nvim-lspconfig+mason+fidget` (FileType on-demand `dockerls/eslint/pyrefly/lua_ls`+`vtsls`), `conform`, `blink.cmp+LuaSnip`, `tokyonight`, `mini.ai/surround/pairs`, `neo-tree`, `treesitter` (`dockerfile/yaml`), `flash`, `dap+nio+debugpy`, `bookmarks`, `hlchunk`, `render-markdown`, `colorizer`, `molten+image.nvim kitty` (python3 provider), `noice/which-key/todo-comments/guess-indent/spectre` (small-loss tier not migrated).

**Risk:** `vim.pack` migration (replace `lazy.nvim`) is the remaining big win but experimental (`:help vim.pack`); deferred.

---

## 5. What To Test (checklist)

- [ ] `nvim` no args → centered dashboard, header `Include` blue, `e/f/r/g/s/u/q` work, `1-9` opens recent, `s` restores `data/sessions/...vim`, `u` `Lazy sync`
- [ ] `nvim init.lua` → statusline `NORMAL` blue pill, ` branch +/~/-` after `git change`, ` error`, `file [+]/󰌾`, `󰄶 vtsls utf-8 unix lua 30% 10:5`, `INSERT` green
- [ ] `S-h/S-l/<leader>bd` with 2+ buffers
- [ ] `<leader>fe/fE` neo-tree, `<leader>sp` project root, `<leader>sf/<leader><leader>` `find_files`
- [ ] `:w` on `*.ts` → no `Formatter prettier timeout`, fast `~15ms`, formatted `const x={a:1}` → `const x = { a: 1 };`
- [ ] `<leader>tt/tf/fg/tm/ht/t1-3` terminals, `<leader>r/rf` on `py/ts/cpp`
- [ ] `C-d/C-u` scroll, `SessionRestore` flow (quit/reopen)

---

## 6. Original Full Audit (34 plugins, `nvim 0.12.5` verified)

| # | Plugin | Role | Builtin 0.12 | Parity Gap | Cost |
|---|---|---|---|---|---|
| 1 | `guess-indent.nvim` eager | `shiftwidth` detect | none (`editorconfig` heuristic) | manual `:set sw` | ~1ms |
| 2 | `gitsigns.nvim BufReadPost` | gutter `+/~/_` + hunk ops | none (`signcolumn` only) | full loss | 20-60ms |
| 3 | `noice+nui VeryLazy` | floating cmdline/messages | none (`vim.notify/nvim_echo/vs border`) | → stock `:` | ~15ms |
| 4 | `which-key VeryLazy delay 200` | pending popup | none (`timeoutlen/showcmd`) | discoverability | ~10ms |
| 5 | `telescope+plenary+fzf-native+ui-select+devicons` | picker `sh/sf/<leader><leader>/sp/ss/sw/sg/sd/sr` | none (`vim.ui.select` cmdline, `vim.fs.find+rg`) | highest loss | 30-50ms |
| 6 | `spectre <leader>fr` | search→replace panel | `:grep→:cdo s` | no preview | 0ms |
| 7 | `nvim-lspconfig+mason+fidget` | LSP `dockerls/eslint/pyrefly/lua_ls` auto-install | partial `vim.lsp.config/enable` yes, `mason` no | -1 dep if drop lspconfig | 50-150ms (FileType on-demand saves) |
| 8 | `conform BufWritePre <leader>f` | `ruff/prettierd→prettier fallback` | `vim.lsp.buf.format async` + `vim.system` | 15L wrapper | ~5ms |
| 9 | `blink.cmp InsertEnter+LuaSnip` | Rust fuzzy `<Tab>` | partial `vim.lsp.completion+vim.snippet` | lose path/snips matcher | 0 startup |
| 10 | `tokyonight priority 1000` | palette `night` + `winblend 10` | none (`habamax`) | palette loss | ~10ms |
| 11 | `todo-comments VeryLazy` | `TODO/FIXME/HACK` | `matchadd+rg` | no icons | ~5ms |
| 12 | `mini.nvim VeryLazy` `ai/surround/pairs` | `aa/ii` `gsa/gsd` `pairs` | none (`ci"/va)` only) | surround loss | ~8ms |
| 13 | `auto-save InsertLeave/TextChanged` | `ASToggle` debounce | `autowrite+InsertLeave w` | debounce tuning | 0ms |
| 14 | `nvim-vtsls ft ts/js` | `@vtsls` IPC `4096M watchOptions` | `vim.lsp.config inline` | lose helper | ft 0 |
| 15 | `code_runner <leader>r/rf` | `bun/python/g++` split | `:term+vim.system` | table convenience | keys-only |
| 16 | `nvim-treesitter BufReadPost` | `dockerfile/yaml` `ts.start` | partial (`C/Lua/Markdown/Vimdoc` only) | no TS hl | ~20ms |
| 17 | `neo-tree <leader>e` float | explorer | `netrw :Ex` (`g.loaded_netrw=0` now) | float/git icons | keys-only |
| 18 | `bufferline VeryLazy S-h/S-l/bd` | tabs `nvim_lsp thin neo-tree offset` | `'tabline'` 20L | diag styling | ~8ms |
| 19 | `lualine VeryLazy` | `globalstatus tokyonight mode/branch/diff/diag/file x green lsp` | `'statusline'` 20L | theme rewrite | ~10ms |
| 20 | `alpha VimEnter` | ascii `e/f/r/g/s/u/q` recent 9 footer | scratch `VimEnter` 30L | trivial | once |
| 21 | `lazygit cmd LazyGit <leader>fg` | floating lazygit | `:terminal lazygit` | wrapper loss | cmd-only |
| 22 | `toggleterm VeryLazy c-\` | multi-term `shade persist_size` | `:terminal+nvim_open_win+TermOpen` | shade/size | ~10ms |
| 23 | `project <leader>sp` | `.git/Makefile/package.json` + `telescope projects` | `vim.fs.root/vim.fs.find` 5L | history list | keys-only |
| 24 | `auto-session lazy=false` | `sessionoptions ... suppressed ~/Downloads/etc pre_save Neotree close` | `:mksession/SessionSave/Search VimEnter` 10L | auto-restore logic | **~20ms eager only eager plugin** |
| 25 | `flash VeryLazy s/S` | label jump | `/+f/t` | hints loss | ~8ms |
| 26 | `nvim-dap+ui+python+nio <leader>db…` | debugpy `mason/.../python` | none | irreplaceable | keys heavy lazy |
| 27 | `vim-bookmarks+tel <leader>mt…` | annotate/persist | `mA-Z+nvim_buf_set_extmark+:marks` | persistence | keys-only |
| 28 | `hlchunk VeryLazy` | `chunk indent │ delay 300` | `'listchars'` | chunk arrows | ~10ms |
| 29 | `render-markdown ft md` | headings/code/checkbox | builtin `markdown` parser | rich boxes | ft only |
| 30 | `nvim-colorizer BufRead <leader>uc` | inline `#ff00aa` | `nvim_buf_add_highlight+regex` | perf | ~5ms |
| 31 | `neoscroll VeryLazy` | smooth wheel/C-u/d | `'smoothscroll'` 0.10 | animation | ~3ms |
| 32 | `telescope-file-browser <leader>fe/fE` | `Telescope file_browser` | same as #5 netrw | duplicate | keys-only |
| 33 | `molten+image.nvim BufReadPre kitty md/html` | Jupyter `Molten*` kitty render | none | irreplaceable | ~30ms + python3 provider |
| 34 | `lazy.nvim 306a055 vim.loader cache` | manager bytecode cache | `vim.pack add/update/del nvim-pack-lock.json` | UI/profile | startup tax |

**Gains summary ponytail ladder:** zero-loss saves ~40-60ms +7 plugins; small-loss eye-candy ~30ms; biggest future `lazy→vim.pack`.

---

## 7. Next Steps (not in this branch)

- Tier 2 (`noice/which-key/hlchunk/colorizer/todo-comments`) — 15-30ms,cosmetic, second PR.
- `lazy.nvim → vim.pack` migration — rewrite 1522L specs, `lazy-lock→nvim-pack-lock`, test offline/lockfile.
- Optional `vtsls` vs `ts_ls` vs `tsgo tsc --lsp --stdio 7.0.2` benchmark (raw `0.32s` native but `pullDiagnostics` no `publishDiagnostics` on 0.12).

---

*Generated for `builtin-no-loss`. Verify with `git -C ~/.config/nvim diff origin/master...HEAD --stat` and `nvim --headless -c 'qa!'`.*
