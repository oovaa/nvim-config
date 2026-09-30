# AGENTS.md

Neovim config (kickstart-derived, modularised). Docs live in `README.md`
(background), `SETUP.md` (ops), `CHEATSHEET.md` (every keybinding) — this file
only covers what those don't say.

## Commands

```sh
# one plenary suite (this is what CI runs, one file at a time)
nvim --headless -c 'lua require("plenary.busted").run("tests/test_qol.lua")' -c 'qa!'

# full config stress test — NOT in CI, ~2 min, exits non-zero on any FAIL,
# rewrites the (gitignored) tests/stress-report.md
nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'

stylua .            # stylua --check .  == the CI gate
nvim --headless -c 'qa'   # boot smoke: must print no error/E5108/traceback
```

stylua is not on your PATH by default: `export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"`.
In nvim, `:checkhealth config.health` is this repo's own check (`lua/config/health.lua`).

## Layout

- `init.lua` — bootstrap only. `require 'config.{options,keymaps,autocmds}'` run
  **before** `lazy.setup` because `<leader>` and `vim.o` must exist early.
- `lua/config/` — core config, hand-required. `options` `keymaps` `autocmds`
  (pre-lazy); `sessions` `terminal` `runner` `health` (post-lazy, from `init.lua`).
- `lua/plugins/*.lua` — lazy specs, one file per section, auto-imported via
  `{ import = 'plugins' }`. No index file; adding a file is enough.
- `lua/custom/plugins/*.lua` — personal specs, auto-imported too.
- `lua/custom/ui/` — **builtin UI, not plugin specs**: statusline, tabline,
  dashboard, theme persistence. Wired by hand (`custom.ui.init.setup()`).
- `lua/tests/helpers.lua` — read-all-config helpers for the plenary suites.

## Traps

1. **`stylua --check .` currently fails on 18 files, so CI is red on `master`.**
   `.stylua.toml` sets `call_parentheses = "None"`, `collapse_simple_statement =
   "Always"`, `column_width = 160` — that's why the code reads `if x then return end`
   and `require 'foo'`. If you edit one of those 18 files and run `stylua .`, you
   inherit a large unrelated reformat. Decide deliberately whether to commit it
   (I reverted mine to keep diffs reviewable) or fix your own lines by hand.
2. **`<leader>ur` is not a real reload.** It sources `$MYVIMRC`; lazy prints
   "Re-sourcing your config is not supported with lazy.nvim" and does not re-read
   specs. Everything behind `require` is cached, so `lua/config/autocmds.lua` does
   **not** re-register — but code called from `init.lua`'s body does. That's why
   every `nvim_create_autocmd` in a `setup()` function needs a named
   `group = { clear = true }`; without one they accumulate per reload.
   `tests/stress.lua` asserts this.
3. **No lockfile is committed** (`.gitignore` has `lazy-lock.json`), so CI's
   `lazy.sync()` picks up whatever upstream released. Plugin breakage arrives with
   no commit: the installed `molten-nvim` v1.9.2 has no `plugin/` and no
   `lua/molten/init.lua`, so all 9 `<leader>m*` keys raise `E492`. **Those 9 stress
   failures are expected** — don't "fix" the config. Repair is
   `rm -rf ~/.local/share/nvim/lazy/molten-nvim` then reinstall.
4. **mason cannot install Python packages on this host** (`python3` has no
   `ensurepip`). `debugpy` and `nginx-config-formatter` are deliberately left out
   of `ensure_installed`, with comments, in `lua/plugins/lsp.lua` and
   `lua/plugins/formatting.lua`. Adding a Python-backed mason package makes it fail
   on *every* FileType. `nginxfmt` is also why `nginx` is `false` in
   `format_after_save`'s table.
5. **Do not put `prettierd` back.** Measured here: prettierd cold start 850–2300 ms
   inside nvim, vs 270–470 ms for plain prettier (316 ms warm prettierd). It blew
   the save timeout and reported "Formatter failed" while formatting nothing, and
   leaves an orphan daemon per session. The 2000 ms `format_after_save` timeout
   exists because prettier's own cold start hit 2.3 s — don't lower it.
6. **snacks owns `vim.notify` and replaces it on the first call**
   (`snacks/init.lua:219`). A monkey-patch installed at startup is dead by the
   first notification — see the throttle in `init.lua` for the re-wrap pattern.
   Also `require('snacks.config')` does not exist; use `require('snacks').config`.
7. **0.12-only options are set unguarded** in `lua/config/options.lua`
   (`smoothscroll`, `winborder`, `inccommand = 'split'`) and CI pins nvim v0.12.5.
   A pre-0.11 option needs a guard. Related trap that already bit:
   `foldmethod` is window-local since 0.11, so `vim.bo[buf].foldmethod` raises and
   aborts the rest of the callback — set it per window.
8. **Highlight columns are byte offsets, not display cells.**
   `nvim_buf_add_highlight` takes byte cols, so a nerd glyph advances by `#icon`,
   not `strdisplaywidth(icon)` (3 bytes vs 1 cell). See the dashboard in
   `lua/custom/ui/spec.lua`.
9. **`nvim-treesitter` is pinned to `branch = 'main'`** (the rewrite), so
   `nvim-treesitter.{query,configs,parsers}` no longer exist. mini.ai and
   mini.surround silently lose treesitter support (all their uses are `pcall`-guarded),
   nvim-ts-autotag degrades. Don't add plugins that need the master-branch API.
10. **Sessions** are named `<escaped-cwd>-<sha256[:8]>.vim` under
    `stdpath('data')/sessions`; the trailing-slash and `%`-collision cases are
    handled in `session_file_for` (`lua/config/sessions.lua`), which the dashboard
    `s` picker also calls via `_G._builtin_session_file` — keep them in sync.
    `~/`, `~/Downloads`, `/etc`, `/tmp` are suppressed (exact match, not subdirs).

## Conventions

- `ponytail:` comments (`#` in Lua, `--` in help text) mark deliberate shortcuts.
  Keep the format: name the ceiling and the upgrade path.
- Commits: conventional, lowercase subject — `fix:` `feat:` `docs:` `style:`.
  One logical change per commit.
- `setup.sh` is a **fresh-machine** bootstrap that `git clone`s into
  `$XDG_CONFIG_HOME/nvim` and may `sudo`. `--check` reports without changing
  anything. Don't run it in place.
- The stress harness has no dependencies on purpose (the point is to test the
  config, not a framework). `tests/stress_child.lua` is dispatched by
  `$NVIM_STRESS_SECTION`; it streams results to `$NVIM_STRESS_OUT` so a section
  that dies mid-way still reports what it finished.
