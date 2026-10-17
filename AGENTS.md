# AGENTS.md

Neovim config (kickstart-derived, modularised). Docs live in `README.md`
(background), `SETUP.md` (ops), `CHEATSHEET.md` (every keybinding) — this file
only covers what those don't say.

## Commands

```sh
# what CI runs: every suite, one file at a time (plus boot + stylua jobs)
for f in tests/test_*.lua; do nvim --headless -c "lua require('plenary.busted').run('$f')" -c 'qa!'; done

# full config stress test — CI `stress` job, ~2 min, exits non-zero on any FAIL,
# rewrites the (gitignored) tests/stress-report.md
nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'

stylua .            # stylua --check .  == the CI gate
nvim --headless -c 'qa'   # boot smoke: must print no error/E5108/traceback
```

stylua is not on your PATH by default: `export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"`.
In nvim, `:checkhealth config` is this repo's own check (`lua/config/health.lua`).

## Layout

- `init.lua` — bootstrap only. `require 'config.{options,keymaps,autocmds}'` run
  **before** `lazy.setup` because `<leader>` and `vim.o` must exist early.
- `lua/config/` — core config. `options` `keymaps` `autocmds` (pre-lazy, hand-required
  from `init.lua`); `sessions` `terminal` `runner` `health` (post-lazy, from `init.lua`);
  `python_lsp` (required lazily by the lsp spec, not by `init.lua`).
- `lua/plugins/*.lua` — lazy specs, one file per section, auto-imported via
  `{ import = 'plugins' }`. No index file; adding a file is enough.
- `lua/custom/plugins/*.lua` — personal specs, auto-imported too.
- `lua/custom/ui/` — **builtin UI, not plugin specs**: statusline, tabline,
  dashboard, theme persistence. Wired by hand (`custom.ui.init.setup()`).
- `lua/tests/helpers.lua` — read-all-config helpers for the plenary suites.

## Traps

1. **`stylua --check .` is the CI gate — it must stay green.** `.stylua.toml` sets
   `call_parentheses = "None"`, `collapse_simple_statement = "Always"`,
   `column_width = 160` — that's why the code reads `if x then return end` and
   `require 'foo'`. `stylua .` reflows whole lines, not just indentation, so an
   unreformatted neighbour can turn a 1-line change into a 200-line diff. Run
   `stylua .` on the files you touch and keep the reformat in its own `style:`
   commit, never mixed into a fix.
2. **`<leader>ur` is a real reload; plain `:source $MYVIMRC` is not.** The mapping
   drops `^config%.`/`^custom%.` from `package.loaded` then sources `$MYVIMRC`, so
   config modules re-register from scratch. A bare `:source` only re-runs `init.lua`'s
   body — lazy never re-reads specs ("Re-sourcing not supported"). Either way every
   `nvim_create_autocmd` needs a named `group = { clear = true }` or it stacks:
   `tests/stress.lua` sources `$MYVIMRC` 4x and fails on any autocmd/keymap growth.
3. **No lockfile is committed** (`.gitignore` has `lazy-lock.json`), so CI's
   `lazy.sync()` picks up whatever upstream released. Known case: `molten-nvim`
   v1.9.2 ships no `plugin/` and no `lua/molten/init.lua` *by design* — its
   commands come from the **manifest**, not from python: startup sources
   `stdpath('data')/rplugin.vim` (written by `:UpdateRemotePlugins`), which
   calls `remote#host#RegisterPlugin('python3', ...)` and *defines* the 41 specs
   (24 commands, 17 functions). No `import jupyter_client` happens at
   registration — python only runs when a command is invoked. The spec's `cond`
   therefore just greps that manifest for `molten`
   (`lua/custom/plugins/init.lua`); it is evaluated **once**, at
   `lazy.setup()`, so after `:UpdateRemotePlugins` (the spec's `build`) you must
   **restart** — reloading won't turn the spec on. If all 9 `<leader>m*` keys
   raise `E492`, check `:command Molten` and the manifest before touching the
   spec. Upstream also renamed `MoltenHide` → `MoltenHideOutput` (config binds the new name).
4. **mason cannot install Python packages on this host** (`python3` has no
   `ensurepip`). `debugpy` and `nginx-config-formatter` are deliberately left out
   of `ensure_installed`, with comments, in `lua/plugins/lsp.lua` and
   `lua/plugins/formatting.lua`. Adding a Python-backed mason package makes it fail
   on *every* FileType. `nginxfmt` is also why `nginx` is `false` in
   `format_on_save`'s table.
5. **Do not put `prettierd` back.** Measured here: prettierd cold start 850–2300 ms
   inside nvim, vs 270–470 ms for plain prettier (316 ms warm prettierd). It blew
   the save timeout and reported "Formatter failed" while formatting nothing, and
   leaves an orphan daemon per session. The 2000 ms `format_on_save` timeout
   exists because prettier's own cold start hit 2.3 s — don't lower it.
6. **snacks owns `vim.notify` and replaces it on the first call**
   (`snacks/init.lua:219`). A monkey-patch installed at startup is dead by the
   first notification — see the throttle in `init.lua` for the re-wrap pattern.
   Also `require('snacks.config')` does not exist; use `require('snacks').config`.
   Its own `picker.ui_select` option is *not* what wires `vim.ui.select` here:
   snacks installs that only from its `UIEnter` setup, which never fires
   headless, so the snacks spec's `config` in `lua/plugins/ui.lua` assigns
   `vim.ui.select` explicitly right after `setup()`.
7. **0.12-only options are set unguarded** in `lua/config/options.lua`
   (`smoothscroll`, `winborder`, `inccommand = 'split'`) and CI pins nvim v0.12.6.
   A pre-0.11 option needs a guard. Related trap that already bit:
   `foldmethod` is window-local since 0.11, so `vim.bo[buf].foldmethod` raises and
   aborts the rest of the callback — set it per window.
8. **Highlight columns are byte offsets, not display cells.**
   `nvim_buf_add_highlight` takes byte cols, so a nerd glyph advances by `#icon`,
   not `strdisplaywidth(icon)` (3 bytes vs 1 cell). See the dashboard in
   `lua/custom/ui/dashboard.lua`; `lua/custom/ui/spec.lua` is only a compat
   facade that re-exports it. Statusline and tabline are its siblings
   (`statusline.lua`, `tabline.lua`) in the same directory.
9. **`nvim-treesitter` is pinned to `branch = 'main'`** (the rewrite), so
   `nvim-treesitter.{query,configs,parsers}` no longer exist. mini.ai and
   mini.surround silently lose treesitter support (all their uses are `pcall`-guarded),
   nvim-ts-autotag degrades. Don't add plugins that need the master-branch API.
   On `main` there is no prebuilt grammar: every `:TSInstall` shells out to
   `system({ 'tree-sitter', 'build', '-o', 'parser.so' })`
   (`nvim-treesitter/lua/nvim-treesitter/install.lua:305`), so **the tree-sitter
   CLI is the gate, not `cc`** — without it the build dies at spawn however good
   the C toolchain is. `cc` is still needed one level down (the CLI compiles).
   Mason is deliberately *not* asked for `tree-sitter-cli`: `mason.setup()` puts
   `mason/bin` on `PATH` (`mason/init.lua:25`), so its copy would silently
   shadow the homebrew CLI this host actually uses.
10. **Sessions** are named `<escaped-cwd>-<sha256[:8]>.vim` under
    `stdpath('data')/sessions`; the trailing-slash and `%`-collision cases are
    handled in `session_file_for` (`lua/config/sessions.lua`). **The module is
    canonical**: the dashboard `s` picker resolves `config.sessions` first and
    only falls back to `_G._builtin_find_session` / `_G._builtin_session_files`
    (`custom/ui/dashboard.lua`), which are plain aliases kept for the stress
    harness and legacy reload callers — don't "fix" the picker back onto the
    `_G` names. `~/`, `~/Downloads`, `/etc`, `/tmp` are suppressed (exact match, not subdirs).
11. **Auto-save and format-on-save are coupled across insert mode.** `defer_save`
    includes `TextChanged`, so normal-mode edits — and mid-insert pauses — save
    without leaving insert mode; `format_on_save` returns nil while the mode is
    `i*`/`ni*` (mid-typing), `s*` (snippet Select — a reflow under an active
    selection shifts its anchors, so the next keystroke deletes code), or `R*`
    (replace), because those writes must stay raw (formatting a half-typed
    line reflows it and jumps the cursor). Don't remove one side without the other.
12. **biome wins on both sides of the save only inside a biome-configured repo, and the lint entry pins `cwd`.**
     The one rule lives in `M.biome_root` (`lua/config/health.lua`): walk up from
     the buffer for `biome.json`/`biome.jsonc`, but reject `$HOME`. Without that
     rejection the upward walk hands `~/biome.json` to **every** repo under
     `/home/omar`, and repos that never asked for biome get its lineWidth/quote
     style. Formatting: `lua/plugins/formatting.lua` calls `js_formatters(bufnr)`
     per buffer (conform supports a function in `formatters_by_ft`), returning
     `{ 'biome', 'biome-organize-imports', 'prettier' }` under a repo config and
     `{ 'prettier' }` otherwise; biome leads there on measured speed (0.04s vs
     0.17s median, 121-line JS file, ~4x — past the 30% bar), and that does
     **not** weaken trap 5 — prettier is the fallback backend, only `prettierd`
     is forbidden. Linting: `biome_or_oxlint` in `lua/plugins/ui.lua` returns
     `biomejs` with `cwd` pinned to the buffer's own project root, else `oxlint`.
     Drop that pin and nothing errors visibly: biome resolves its config from
     cwd, aborts with "nested root configuration", nvim-lint's
     `ignore_exitcode` swallows the exit 1, and the buffer just gets zero
     diagnostics. Both sides read `biome_root`, so a change there moves format
     and lint together — never edit one side's copy.
13. **The Python LSP is a ladder, not a fixed server.**
     `lua/config/python_lsp.lua` holds the choice — `M.resolve()` returns
     `{ name, cmd, settings }` for the first hit among `ty` → `pyrefly` →
     `pyright-langserver` (or `nil`), and `M.installed()` reports what is on
     `PATH`. `lua/plugins/lsp.lua` only registers the result (`filetypes`,
     `root_markers`). Keep the resolver free of spawns and filesystem probing:
     `tests/test_python_tools.lua` drives it by stubbing `vim.fn.executable`,
     which is the only thing it may depend on. A spec-level case in the same
     file pins that the winner actually reaches `vim.lsp.config` — the config
     loop once ran *before* the resolver block and silently dropped it on
     ty-only hosts. None of the three is in mason
     `ensure_installed` (trap 4). `:NvimCheckPythonLsp` reports which are on
     `PATH`. `pyrefly` stays registered-but-unused when another server wins, so
     the stress harness can still see it — deliberate, not a leftover.

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
