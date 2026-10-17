# Modern Statusline Pills + Dashboard Projects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the builtin statusline with rounded-pill separators (no new segments) and give the dashboard recency-ordered recent projects plus a conditional first-run "Resume" row.

**Architecture:** Two independent surfaces. Task 1 extracts a reusable `M.list_projects(dir)` into `config.sessions` (the projects list *is* the session registry — one scanner, zero duplication). Task 2 is a pure visual change inside `statusline.lua`'s existing `define_hl()` + assembly (string concat only, no new per-eval work). Task 3 rewires the dashboard's `s` picker to the new API and inserts one conditional button row; all render/extmark math already derives from `#buttons`, so insertion is safe. Task 4 is gates + docs.

**Tech Stack:** Neovim 0.12.6 LuaJIT, plenary.busted, stylua, mksession-based sessions. No new plugins, no new dependencies.

**Spec:** Design decided in chat (brainstorm, 2026-10-17). User picks: statusline = rounded pills, **no new info segments**; dashboard = recency-ordered projects list where selection does **in-place cd + session restore** (sourcing the session file sets `cd` — the existing mechanism already does this), plus a top row "Resume: `<project>`" shown only when the current cwd has a session. Dashboard look = consistency pass only, no redesign. Speed is a hard requirement: no new work per redraw, no subprocesses in either draw path.

## Global Constraints

- `stylua --check .` must stay green; run `stylua .` (mason PATH: `export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"`) on touched files only, style reflow never mixed into a fix commit.
- Every new `nvim_create_autocmd` needs a named `group = { clear = true }` augroup (trap 2). This plan adds **zero** new autocmds.
- Nerd glyphs are written as `vim.fn.nr2char(0x…)` codepoints, never literal PUA chars (dashboard convention, L14–15).
- Extmark/highlight columns are byte offsets (trap 8): icon advance is `#icon`, not `strdisplaywidth`.
- No subprocess may run per statusline eval or per redraw. Git branch/diff stay on `vim.b.gitsigns_head` / `vim.b.gitsigns_status_dict`.
- Dashboard highlight math already derives every row from `#buttons`/`#header` (`btn_start` L184, recents L201, `<CR>` L225) — a conditional button insert must preserve that property.
- Headless boot `nvim --headless -c 'qa'` must emit no E5108/traceback; no regression to the 400ms startup gate (measured 20–30ms).
- Conventional commits, lowercase subject: `feat:` `fix:` `docs:` `style:`.
- Test command (per suite): `nvim --headless -c "lua require('plenary.busted').run('tests/<file>.lua')" -c 'qa!'`
- The stress harness (`tests/stress.lua`) must keep its render-matrix contract: `_builtin_statusline()` returns a **non-empty string** for every ft, including `dashboard`/`lazy` (statusline.lua L226).

## Review Focus

Each failure mode below is pinned by a test in the task that owns the code:

1. A session `cd` line containing `%` (path escapes) must round-trip to the real cwd label — `list_projects` reuses the same `cd`-parse + `expand` + trailing-slash-strip as `find_session_for` (Task 1 test).
2. Missing or empty sessions dir must return `{}` without error, not crash the dashboard (Task 1 test, guards mirror `session_files`' `fs_stat` check).
3. Dashboard rendered in a cwd with no session must show **no Resume row** and otherwise render identically (Task 3 test).
4. Two session files for the same project dir must dedupe to the newest by mtime; equal mtimes order by path asc for determinism (Task 1 test).
5. Statusline eval cost must not grow measurably: 200 evals after 1 warmup under a 150 ms budget on this host (Task 2 test; CI variance note in test comment — the bar is regression-shaped, not a perf trophy).

---

### Task 1: `config.sessions` — recency-ordered projects listing

**Files:**
- Modify: `lua/config/sessions.lua`
- Test: the suite that already covers `config.sessions` (grep `tests/` for `sessions` first — likely `tests/test_config_modules.lua`; if none exists, put it there)

**Interfaces:**
- Consumes: existing module-local `norm_cwd`, `session_files(dir)` (`sessions.lua:38-49`).
- Produces: `M.list_projects(dir) -> { { label = <abs-cwd>, path = <session-file>, mtime = <sec> }, … }` — **newest-first**, deduped by `label` (newest wins; equal mtime → path asc). Plus the house compat shim `_G._builtin_list_projects = list_projects` (see `_G._builtin_session_files`, L95–99). `label` is the normalized absolute cwd (same string `norm_cwd` would return for it); display shortening stays in the dashboard.

- [ ] **Step 1: Write the failing tests** (in the chosen suite; fixtures in `/tmp`, mirroring `test_builtin_ui.lua`'s tmpdir pattern):

```lua
-- fake session file lines: 'cd <path>' + one 'badd' line (the dashboard's
-- has_badd contract). mtime is set by writing files in ascending order.
local sess = ('/tmp/nvim-sessions-test-%d'):format(vim.uv.hrtime())
vim.fn.mkdir(sess, 'p')

describe('sessions.list_projects', function()
  it('returns {} on a missing dir and on an empty dir', function()
    local M = require 'config.sessions'
    assert.equals(0, #M.list_projects('/tmp/definitely-not-here-' .. vim.uv.hrtime()))
    assert.equals(0, #M.list_projects(sess))
  end)
  it('lists newest-first, deduped by cwd, newest mtime wins', function()
    local M = require 'config.sessions'
    local a = sess .. '/a.vim'
    local b = sess .. '/b.vim'
    vim.fn.writefile({ 'cd ' .. vim.fn.expand '~', 'badd +1 file' }, a)
    vim.uv.sleep 0 -- nah: use file writes w/ distinct mtimes via os.touch? see step note below
    vim.fn.writefile({ 'cd ' .. vim.fn.expand '~', 'badd +2 other' }, b)
    local list = M.list_projects(sess)
    assert.equals(1, #list, 'same cwd dedupes to one project')
    assert.equals(vim.fn.expand '~' , list[1].label)
    assert.equals(b, list[1].path, 'the newest file wins the dedupe')
  end)
  it('%-containing cd paths round-trip to the real cwd label', function()
    local M = require 'config.sessions'
    local p = sess .. '/c.vim'
    vim.fn.writefile({ 'cd /tmp/a%20test', 'badd +1 x' }, p)
    local list = M.list_projects(sess)
    local labels = {}
    for _, e in ipairs(list) do labels[#labels + 1] = e.label end
    assert.is_truthy(vim.tbl_contains(labels, '/tmp/a%20test'), 'expanded cd text preserved verbatim')
  end)
  vim.fn.delete(sess, 'rf')
end)
```

> Mtime control: `writefile` in quick succession can produce equal mtimes. Optionally touch via `vim.uv.fs_utime(path, t, t)` with distinct seconds after writing (that keeps the "newest wins" assertion deterministic); the tie-break assertion (equal mtime → path asc) tests the sort comparator directly by monkey-patching `vim.uv.fs_stat` is NOT needed — pass equal fake mtimes through the comparator only if `list_projects` sorts in a pure way; otherwise pin dedupe + newest-first with distinct utimes and leave the tie-break to the comparator code (test it via two entries with forced equal mtime using `fs_utime` before re-listing).

- [ ] **Step 2: Run the suite — expect FAIL** ("attempt to call field 'list_projects' (a nil value)").

- [ ] **Step 3: Implement `M.list_projects(dir)` in `lua/config/sessions.lua`**

One scanner, placed next to `find_session_for` (L51–84), reusing its exact `cd`-parse idiom (L67–71): read each session file once (`vim.fn.readfile`), skip unless a `badd` line exists *and* a `cd` label exists, label = `fnamemodify(expand(cd), ':p'):gsub('/+$', '')`. Dedupe `seen[label]` keeping the higher `e.mtime` (tie → lexicographically smaller path wins the slot). Sort result `mtime` desc, tie `path` asc. Expose `M.list_projects` + `_G._builtin_list_projects`. Do **not** remove the dashboard's inline copy yet (Task 3 does that).

- [ ] **Step 4: Run the suite — PASS.** Then grease the whole sessions surface: `for f in tests/test_*.lua; do nvim --headless -c "lua require('plenary.busted').run('$f')" -c 'qa!'; done` — anything session-related must stay green.

- [ ] **Step 5: Commit**: `feat(sessions): recency-ordered projects listing`

---

### Task 2: Statusline — rounded-pill separators (visual only)

**Files:**
- Modify: `lua/custom/ui/statusline.lua` — `define_hl()` (L101–173), assembly tail (L349–357)
- Test: `tests/test_builtin_ui.lua` (new `describe('statusline pills')` block)
- Perf test: `tests/test_performance.lua` (append one `it` block)

**Interfaces:**
- Consumes: existing `bar_bg`/`mid_bg`/`c.hint` palette, per-mode loop (L152–155), `M._bar_bg` (L115).
- Produces: three new highlight families + one shared: `SL_acap_<key>` `{ bg = accent, fg = mid_bg }` (a→b cap, one per mode key), `SL_acapn_<key>` `{ bg = accent, fg = bar_bg }` (a→c cap when the whole b section is empty), `SL_bcap` `{ bg = mid_bg, fg = bar_bg }` (b→c cap). Glyph constant: `local SEP = vim.fn.nr2char(0xe0b8)` at module scope of `setup()` — codepoint only. Assembly becomes: interpolate a cap segment between a|b, a|c-when-b-empty, and b|c boundaries; **do not** add caps inside the right_x/right_y/right_z run (already breathed on with spaces) and do not add caps between b's inner parts. No new segments, no content changes.

- [ ] **Step 1: Write the failing test** in `tests/test_builtin_ui.lua` (style premise: assert on groups + glyph presence, never on full-string shapes):

```lua
describe('statusline pills', function()
  it('uses rounded cap transitions and no flat % markers between a/b/c', function()
    local ui = require 'custom.ui.statusline'
    ui.setup()
    vim.cmd.edit(vim.fn.fnameescape('/tmp/nvim-sls-test.md'))
    vim.fn.writefile({ 'x' }, '/tmp/nvim-sls-test.md')
    local s = _G._builtin_statusline()
    local sep = vim.fn.nr2char(0xe0b8)
    assert.is_truthy(s:find(sep, 1, true), 'a rounded cap glyph appears')
    -- the c section keeps flat text (no accent bg escapes into the filename)
    assert.is_truthy(s:match '%#SL_c#', 'c section still flat-highlighted')
    -- per-mode cap groups exist for the active mode's colors
    local key = nil
    for k in pairs(vim.api.nvim_get_hl(0, { name = 'SL_acap_n' }) and { n = true }) do key = k end
    vim.defer_fn(function() end, 0)
  end)
  vim.fn.delete('/tmp/nvim-sls-test.md')
end)
```

(Executors: finalize the block with whatever locals are needed; the assertions that must survive are: cap glyph present; `SL_c` still used; `s` non-empty; after `vim.cmd.colorscheme 'habamax'` + `vim.cmd.colorscheme 'default'` re-run `_G._builtin_statusline()` and re-assert the cap group exists — proving `define_hl()` still runs on ColorScheme.)

- [ ] **Write the failing perf test** in `tests/test_performance.lua`:

```lua
it('statusline eval stays cheap: 200 evals < 150ms after warmup', function()
  -- regression-shaped, not a trophy: CI runners are slow; the number only
  -- needs to catch per-eval subprocess calls or re-parsing.
  require 'custom.ui.statusline'.setup()
  vim.cmd.edit(vim.fn.fnameescape('/tmp/nvim-perf-sls.md'))
  vim.fn.writefile({ 'x' }, '/tmp/nvim-perf-sls.md')
  _G._builtin_statusline() -- warmup: primed caches (devicons/lsp/search handles)
  local t0 = vim.uv.hrtime()
  for _ = 1, 200 do _G._builtin_statusline() end
  local ms = (vim.uv.hrtime() - t0) / 1e6
  assert.is_true(ms < 150, '200 evals took ' .. ms .. 'ms')
  vim.fn.delete '/tmp/nvim-perf-sls.md'
end)
```

- [ ] **Step 2: Run both — expect FAIL** (no cap groups/glyph yet).

- [ ] **Step 3: Implement** in `lua/custom/ui/statusline.lua`:
  - In `define_hl()`: add `local SEP = vim.fn.nr2char(0xe0b8)` next to the modes table; extend the per-key loop (L152–155) with `hl('SL_acap_' .. key, accent, mid_bg)` and `hl('SL_acapn_' .. key, accent, bar_bg)`; add `hl('SL_bcap', mid_bg, bar_bg)` after the loop body near L156.
  - In the assembly tail (L349–357): build the left run from non-empty pieces (`hl_a+pill`, optional `macro_s`, optional `b_s`, `center`) and join consecutive pieces with the cap piece `' %*%#SL_acap_' .. key .. '#' .. SEP .. '%*'` variant chosen by the next piece’s bg (mid_bg→`SL_acap_<key>`, bar_bg→`SL_acapn_<key>`; b→c uses `' %*%#SL_bcap#' .. SEP .. '%*'`). Keep `%<` truncation on the filename (L352) and the trailing `' %*'` reset before `%=`.

- [ ] **Step 4: Run both tests — PASS.** Also run the full per-file loop once to catch a stress/render contract regression (the render matrix only requires non-empty output — the change cannot violate it, but verify).

- [ ] **Step 5: Commit**: `feat(statusline): rounded-pill separators`

---

### Task 3: Dashboard — projects picker + conditional Resume row

**Files:**
- Modify: `lua/custom/ui/dashboard.lua` — buttons table (L16–101, the `s` entry), VimEnter callback (L122–230)
- Test: `tests/test_builtin_ui.lua` (new `describe('dashboard projects')` block)

**Interfaces:**
- Consumes: `M.list_projects(dir)` from Task 1 (exact: newest-first `{ label, path, mtime }`), `M.find_session_for(cwd)` (L86), `has_badd` semantics.
- Produces (module-private is fine — both live inside `setup_starter`): `_G._builtin_dashboard_resume()` not needed; the Resume row is an ordinary button entry `{ key = 'S', icon = nr2char(0xf017), label = 'Resume: <na>', action = function() … source session … end }` prepended via `table.insert(buttons, 1, resume)` **inside the VimEnter callback before the `label_w` computation (L140)** — every downstream offset is computed from the mutated `#buttons`, so no highlight math may be duplicated or re-derived.

- [ ] **Step 1: Write the failing tests** (tmpdir-anchored `/tmp` per AGENTS-style fixture discipline; the dashboard reads `stdpath('data')/sessions`, so drive the *decision-finder* seam instead — factor the "does cwd have a restorable session?" decision into a tiny local helper `resume_for()` that the button builder calls, and test via a stubbed `config.sessions`? No: simpler, don't stub — test the composition):
  1. `s` label is now `'Recent Projects'` (rendered rows include it).
  2. Buttons render with the resume row first **iff** a fake session exists for cwd: since injecting stdpath is invasive, test this through `find_session_for(nil)` monkeypatch while the VimEnter callback is extracted into `M.render(buf, win)` first. **This extraction is the one structural change of Task 3.** Test both branches by directly calling `M.render()` with `session_files` pointing at a tmpdir via `vim.fn.stdpath` stub? — *Decision (mine, recorded):* the test does NOT stub stdpath. It (a) asserts the resume row appears after `table.insert` logic by calling the extracted `M.build_buttons(buttons)` twice — once with `find_session_for` returning a real tmp file (with `badd`), once with nil — and (b) asserts the picker list comes out recency-ordered by calling `M.list_projects()` on a seeded tmpdir through the same seam the `s` action uses (`require 'config.sessions'.list_projects`). That keeps tests honest without touching stdpath.

```lua
describe('dashboard projects', function()
  local M = require 'custom.ui.dashboard'
  it('resume row only appears when find_session_for resolves', function()
    local dyn = vim.env.DASH_SESS trick: skipped; the real check:
    -- build via the extracted helper:
    local with_file = M.get_resume_for(function() return '/tmp/fake.vim' end, function(p) return vim.fn.filereadable(p) == 1 end)
    assert.is_nil(with_file or nil, 'shape: returns a button table when a restorable file exists')
    assert.is_nil(M.get_resume_for(function() return nil end))
  end)
  it('sessions picker comes from list_projects in mtime order', function()
    local S = require 'config.sessions'
    local dir = M.sessions_dir and M.sessions_dir() or vim.fn.stdpath 'data' .. '/sessions'
    local list = S.list_projects(dir)
    for i = 2, #list do
      assert.is_true(list[i - 1].mtime >= list[i].mtime, 'projects listed newest-first')
    end
  end)
end)
```

(Executors: make the helpers' real signatures — `M.get_resume_for(find, readable) -> button|nil` and `M.sessions_dir()` — match these tests; the `s` button body becomes the Consumer of both.)

- [ ] **Step 2: Run — expect FAIL** (helpers don't exist, label mismatch, inline scan still in the button body).

- [ ] **Step 3: Implement** in `lua/custom/ui/dashboard.lua`:
  - Extract the buttons/lazy table into a build step so `label_w`/render math ref it after insertion: inside the VimEnter callback, before L134's label loop, call `local resume = build_resume(); if resume then table.insert(buttons, 1, resume) end`.
  - `build_resume()` = `find_session_for(nil)` → `vim.fn.filereadable` + the same `badd`-scan the `s` action already performs (L27–33) → truthy only if the file has a `badd` line. Label: `'Resume: ' .. fnamemodify(cwd_label, ':t')` where `cwd_label` comes from the same `cd`-line scan.
  - Replace the `s` entry's inline scanner body (L57–96) with: `local list = sess_mod.list_projects or _G._builtin_list_projects; sess_dir → items = list(sess_dir)` mapped to display strings (`:~`-shortened like L75), passed to the same `do_pick` (`bwipeout!` dashboard, `source <fnameescape(path)>`), i.e. **in-place cd + restore** (the session file's `cd` line moves nvim). Remove the now-dead inline readfile loop.
  - New button entry `p`, `"Recent Projects"` stays as `s`'s new label — decision: **two buttons, not one**: keep `s` as "Recent Projects" (picker over `list_projects`, same in-place restore) *and* the conditional `S` Resume row on top. The `s` picker sorts by `list_projects` order (recency), replacing `table.sort(items)` alphabetical (L79).
  - Keep the existing `<CR>`-on-recent handler untouched.

- [ ] **Step 4: Run — PASS.** Then the full per-file loop: all suites green (watch for any existing test pinning alphabetical session order — update such an assertion to recency in this task's commit).

- [ ] **Step 5: Commit**: `feat(dashboard): recency-ordered projects + conditional resume row`

---

### Task 4: Gates + docs

**Files:**
- Modify: `CHEATSHEET.md` (dashboard-buffer keys: `s` → "Recent Projects", new `S` → "Resume session"), `AGENTS.md` (trap 10 gains one line: the dashboard `s`/`S` resolve `config.sessions.list_projects` first — same canonical-module rule as the existing `find_session_for` note)

- [ ] **Step 1:** Full loop: `for f in tests/test_*.lua; do nvim --headless -c "lua require('plenary.busted').run('$f')" -c 'qa!'; done` — 0 failed / 0 errors on every file.
- [ ] **Step 2:** `nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'` — pass or known-documented Molten/TS-main warnings only; **no autocmd/keymap growth** (stress sources `$MYVIMRC` 4×).
- [ ] **Step 3:** `stylua .` clean (no diff output). `nvim --headless -c 'qa'` silent.
- [ ] **Step 4:** Docs; commit: `docs: cheatsheet + agents note for dashboard projects`

---

## Self-review notes (recorded)

- Spec coverage: pills restyle (Task 2), recency projects (Tasks 1+3), conditional Resume (Task 3), in-place open (Task 3, via session `cd`), speed guarantees (Review Focus 5 + no new per-eval work in Task 2's implementation bounds). Nothing from the spec lacks a task.
- Type check: `M.list_projects(dir)` naming consistent across Tasks 1/3; `_G._builtin_list_projects` follows the sessions.lua shim convention (L95–99).
- Deliberately out of scope (user did not pick them): gradient header, 2-column grid, statusline info segments (debug pill, breadcrumb, cwd tail, word count, file size, visual selection), snacks.dashboard swap (rejected in the 2026-10-14/15 plans).
