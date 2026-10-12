# Real tests + perf gate — plan

**Date:** 2026-10-12
**Base:** `master` @ `ff4d5bf` (up to date with origin)
**Goal:** fix the two real bugs; replace grep-the-source assertions with behavior
assertions; turn the useless 2000ms startup check into a real gate.

## Why

88 assertions pass today. Most don't run the config — they `readfile()` the
Lua source and `match()` on strings. Three real consequences, all measured:

1. **A real bug shipped through green tests.** `lua/plugins/ui.lua:52-65` sets
   `added`, `deleted`, `renamed` to `''`. Every added/deleted/renamed file
   renders iconless in the snacks picker. No test noticed — no test was looking
   at behavior.
2. **The startup gate catches nothing.** `tests/test_modular.lua:124` asserts
   `< 2000ms`. Actual is 72–95ms warm. A 20x regression stays green.
3. **Three modules have zero behavior coverage.** `config.sessions`,
   `config.terminal`, `config.runner` are only ever `assert.has_no.errors(require ...)`.

## Constraints (from AGENTS.md)

- `stylua --check .` is CI. Run `stylua .` on touched files; reformat gets its
  own `style:` commit.
- Every `nvim_create_autocmd` needs a named `group={clear=true}`.
- No new dependencies. Everything here uses what CI already installs (plenary
  busted, nvim 0.12.6).

## Non-goals

- Not touching startup architecture. mason's eager `rplugin.vim` is ~16ms of
  ~80ms, but deferring it risks breaking `:Mason` and is a separate decision.
- Not re-running the full 1459-line `tests/stress.lua` as part of each change.

---

## Part 1 — Real bugs

### 1.1 snacks git icons render empty

**File:** `lua/plugins/ui.lua:52-65`

`added`, `deleted`, `renamed` are `''`; `commit`, `ignored`, `unmerged` are a
bare space. Only `staged` (0xF00C) and `modified` (0xF040) were filled in.

**Fix:** fill every field with `vim.fn.nr2char(0x....)`, matching the existing
style and the file's own comment about emoji bytes getting stripped in transit.

**Constraint:** every codepoint used must be probed with `vim.fn.nr2char` and
confirmed non-empty before committing. Verified usable in 0xF00C–0xF045,
0xF067, 0xF05D, 0xF0E7, 0xF111. Candidates to probe: 0xF068 (removed),
0xF069 (modified), 0xF417 (tag), 0xF059 (eye-slash).

**Regression test:** assert every value in the resolved
`require('snacks').config.picker.icons.git` table is a non-empty string. This
is the assertion that would have caught it.

### 1.2 `:checkhealth config.health` errors

`lua/config/health.lua` resolves as module `config`, so the command is
`:checkhealth config`. Seven files tell the user to run `config.health`, which
errors with `No healthcheck found for "config/health" plugin`.

**Decision: fix the docs, not the file.** Moving it to
`lua/config/health/health.lua` would break `require('config.health')` in
`tests/test_polish.lua:33` and `tests/test_cleanup.lua:70` for no benefit.

**Files (6 edits, one token each):**
- `setup.sh:192` (the command that actually runs)
- `setup.sh:215` (the completion message)
- `SETUP.md:16`, `SETUP.md:22`, `SETUP.md:70`
- `AGENTS.md:22`

`README.md:51` already says plain `:checkhealth` — leave it.

**Regression test:** `tests/stress_child.lua:63-77` already runs
`checkhealth config` and asserts the `nvim-config` section appears. That test is
correct and is the guard. No new test needed.

---

## Part 2 — Performance tooling

### 2.1 Shared startup measurement

Add `M.startup_ms(runs)` to `lua/tests/helpers.lua`: shell out to
`nvim --headless --startuptime <tmp> +q` `runs` times, parse the `NVIM STARTED`
line, return `{ min, median, max }`. This replaces the inline shell + parse at
`tests/test_modular.lua:114-125`.

Parsing detail (gotcha, already hit): the log line is
`<clock> <self+sourced> <self>: <script>`. The total is field 1 on the
`NVIM STARTED` line. Use
`l:match '^(%S+)%s+%S+: %-%-%- NVIM STARTED %-%-%-$'`.

### 2.2 Real gate

New `tests/test_startup.lua`:
- 1 warm-up run (discarded — cold boot is ~132ms vs ~80ms warm)
- 3 measured runs
- assert **median < 400ms**

Why 400 and not 100: this host does 72–95ms, GitHub runners are several times
slower. 400ms still catches any real regression while leaving CI headroom.

The test also prints the top 5 entries by `self+sourced` so a failure is
diagnosable instead of just red.

### 2.3 Remove the old check

Delete the `startup stays fast` test from `tests/test_modular.lua`. The new file
supersedes it. `smoke-test.yml` globs `tests/test_*.lua`, so no CI edit needed.

---

## Part 3 — Real assertions

### 3.1 Delete `tests/test_cleanup.lua` (85 lines, 11 assertions)

Every assertion is migration archaeology — "telescope is gone", "noise is gone",
"fzf-native is gone". Once the migration is done these can never fail again.
They are pure maintenance cost. The four with *ongoing* intent (M1 actions-preview
backend, M2 `<leader>st`, F1 lazyredraw, F2 win32) get real equivalents below.

### 3.2 Rewrite `tests/test_polish.lua`

| old (fake) | new (real) |
|---|---|
| `:12-18` count `'CursorHold'` strings | `nvim_get_autocmds{event='CursorHold'}` has len 1, group `idle-upkeep` |
| `:20-25` `format_on_save` guard mentions `large_file_mode` | write a 2MiB temp file, open it, assert `vim.b.large_file_mode == 1` and `vim.bo.undofile == false` |
| `:27-35` two `c:match` greps | drop the greps, keep the two real asserts already in the file |
| `:37-41` `nvim_create_user_command('StartupTime'` grep | `vim.fn.exists(':StartupTime') == 2` |
| `:43-46` `treesitter%-start.-buftype` grep | create a scratch buffer, set ft, assert `vim.treesitter.get_parser(buf)` is nil |

### 3.3 Rewrite `tests/test_performance.lua`

Also removes the leftover `print('DEBUG test: ...')` lines at `:11-17`.

| old (fake) | new (real) |
|---|---|
| `:19-57` 13 theme names `match 'lazy%s*=%s*true'` | `require('lazy.core.config').plugins['catppuccin'].lazy == true`, and tokyonight `.priority == 1000` |
| `:59-73` snacks spec contains `<leader>ty` | `vim.fn.maparg('<leader>ty', 'n', false, true).callback` is a function |
| `:78-91` no `lspconfig` string in source | `not pcall(require, 'lspconfig')`; `require('vim.lsp.config').vtsls ~= nil` (+ the other 6 servers) |
| `:96-121` snacks modules `enabled = true` | `require('snacks').config.input.enabled == true` etc.; scroll/statuscolumn/toggle `~= true` |
| `:126-140` no bulk TSInstall loop | delete — folded into the startup gate |
| `:145-153` autotag has `ft =` | `plugins['nvim-ts-autotag'].ft` contains `typescriptreact`, `javascriptreact` |
| `:158-165` `vim.loader.enable` grep | delete — folded into the startup gate |
| `:170-189` colorizer/image `ft` blocks | `plugins['catgoose/nvim-colorizer.lua'].ft` contains `css` and `.event == nil` |
| `:194-207` keys inside snacks spec | `maparg` for `<leader>sf/sg/sd/e/fe` |

### 3.4 Rewrite `tests/test_qol.lua`

Every assertion moves to either `require('lazy.core.config').plugins[...]`
or `vim.fn.maparg(...)`:

- blame / refactoring / neotest / aerial / rest / bqf / grug-far:
  assert the plugin is in lazy's registry with the expected `.keys` / `.ft`
- `<leader>gb`, `<leader>rr`, `<leader>tr/ts/to`, `<leader>o`, `<leader>fr`:
  `maparg` returns a function
- `<leader>hr`: open an `http` buffer, assert the mapping exists **and is
  buffer-local** (this is what the old test was actually checking)
- the "must NOT contain" assertions (markdown-preview, dressing, spectre):
  delete — nothing can reintroduce a deleted spec without also failing the
  "plugin is in the registry" positives

### 3.5 `tests/test_modular.lua` — keep the grep, fix the rest

- `:9-34` init.lua-is-thin — **keep as grep.** This is a real architectural
  constraint ("plugin specs don't move back into init.lua"), and grep is the
  honest way to state it.
- `:60-95` 21 repos must appear in source — replace with: each repo key exists
  in `require('lazy.core.config').plugins`. Same guarantee, checked against the
  live registry instead of the text.
- `:97-103` three greps + one real assert — keep `vim.g.colors_name`, drop the greps.
- `:114-125` startup — delete, moved to `tests/test_startup.lua`.

### 3.6 New `tests/test_config_modules.lua` — the zero-coverage gap

**`config.sessions`** (helpers already exposed on `_G` at `sessions.lua:85-89`):
- `_G._builtin_session_file('/a/b')` == `_G._builtin_session_file('/a/b/')` — trailing slash normalizes
- `_G._builtin_session_file('/a/b')` ~= `_G._builtin_session_file('/a%b')` — the collision bug at `sessions.lua:28-32` cannot come back
- deterministic across two calls
- output ends in `.vim` and the basename ends in `-<8 hex>.vim`
- `_G._builtin_session_files('/nonexistent-dir')` == `{}` — the `fs_stat` guard at `sessions.lua:39`
- `nvim_get_autocmds{event='VimLeavePre', group='BuiltinSessions'}` has len 1 — AGENTS.md trap 2

**`config.terminal`** (no exports; test through the real keymaps):
- `maparg('<leader>tt')` is a function
- feedkeys `<Space>tt` → window count 1 → 2, and a buffer with
  `buftype == 'terminal'`
  **Note: assert `buftype`, not `filetype`.** A raw `:terminal` buffer has an
  empty filetype — already hit this while probing.
- feedkeys again → back to 1 window (toggle back works)
- `<leader>tf` → float window config width == `floor(columns * 0.85)`
  (the geometry at `terminal.lua:55-56`)

**`config.runner`** (no exports):
- `maparg('<leader>R')` and `maparg('<leader>rf')` are functions

---

## Ordering

One commit per step, conventional lowercase, `stylua .` before each.

1. `fix: checkhealth doc drift` — 6 files, 6 one-token edits
2. `fix: empty snacks git icons` — `lua/plugins/ui.lua` + the non-empty-icon
   regression test
3. `test: real startup gate with measured threshold` — `helpers.lua`,
   `tests/test_startup.lua`, delete old check
4. `test: replace grep assertions with behavior tests` — the bulk
5. `test: drop migration-archaeology assertions` — delete `test_cleanup.lua`

## Verification per step

```
for f in tests/test_*.lua; do
  nvim --headless --cmd "cd $PWD" -c "lua require('plenary.busted').run('$f')" -c 'qa!' 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' | tee /tmp/t.log
  sed -n 's/\x1b\[[0-9;]*m//g;p' /tmp/t.log | grep -qE 'Failed *:.*[1-9]|Errors *:.*[1-9]' && echo "FAIL $f"
done
stylua --check .
```

Plus the two manual checks that can't be automated:
- open a git repo with staged + deleted + renamed files, hit `<leader>sg`, confirm
  all three now have icons
- `:checkhealth config` still clean

## Risks

- **Terminal tests spawn real shells.** `<leader>tt` runs `vim.o.shell` and
  calls `startinsert`; in headless CI this is the least deterministic part of
  the suite. Mitigate: close the terminal buffer after each case and assert
  window count returns to baseline before the next one. If it proves flaky in
  CI, drop the feedkeys cases to `maparg` existence checks only and say so.
- **Startup threshold is a moving target on slow runners.** 400ms is set with
  headroom; if CI goes red on a slow GitHub host, raise the number rather than
  removing the gate.
- **`snacks` module loading is lazy.** `require('snacks').config` must resolve in
  the test's nvim instance. Being confirmed by probe before step 4 starts.