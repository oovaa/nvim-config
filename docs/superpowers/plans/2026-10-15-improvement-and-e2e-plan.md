# Neovim Config — Improvement Plan + E2E Test Plan

**Date:** 2026-10-15 · **Base:** `b95cb15` (up to date, tree clean) · **Measured on:** nvim 0.12.6
**Scope:** performance, tooling, UI/UX, and end-to-end verification.

Every claim below was verified on this machine (I installed nvim 0.12.6 at
`~/.local/opt/nvim` to do it). Claims I could *not* verify are marked `[unverified]`.

---

## 0. Executive summary

The config is in far better shape than the task count suggests. Boot is clean,
headless startup is **30–60 ms**, and the previous plan's structural work (autocmd
idempotency, module split, biome wiring, python LSP ladder) genuinely landed.

The problem is **not** performance. It is that **the safety net does not work**,
and three "done" tasks are inert on this host.

| Severity | Finding |
|---|---|
| **P0** | The CI gate is blind. Delete a test file or replace it with garbage — CI stays green. *(verified: exit 2 + `FAILED TO LOAD FILE`, unmatched by the grep)* |
| **P0** | `e2e_features.lua` never runs — CI globs `tests/test_*.lua`. The repo's best test is dead code. *(verified)* |
| **P1** | Lua can never be formatted. `lsp.lua:204` disables lua_ls formatting, but conform has no `lua` entry. *(verified: stylua installed, wired to nothing)* |
| **P1** | biome is **not installed**; tasks D1/D2 are inert. `~/.bun/bin` = bun, bunx, vtsls. *(verified)* |
| **P1** | `stop_after_first` is unset, so if biome *were* installed, prettier runs **last and wins** — erasing the claimed 4× win. *(verified by reading)* |
| **P1** | `node`/`vtsls` are not on PATH and `options.lua:12-17` probes neither location → jsonls + vtsls die with exit 127. *(verified)* |
| **P2** | `%` is not escaped in statusline branch/filename. `release%2-branch` renders as `releasebranch`. *(verified empirically)* |
| **P2** | Stress suite contains assertions that `return true` unconditionally; one FAIL is permanent and trained-ignore. |
| **P3** | blink.cmp has no ghost text; `fuzzy` downloads a binary on first use. |

---

## 1. What is NOT worth doing

Stated up front so nobody re-litigates it. All rejected on measured evidence:

- **Startup optimisation.** 30–60 ms headless against a 400 ms budget. There is nothing to win.
- **C3 (session scan cost).** Measured **0.48 ms** to list, **2.33 ms** worst-case lookup, triggered once per dashboard `s` press — never per keystroke, never on redraw. Even folding the double `readfile` into one loop saves ~1 ms. **Do not do it.** The only defensible piece is pruning the stale `/tmp/nvim/...sandbox-*` session files.
- **Async `format_after_save`.** Trap 11's rationale (discarding a result under concurrent modification, against a ~1 s auto-save) is unchanged. Sync + 2000 ms stays.
- **`snacks.dashboard`.** E1 was already decided against. Keep the custom dashboard.
- **Reverting the nerd glyphs.** `6d09083`/`b95cb15` deliberately put them back.
- **Bumping `maxTsServerMemory` 2048 → 3072.** Only if the box is RAM-tight; VSCode's own default is 3072, so 2048 is a deliberate choice, not a bug.
- **`fuzzy = 'rust'`.** Costs a GitHub download on first use for no real gain. Pin `implementation = 'lua'`.

---

## 2. P0 — Make the gate real

Nothing else in this document matters if a red suite reads as green.

### 2.1 The CI loop cannot fail

`smoke-test.yml:59-69` globs `tests/test_*.lua`, runs plenary, then greps only for
`Failed *:.*[1-9]|Errors *:.*[1-9]`. Verified behaviour:

| Suite state | Exit | Plenary output | CI verdict |
|---|---|---|---|
| Syntax error in the file | `2` | `FAILED TO LOAD FILE` | **passes** |
| Zero `describe` blocks | `0` | *(nothing)* | **passes** |
| Suite deleted from disk | — | loop skips it | **passes** |

`plenary/busted.lua` signals via `cq` (exit 2) on load failure, and `| tee` discards
that code entirely, so even `set -e` would not catch it.

**Fix** — one line in the loop, plus `pipefail`:

```sh
set -o pipefail
for f in tests/test_*.lua; do
  nvim --headless --cmd "cd $GITHUB_WORKSPACE" -c "lua require('plenary.busted').run('$f')" -c 'qa!' 2>&1 | tee /tmp/test.log
  if ! sed 's/\x1b\[[0-9;]*m//g' /tmp/test.log | grep -qE 'Success: +[0-9]+'; then
    echo "::error::$f produced no results (load failure or zero tests)"; cat /tmp/test.log; exit 1
  fi
  if sed 's/\x1b\[[0-9;]*m//g' /tmp/test.log | grep -qE 'Failed *:.*[1-9]|Errors *:.*[1-9]'; then
    echo "::error::$f failed"; cat /tmp/test.log; exit 1
  fi
done
```

The `Success: +[0-9]+` presence check is what closes the hole: a load failure or an
empty file prints no summary at all.

### 2.2 Revive `e2e_features.lua`

```sh
git mv tests/e2e_features.lua tests/test_e2e_features.lua
```

Then **delete all 7 `NVIM_APPNAME = 'nvim-improve'` occurrences** (and the hardcoded
`data .. '/nvim-improve'`). With that appname the child boots `~/.config/nvim-improve`
— a *different config* — and the file's own final assertion
(`assert.are.equal(root, stdpath 'config')`) would fail. CI already symlinks the
checkout to `~/.config/nvim`, so the default appname is correct.

This single rename is worth more than any new test: it revives the molten-manifest
case, the real biome-lint diagnostic case, the real `<leader>bp` keypress case, and
the python-ladder child-process case — all currently dead.

### 2.3 Kill the permanent red

`stress.lua:233` FAILs because the 9 `<leader>m*` Molten keys never register.
`rplugin.vim` on this host is 3 comment lines with zero `molten` occurrences, so the
spec's `cond` is correctly false (Trap 3).

**Keep the keymaps. Keep `cond`. Fix the assertion.** The check should ask "does this
which-key group have a mapping?" and answer FAIL only when the owning spec is
*enabled*. Collect each `keys` prefix from the lazy registry with its spec's `cond`
result, then:

- prefix owned by an enabled spec, no mapping → **FAIL** (a real regression)
- prefix owned by a spec whose `cond` is false → **WARN**, carrying the reason
  (`<leader>m: molten spec cond-disabled; rplugin.vim lists no molten`)

A permanently red stress job trains you to skim it, which is how the *next* real FAIL
gets missed.

Also fix the two dead assertions at `stress.lua:899-931` — they build a `missing` table
and then `return true` unconditionally. Two of the 894 "PASS"es cannot fail.

---

## 3. P1 — Fix what is actually broken

### 3.1 Lua formatting (2 lines)

`lsp.lua:204` disables lua_ls formatting with the comment *"formatting is done by
stylua"*, and `lsp.lua:259` installs stylua *"conform needs it"*. But
`formatters_by_ft` (`formatting.lua:119-141`) has no `lua` key and `enabled_filetypes`
(`formatting.lua:77-99`) has no `lua = true`. With `lsp_format = 'fallback'`, conform
finds no client and `notify_no_formatters` prints *"No formatters available for
filetype: lua"*.

```lua
-- formatters_by_ft
lua = { 'stylua' },
-- enabled_filetypes
lua = true,
```

In a config written in Lua, `<leader>ff` currently does nothing.

### 3.2 biome: install it, and stop prettier from winning

Two independent defects:

1. **Not installed.** `ls ~/.bun/bin` → `bun bunx vtsls`. D1/D2 are inert; prettier is
   doing all JS/TS today, which is the *slower* path the tasks were meant to remove.
2. **`stop_after_first` is unset** (`formatting.lua:110-112`). Conform's default runs
   *every* available formatter in the list, so `{ 'biome', 'biome-organize-imports',
   'prettier' }` would run all three — and prettier, **last**, would overwrite biome's
   output using `~/.config/nvim/prettier.config.json`. The 4× claim would be void and
   you would still pay prettier's 270–470 ms cold start (Trap 5).

```lua
default_format_opts = {
  lsp_format = 'fallback',
  stop_after_first = true,   -- prettier is the fallback, not a co-runner
},
```

With `stop_after_first`, `biome-organize-imports` cannot run (it is a separate entry),
so simplify `local biome = { 'biome', 'prettier' }` — biome formats, biome handles
imports, prettier is the fallback when no `biome.json` is present.

Install it (`bun add -g @biomejs/biome` or `npm i -g @biomejs/biome`) and add a
`:checkhealth config` row so this can never silently regress again.

> Note: `prepend_args = {'--config', '~/.config/nvim/prettier.config.json'}` at
> `formatting.lua:115` overrides any project `.prettierrc`, contradicting the comment
> at `formatting.lua:121`. Either drop the prepend or fix the comment.

### 3.3 Make `node`/`vtsls` resolvable

`options.lua:11-24` prepends the first prefix containing node, but its list is
linuxbrew / opt/homebrew / /usr/local. On this host node lives at
`~/.local/share/pi-node/current/bin` and vtsls at `~/.bun/bin` — neither is probed.
Result: jsonls and vtsls die with exit 127 (`env: 'node'`), which is precisely the
failure the block was written to prevent.

```lua
local prefixes = {
  vim.fn.glob(vim.fn.expand '~/.local/share/pi-node/*/bin', false, true),
  vim.fn.expand '~/.bun/bin',
  vim.env.HOMEBREW_PREFIX and vim.env.HOMEBREW_PREFIX .. '/bin',
  '/home/linuxbrew/.linuxbrew/bin', '/opt/homebrew/bin', '/usr/local/bin',
}
```

Flatten the table before the loop; `~/.bun/bin` covers vtsls too.

### 3.4 vtsls client half is dead

`editing.lua:170` sets `vtsls.enableMoveToFileCodeAction`, but that code action is
registered from `nvim-vtsls/lua/vtsls/init.lua` inside `require('vtsls').config()`,
which is **never called** (verified by grep — only `vim.lsp.config('vtsls', ...)`
exists). Symptom: "Move to file" runs with no `targetFile`. The same call also installs
`VtsExec`, `VtsRename`, `organize_imports` and `fix_all`.

```lua
require('vtsls').config {}   -- do NOT use require('vtsls').lspconfig; lspconfig is removed
```

Drop `vtsls.experimental.completion.entriesLimit = 30` (`editing.lua`) — upstream
documents it as a remedy for a too-large completion payload, and blink already
fuzzy-matches.

### 3.5 DAP gate is dead and lands on a host without debugpy

`debugging.lua:45-46` only calls `dap-python.setup` when a mason venv exists. It does
not, so the adapter is never configured — and `python3 -c 'import debugpy'` raises
`ModuleNotFoundError`, so `<leader>dc` fails regardless. dap-python's default is
already `python3 -m debugpy`. Call `setup {}` unconditionally and delete the gate.

`health.lua:93` then violates Trap 4 by advising `:Mason` to install debugpy — a
package mason cannot build on this host (no `ensurepip`). Change the advice to
`pip install --user debugpy`.

### 3.6 blink.cmp — two cheap wins

- **Ghost text is the single biggest available UX improvement and it is absent**
  (`completion.lua:39-106`). `completion.ghost_text.enabled = true`.
- **Pin `fuzzy = { implementation = 'lua' }`.** The default
  (`blink.cmp/config/fuzzy.lua:42`) downloads a prebuilt binary from GitHub on first
  use — a network dependency in the completion path.

### 3.7 Capabilities reach only one server

`get_lsp_capabilities()` is called exactly once, for vtsls (`editing.lua:138,146`).
lua_ls, jsonls, dockerls, nginx, compose and the python ladder all get Neovim
defaults — no snippet support, no markdown signature help. Fixing this means
requiring blink at `FileType`/`VimEnter`, which defeats blink's `event = 'InsertEnter'`
load. **Judgment call, not a free win** — the cheap version is to wire capabilities for
the servers that matter and accept blink's earlier load.

---

## 4. P2 — UI polish

### 4.1 Escape `%` in the statusline (verified)

`statusline.lua:312` escapes LSP progress (`gsub('%%','%%%%')`), but `:233` (branch),
`:281` (filename via `expand('%:~:.')`) and `tabline.lua:55` (buffer name) do not.
Verified empirically:

```
raw     -> "releasebranch"       -- %2 expanded as register 2, text vanished
escaped -> "release%2-branch"
```

A git branch named `release%2-branch` renders wrong; a filename like
`sales%20report.md` hits the same path. One helper applied at all four sites.

### 4.2 Other UI items

| # | Change | Effort |
|---|---|---|
| 1 | `statusline.lua:350` — drop `enc` and `ff`. Both are `utf-8 unix` on every file: 9 cells of noise, and the left section is never truncated, so in a split the filename is what disappears. Deletion. | S |
| 2 | `visual.lua:58-69` — which-key has groups for `s t m d f r g u y` but not `<leader>l` (`ls`, `lS`, `lr`). One line. | S |
| 3 | `dashboard.lua:116` — `fnamemodify(f, ':~:.')` is never truncated and `max_w` sizes the block from it. Cap at ~60 cells. | S |
| 4 | `dashboard.lua:152` — footer still reads `neon-ui · 0.12.6`; alpha was removed. Misleading on the first screen a new user sees. | S |
| 5 | `dashboard.lua:123` — `VimEnter` autocmd has **no `group = { clear = true }`**. Trap 2 violation; every `<leader>ur` stacks another. Inert today (VimEnter already fired) and unguarded by CI. | S |
| 6 | `dashboard.lua:44-47` — dead branch. `sessions.lua:83` never returns nil, and the fallback builds the pre-`sha8` legacy name that `sessions.lua:33` no longer writes. Trap-10 drift in dead code; delete. | S |
| 7 | `theme.lua:107` — `require('tokyonight.colors').setup{}` runs on **every** ModeChanged, deep-copying the palette and blending ~40× to make two hexes. Cache per ColorScheme. | S |
| 8 | `theme.lua:110` + `tabline.lua:12` hardcode tokyonight hexes while 14 themes are installed and the rest of the statusline derives accents from live highlights. | S |
| 9 | `options.lua:79-81` documents `have_nerd_font = false` as an escape hatch, but the custom UI emits PUA unconditionally. Either honour it or correct the comment — silently doing nothing is the worst option. | S |
| 10 | `statusline.lua:222` — on the dashboard the bar returns `'%#SL_c# %f %*'` against an unnamed buffer, so it renders as a bare 2-space bar. | S |

**Two things the analysis flagged that I checked and rejected:**

- *Tabline clicks are a silent no-op* — **false**. `options.txt:6400-6406` shows
  `%10@SwitchBuffer@` calls `SwitchBuffer(10, 1, 'l', '    ')`, so the number before
  `@` *is* argument 1. `'%' .. buf .. '@_builtin_tabclick@'` correctly passes the bufnr
  and the button. The handler is fine; only the *test* of it is fake (both
  `test_builtin_ui.lua:47` and `stress.lua:500` call it with hand-made args instead of
  dispatching a real click).
- *Mode pill flips INSERT → IC during completion* — **false**. `mode()` returns one
  character without an argument; `mode(1)` is what returns `ic`/`Rc`.

---

## 5. Health check additions

New `:checkhealth config` rows (`lua/config/health.lua`), each guarding a defect that
is currently invisible:

- `vtsls` — *not a mason package, resolved from `~/.bun/bin`; its absence silently
  disables all TypeScript*
- `lua-language-server` — the only always-on LSP in a Lua-heavy config, currently unchecked
- biome — the whole point of D1/D2; guard against it silently going missing again
- `tree-sitter` CLI — Trap 9: **this is the parser gate**, not `cc`
- Python LSP — reuse `config/python_lsp.lua:installed()` so the row cannot drift
  from the ladder's own predicate
- `jupyter` / `jupytext` — listed as external in `init.lua:17`, unchecked

---

## 6. E2E test plan

**Mechanism — reuse what already works.** `tests/stress_child.lua` dispatches by
`$NVIM_STRESS_SECTION` and streams `@@LEVEL|name|msg` to `$NVIM_STRESS_OUT`. Add a
`data-safety` section; anything needing a pristine boot goes in the child. Everything
else goes in `tests/test_*.lua` so the existing CI loop picks it up with no workflow
edit.

**Technique key:** `a` feedkeys · `b` filesystem fixture · `c` child process ·
`d` golden snapshot · `e` manual (cannot automate)

### Tier 0 — smoke
| id | proves | tech | pass signal |
|---|---|---|---|
| T0.1 | the CI loop can fail | c | **Section 2.1 above** — no summary ⇒ red |
| T0.2 | boot is clean | c | exit 0, zero `E[0-9]{3,}`/traceback |
| T0.3 | every stress child finished | c | each `out-<section>` ends `@@END` (today only WARN) |

### Tier 1 — data safety (would lose your code)
| id | proves | tech | steps → assertion |
|---|---|---|---|
| **T1.4** | **Trap 11: a save fired mid-insert writes RAW text** | a+b | `feedkeys('A','x')`; assert `get_mode().mode=='i'`; `:write` → **bytes == the exact typed half-line, no reflow, cursor unchanged** |
| T1.5 | control: the *same* save outside insert DOES format | b | repeat after `\<Esc>` → ruff-normalized bytes (proves T1.4 isn't passing because conform is dead) |
| T1.1 | auto-save persists a normal-mode edit with no `:w` | b | write file, `:e`, `feedkeys('ox')`, wait 2 s → `readfile` contains `ox`. **Zero tests today** |
| T1.2 | edits <1 s before `:bun` are not lost | b | edit, immediately `:bun` → bytes survive (`immediate_save` on BufLeave) |
| T1.7 | undofile restores across sessions | a+b | write, edit, write, `%bwipeout!`, reopen, `u` → buffer == `"x\n"`. Stress only asserts `undofile()` returns a path |
| T1.9 | a real quit writes a real session; a real start restores it | c | child1 edits + `qa` → session exists; child2 `:source` → buffer restored. Stress §8 `exec_autocmds`'d `VimLeavePre` instead |
| T1.10 | dashboard-only exit does not clobber an existing session | c | compare mtime + bytes across a dashboard-only child |
| T1.11 | large-file buffers are not auto-formatted | b | 1 MiB `.py`, edit one line, `:write` → unformatted, `b:large_file_mode` set |
| T1.8 | `:q` with unsaved changes is refused | c | edit then `q` → exit ≠ 0, output contains `E37` |

**T1.4 is the flagship.** Trap 11 is the highest-consequence behavior in the config and
it has **zero** tests. `test_markdown_lists.lua` proves `feedkeys` works inside a
plenary coroutine, so this should work; if it doesn't, fall back to stubbing
`nvim_get_mode` and calling the `format_on_save` closure directly.

### Tier 2 — core editing
| id | proves | tech | steps → assertion |
|---|---|---|---|
| T2.1 | `<leader>ur` really reloads | c | record autocmd+keymap counts, press it, re-count → **identical**, then press `<leader>q` → "No diagnostic on this line". Stress §15 only sources `$MYVIMRC`; the `package.loaded` purge path is never exercised |
| T2.2 | mini.pairs auto-close + `skip_next` | a | `feedkeys('i(')` → lines == `{'x=('}`; no doubling. `test_critical_fixes.lua` only greps the source |
| T2.3 | mini.surround `gsa`/`gsd` | a | surround/unsurround changes lines |
| T2.4 | `<leader>ff` formats the buffer **without touching disk** | a+b | dirty a `.json`, `<leader>ff`, don't write → buffer normalized, on-disk bytes unchanged |
| T2.6 | `gy` / `<leader>yd` pick the nearest diagnostic by column | a | two diagnostics at different cols → register == nearest msg |
| T2.10 | `<leader>q` opens the diagnostic loclist | a | set a diagnostic, press it → loclist has 1 entry, qf window current |
| T2.13 | flash `s` jump | a | two occurrences, press `s` then target char → cursor moves. `[unverified — flash may need child + stub_input]` |

### Tier 3 — language features
| id | proves | tech | steps → assertion |
|---|---|---|---|
| T3.1 | LSP hover returns real content | a | wait attach, `textDocument/hover` → result contains the signature. Zero tests today |
| T3.3 | `grn` renames across files **on disk** | a+b | rename in two buffers, write both → both contain the new name. The only real write-path rename proof |
| T3.5 | ruff/biome lint yields real diagnostics | b | bad file, `lint.try_lint(0)` → ≥1 diagnostic with `source=='ruff'`. Mirrors the dead `e2e_features` case |
| T3.7 | treesitter really parses | a | real `.lua` file → parser non-nil, root spans buffer, `nvim_buf_get_hl` has a non-empty `Function` range. Today only asserts `start()` was *called* |
| T3.10 | blink.cmp opens a menu | a | `feedkeys('i','stri')`, wait → `complete_info().visible == 1`. Zero tests today |
| T3.9 | all three python-ladder rungs attach | c | fake `ty`/`pyrefly`/`pyright` shims on PATH, child opens a `.py` → client attached. *Moves the dead `e2e` case into CI* |

### Tier 4 — UI (golden snapshots)
| id | proves | tech | pass signal |
|---|---|---|---|
| T4.1 | statusline content is pinned | d | `nvim_eval_statusline` on a fixed buffer set + `nvim_get_hl('SL_c')` → diff vs `tests/golden/statusline.txt`. Regenerate **only** with `UPDATE_GOLDEN=1` |
| T4.2 | dashboard byte columns are right | d | `nvim_buf_get_extmarks` → diff vs golden. Asserts Trap 8 (byte cols, not display cells) for real |
| T4.3 | dashboard degrades at 60/80/120 cols | d | no rendered row exceeds `columns` |
| T4.4 | tabline matrix is pinned | d | 0/1/2/3 buffers × modified/unmodified × current/not |
| T4.6 | dashboard `s` resolves a **real** session | a+b | write a session, press the row → sourced, buffer restored. Today only the zero-session inert path |

### Tier 5 — tooling
| id | proves | tech | pass signal |
|---|---|---|---|
| T5.1 | gitsigns signs a real hunk; `[c`/`]c` move | a | `git init` + commit + edit → signs appear, cursor moves both ways. Requires a real repo |
| T5.4 | DAP breakpoint toggles **without launching** | a | `<leader>db` → `dap.breakpoints` has the line, **no session started**. Deliberately avoids debugpy (Trap 4) |
| T5.5 | neotest discovers a real test file | a | summary marks 1 file attempted — **do not** assert pass/fail (needs pytest) |

### Tier E — manual, must be committed as `tests/MANUAL.md`
Cannot be automated; each needs a binary pass/fail so it is reproducible:
dashboard readable at 60 cols · nerd-font coverage (zero U+FFFD anywhere) · auto-save
feels right (file updates ~1.5 s, no mid-typing reformat) · format-on-save latency
(< 400 ms warm — a 2 s hang is the prettierd regression from Trap 5) · snacks picker
first paint < 150 ms in a 5k-file repo · LSP progress appears and does not stick ·
theme switch re-tints statusline/tabline/dashboard · which-key stays visible in macros.

### Known-impossible
Real TTY / kitty (image.nvim, spinners, smoothscroll) · nerd-font glyph coverage
(a property of your font) · network (`<leader>hr` rest.nvim) · debugpy + pytest
(Trap 4) · "does the picker *feel* laggy" (needs a stopwatch and a human).

---

## 7. Rot gates

Tests that cannot fail are worse than no tests. Three cheap gates:

1. **Mutation check** — `tests/mutation.sh`, four seeds, each traceable to a Trap:

   | mutation | suite that MUST go red |
   |---|---|
   | delete the `if m0 == 'i'` line in `formatting.lua` | T1.4 (Trap 11) |
   | remove `'QuitPre'` from `immediate_save` | T1.2 |
   | `sessions.lua` `{ clear = true }` → `{}` | `test_autocmd_idempotency.lua` (Trap 2) |
   | `options.lua` `undofile = false` | T1.7 |

   **A negative control is mandatory** — a seed that mutates nothing and asserts the
   suite is *green*. Otherwise a gate where everything is red passes.

2. **Manifest** — every `tests/test_*.lua` on disk must appear in a `MANIFEST` table
   in `test_manifest.lua` with a one-line "what it proves". A new suite with no entry
   fails CI, so nobody can add a file that asserts nothing.

3. **Section liveness** — each `section 'N …'` in `stress.lua` records its result count
   at entry; the wrapper asserts every section emitted ≥ 1. Today a gutted section is
   invisible among 894 PASSes.

---

## 8. Execution order

Each step is independently reversible and ends with: plenary green, stress green,
`stylua --check .` clean, headless boot silent. **Run `stylua .` on touched files and
keep reformatting in its own `style:` commit** (Trap 1).

| # | Task | Why first |
|---|---|---|
| 1 | §2.1 CI gate · §2.2 revive `e2e` | nothing below can be trusted until the suite can go red |
| 2 | §3.1 lua formatting · §3.5 DAP gate · §3.3 PATH | real dead functionality, tiny diffs |
| 3 | T1.4 + T1.5 + T1.1 (data safety) | the untested behavior that loses code |
| 4 | §2.3 kill the permanent red · fix the two dead assertions | honest baseline |
| 5 | §3.2 biome install + `stop_after_first` · §5 health rows | re-enables D1/D2 and guards them |
| 6 | §3.4 `vtsls.config` · §3.6 ghost text + fuzzy pin | capability and UX wins |
| 7 | T4.1–T4.4 golden UI · §4.1 `%`-escape | UI correctness, then freeze it |
| 8 | §7 rot gates | stop the suite rotting again |

---

## 9. Risks and open questions

- **Verified on this host only.** Mason packages here are not the mason packages on
  your daily machine; a formatter present locally may be absent for you. §5's health
  rows exist precisely so this is visible instead of silent.
- **`require('vtsls').config {}` (3.4) is from upstream's README, not from a run I
  performed** — `~/.local/share/nvim/lazy/` was populated mid-analysis. Verify with
  `:VtsExec` after the change.
- **§3.7 (LSP capabilities) is a trade-off, not a free win** — wiring capabilities for
  all servers requires blink at `FileType`, which gives up its `InsertEnter` laziness.
  Left as a decision.
- **The `sloppy session prune` and `prettier --config` comment conflict (3.2)** need a
  decision on whether this config or a project's own `.prettierrc` wins.
- **`lazy-lock.json` is gitignored** (Trap 3), so CI's `lazy.sync()` takes whatever
  upstream shipped. Not addressed here; committing the lock contradicts the trap as
  written, and pinning versions spec-by-spec is noisy. Your call.
- **I changed nothing in the repo.** The only writes this session were `/tmp/opencode/*`
  probe scripts, `~/.local/opt/nvim` + `~/.local/bin/nvim`, and this plan.
