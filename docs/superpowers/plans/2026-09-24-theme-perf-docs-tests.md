# Theme picker, perf, docs, tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Themery with snacks.picker.colorschemes on `<leader>ty`, land measured perf wins only, update all docs, run heavy e2e tests, fix findings, open a PR, and report what/why.

**Architecture:** Single branch off `master`. Remove the Themery plugin spec and its keymaps/comments; bind `<leader>ty` on the existing snacks.nvim spec to `require('snacks').picker.colorschemes()`. Keep boot default `tokyonight-night` (Themery only restored after first `:Themery` open — boot never restored, so no persistence file). Sweep docs for Themery wording. Expand tests for the new key and absence of Themery. Run suites + stylua + headless boot. Open PR with gh.

**Tech Stack:** Neovim 0.12.5, lazy.nvim, snacks.nvim (colorschemes source confirmed in installed plugin), plenary.busted tests, stylua, gh CLI.

## Global Constraints

- Neovim floor: effectively 0.11+ (smoothscroll/winborder); CI uses v0.12.5.
- No new plugins; snacks.nvim already installed.
- No persistence file: Themery was cmd-lazy and only loaded state on first open; boot always used tokyonight-night (verified in themery `setup` → only runs when `:Themery` fires). Do not invent restore-on-boot unless measurement forces it.
- Default colorscheme remains `tokyonight-night` from init.lua.
- Conventional Commits; branch `feat/snacks-theme-picker` off `master`.
- ponytail: no unrequested abstractions; only measured perf changes.
- All user-facing docs must not claim Themery; may claim snacks picker and accurate persistence behavior.
- Tests: fail CI if string contains `Failed`; keep existing suite style (string match + live keymap asserts).

---

### Task 1: Branch + baseline measurements

**Files:** none (read-only measurements, git branch)

**Interfaces:**
- Consumes: clean `master` at origin.
- Produces: branch `feat/snacks-theme-picker`; baseline numbers in `/tmp/nvim-startup-baseline.log`.

- [ ] **Step 1: Create branch**

```bash
git -C /home/omar/.config/nvim checkout -b feat/snacks-theme-picker
```

Expected: `Switched to a new branch 'feat/snacks-theme-picker'`

- [ ] **Step 2: Capture startup baseline (3 runs)**

```bash
for i in 1 2 3; do
  nvim --headless --startuptime /tmp/nvim-st-$i.log +qa 2>/dev/null
done
cp /tmp/nvim-st-1.log /tmp/nvim-startup-baseline.log
tail -1 /tmp/nvim-st-*.log
```

Expected: three files; note last line total times for report (README claims ~185ms).

- [ ] **Step 3: Confirm clean boot**

```bash
nvim --headless '+qa' 2>&1 | tee /tmp/boot-before.log
```

Expected: empty or no `error|E5108|stack traceback`.

- [ ] **Step 4: Commit nothing yet**

No commit — measurements only.

---

### Task 2: Fail tests for Theme swap (TDD)

**Files:**
- Test: `tests/test_performance.lua` (extend themes describe)
- Test: `tests/test_keymaps_autocmds.lua` (extend)

**Interfaces:**
- Consumes: none yet (tests fail until Task 3).
- Produces: assertions that `<leader>ty` is snacks colorschemes and `themery` is absent.

- [ ] **Step 1: Add failing assertions in test_performance.lua themes block**

After existing themes `it(...)` in `tests/test_performance.lua` (~line 8–43), add:

```lua
    it('uses snacks.picker for <leader>ty, not themery', function()
      local themes_path = vim.fn.stdpath('config') .. '/lua/custom/plugins/themes.lua'
      local content = table.concat(vim.fn.readfile(themes_path), '\n')
      assert.is_falsy(content:match('themery'), 'themes.lua must not reference themery')
      assert.is_falsy(content:match('zaldih'), 'themery plugin must be removed')

      local keymaps = table.concat(vim.fn.readfile(vim.fn.stdpath('config') .. '/lua/config/keymaps.lua'), '\n')
      assert.is_falsy(keymaps:match('Themery'), 'keymaps.lua must not map Themery')

      local init = table.concat(vim.fn.readfile(vim.fn.stdpath('config') .. '/init.lua'), '\n')
      local snacks = init:match("'folke/snacks%.nvim'.-\n  },")
      assert.is_not_nil(snacks, 'snacks spec should exist')
      assert.is_truthy(snacks:find('<leader>ty', 1, true), 'snacks should own <leader>ty')
      assert.is_truthy(snacks:find('colorschemes', 1, true), '<leader>ty should open colorschemes picker')
    end)
```

- [ ] **Step 2: Add live keymap assertion in test_keymaps_autocmds.lua**

Append inside `describe`:

```lua
  it('<leader>ty is not Themery command', function()
    local map = vim.fn.maparg('<leader>ty', 'n')
    assert.is_truthy(map == '' or not map:match('Themery'), 'must not map to Themery')
  end)
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
nvim --headless -c 'lua require("plenary.busted").run("tests/test_performance.lua")' -c 'qa!' 2>&1 | tee /tmp/t-perf-fail.log
```

Expected: `Failed` present (snacks missing `<leader>ty` / themery still present).

- [ ] **Step 4: Commit failing tests**

```bash
git add tests/test_performance.lua tests/test_keymaps_autocmds.lua
git commit -m "test: require snacks colorschemes on leader ty, forbid themery"
```

---

### Task 3: Replace Themery with snacks colorschemes picker

**Files:**
- Modify: `lua/custom/plugins/themes.lua` (remove themery block + comments)
- Modify: `lua/config/keymaps.lua` (remove Themery map)
- Modify: `init.lua` snacks keys (~1264–1298)
- Modify: `lua/custom/ui/theme.lua` header comment
- Modify: `lua/config/autocmds.lua` line 32 comment
- Modify: `lua/custom/plugins/themes.lua` header comments
- Modify: `lazy-lock.json` (via `:Lazy sync` / remove themery entry)

**Interfaces:**
- Consumes: snacks.picker.colorschemes API (verified: `M.colorschemes` in sources.lua; live preview + confirm applies `vim.cmd.colorscheme`).
- Produces: `<leader>ty` → colorschemes picker; no themery dependency.

- [ ] **Step 1: In themes.lua, replace themery spec with nothing; fix header**

Replace lines 1–4 and delete lines 92–151 (themery block). Resulting file should end after flexoki + commented restore list. New header:

```lua
-- Themes — extra colorschemes (lazy until :colorscheme / preview).
-- Picker is <leader>ty via snacks.picker.colorschemes (init.lua snacks keys);
-- adding a plugin here is the only step to make a scheme available.
```

Update line 46 comment to drop "Themery scan":

```lua
  -- Trimmed 2026-09: 36 → 13 schemes (faster sync).
```

Update horizon comment (line 83) if it mentions Themery:

```lua
  -- -- Horizon — warm sunset (colors file errors on load; excluded from auto-load helpers)
```

- [ ] **Step 2: Remove Themery keymap from keymaps.lua**

Delete:

```lua
-- Switch themes with Themery (live preview + persistence).
vim.keymap.set('n', '<leader>ty', '<cmd>Themery<CR>', { desc = 'Switch [T]heme (Themery)' })
```

Leave a one-line pointer:

```lua
-- <leader>ty is snacks.picker.colorschemes — defined on the snacks spec in init.lua.
```

- [ ] **Step 3: Add key on snacks spec in init.lua**

In the snacks.nvim `keys = {` list (near `<leader>sf` etc.), add after the scratch/select keys or alphabetically near theme-ish keys:

```lua
        { '<leader>ty', function() require('snacks').picker.colorschemes() end, desc = 'Switch [T]heme (colorschemes)' },
```

- [ ] **Step 4: Fix comments that name Themery**

`lua/custom/ui/theme.lua` line 2:

```lua
-- Theme choice: snacks colorschemes picker (<leader>ty); boot default stays
-- tokyonight-night (see init.lua). This module: translucent floats + mode line numbers.
```

`lua/config/autocmds.lua` line 32:

```lua
-- Re-applied on ColorScheme so :colorscheme / snacks picker switches keep them.
```

`lua/custom/ui/spec.lua` line 48 — optional leave (generic `<leader>ty` mention is fine).

- [ ] **Step 5: Drop themery from lockfile / sync**

```bash
nvim --headless -c 'lua require("lazy").sync({wait=true})' -c 'qa' 2>&1 | tail -30
```

Confirm `lazy-lock.json` no longer lists themery (or edit lock if sync is flaky: remove the themery line only).

- [ ] **Step 6: Run new tests — expect PASS**

```bash
nvim --headless -c 'lua require("plenary.busted").run("tests/test_performance.lua")' -c 'qa!' 2>&1 | tee /tmp/t-perf.log
nvim --headless -c 'lua require("plenary.busted").run("tests/test_keymaps_autocmds.lua")' -c 'qa!' 2>&1 | tee /tmp/t-km.log
grep -q Failed /tmp/t-perf.log && exit 1 || true
grep -q Failed /tmp/t-km.log && exit 1 || true
```

Expected: no `Failed`.

- [ ] **Step 7: Verify picker loads headless**

```bash
nvim --headless -c 'lua require("lazy").load{plugins={"snacks.nvim"}}; local ok=pcall(require("snacks").picker.colorschemes); print(ok and "COLORS_OK" or "COLORS_FAIL")' -c 'qa' 2>&1
```

Expected: `COLORS_OK` (picker may not show headless — pcall success is enough).

- [ ] **Step 8: Commit**

```bash
git add lua/custom/plugins/themes.lua lua/config/keymaps.lua lua/custom/ui/theme.lua lua/config/autocmds.lua init.lua lazy-lock.json
git commit -m "feat: replace themery with snacks colorschemes picker on leader ty"
```

---

### Task 4: Documentation sweep (all docs)

**Files:**
- Modify: `SETUP.md`, `CHEATSHEET.md`, `nvim-cheatsheet.md`, `README.md`, `init.lua` header if needed, `TMUX.md`/`vim-motions-cheatsheet.md`/`doc/kickstart.txt` only if they mention themes/Themery

**Interfaces:**
- Consumes: Task 3 behavior.
- Produces: zero `Themery`/`themery` hits outside historical `docs/superpowers/plans/` and specs (historical plans may keep past-tense references; prefer leave historical plan untouched).

- [ ] **Step 1: Grep remaining refs**

```bash
rg -n 'Themery|themery' /home/omar/.config/nvim --glob '!docs/superpowers/**' --glob '!*.lock'
```

- [ ] **Step 2: Fix SETUP.md line 56**

```markdown
- **Themes**: `<leader>ty` opens the snacks colorschemes picker (list includes installed + lazy schemes). Boot default is `tokyonight-night`; the picker does not restore across restarts. To add one, add its plugin spec in `lua/custom/plugins/themes.lua`, then `:Lazy sync`.
```

- [ ] **Step 3: Fix CHEATSHEET.md line 29**

```markdown
| `<leader>ty` | Switch Theme (snacks colorschemes picker; boot default tokyonight-night) | snacks.nvim |
```

- [ ] **Step 4: Fix nvim-cheatsheet.md line 74**

```markdown
| `<leader>ty` | Switch theme (snacks colorschemes; not persisted across restarts) |
```

- [ ] **Step 5: README / init header**

- README: only touch if it names Themery or claims theme persistence incorrectly; keep ~185ms claim unless Task 5 numbers differ materially — then update measured number with real baseline.
- init.lua header line 35/77: leave `<leader>ty` as-is (key unchanged); section 5 "Theme persistence" → "Theme & Filetypes - docker-compose filetype" if it wrongly promises persistence:

```lua
   5.  Theme & Filetypes        - docker-compose filetype; theme pack in custom/plugins
```

- [ ] **Step 6: Re-grep until clean (code + current docs)**

```bash
rg -n 'Themery|themery' /home/omar/.config/nvim --glob '!docs/superpowers/**' --glob '!*.lock' || echo CLEAN
```

Expected: CLEAN or only intentional historical notes.

- [ ] **Step 7: Commit**

```bash
git add -u '*.md' init.lua README.md SETUP.md CHEATSHEET.md nvim-cheatsheet.md
git commit -m "docs: document snacks theme picker, correct persistence claims"
```

---

### Task 5: Performance + legacy API pass

**Files:**
- Possibly: none, or small init.lua / options if measurement shows a win
- Read: grep legacy APIs

**Interfaces:**
- Consumes: baseline from Task 1.
- Produces: after-measure log; either `perf:` commit or documented "no change needed".

- [ ] **Step 1: Re-measure startup**

```bash
for i in 1 2 3; do nvim --headless --startuptime /tmp/nvim-st-after-$i.log +qa 2>/dev/null; done
tail -1 /tmp/nvim-st-after-*.log
```

- [ ] **Step 2: Compare to baseline; only act if clear win available without redesign**

Document deltas in PR body. Optional micro-check: `:StartupTime` / lazy profile already in config. **Do not** restructure init.lua.

- [ ] **Step 3: Legacy API sweep**

```bash
rg -n 'vim\.loop|nvim_buf_get_option|nvim_get_option|buf_get_clients|diagnostic\.goto_next|vim\.tbl_isempty' /home/omar/.config/nvim/lua /home/omar/.config/nvim/init.lua /home/omar/.config/nvim/tests
```

Fix only true deprecated hits in **live** code (not tests asserting absence). Known clean pre-work; re-verify after edits.

- [ ] **Step 4: Commit if any fix**

```bash
git add -u
git commit -m "fix: update deprecated nvim APIs found in sweep"  # only if changes
```

If nothing to change, skip commit and note in PR.

---

### Task 6: Full test battery + stylua

**Files:** none new; run suites

**Interfaces:**
- Consumes: Tasks 3–5.
- Produces: green suites + stylua.

- [ ] **Step 1: Headless boot fail-on-error (CI mirror)**

```bash
nvim --headless -c 'qa' 2>&1 | tee /tmp/boot.log
if grep -qiE 'error|E5108|stack traceback' /tmp/boot.log; then echo FAIL; exit 1; fi
echo BOOT_OK
```

- [ ] **Step 2: Run every tests/test_*.lua like CI**

```bash
cd /home/omar/.config/nvim
fail=0
for f in tests/test_*.lua; do
  echo "=== $f ==="
  nvim --headless -c "lua require('plenary.busted').run('$f')" -c 'qa!' 2>&1 | tee /tmp/one.log
  if grep -q Failed /tmp/one.log; then fail=1; fi
done
exit $fail
```

Expected: exit 0; no `Failed`.

- [ ] **Step 3: stylua check**

```bash
stylua --check /home/omar/.config/nvim
```

Expected: clean (or fix formatting: `stylua /home/omar/.config/nvim` then commit `style: stylua`).

- [ ] **Step 4: Confirm no themery left in runtime plugin dir usage**

```bash
nvim --headless -c 'lua print(vim.inspect(require("lazy.core.config").plugins.themery ~= nil))' -c 'qa' 2>&1
```

Expected: `false`.

---

### Task 7: Subagent bug hunt

**Files:** none (review); fix only confirmed bugs

**Interfaces:**
- Consumes: green battery.
- Produces: optional fix commits; hunt report for PR.

- [ ] **Step 1: Dispatch subagent (explore/general) to hunt bugs**

Prompt must ask for: review of themes.lua/keymaps/init snacks keys/theme.lua/autocmds comment/docs claims; run headless boot + one suite if needed; list only **reproducible** issues with file:line; no style nits; research-only unless user asked fixes (user did: fix them).

- [ ] **Step 2: Apply only real fixes**

```bash
git add -u && git commit -m "fix: address findings from theme-picker bug hunt"
```

Skip if zero findings.

- [ ] **Step 3: Re-run full battery (Task 6 Step 2)** if any fix landed.

---

### Task 8: Push + PR + report

**Files:** PR body via gh

**Interfaces:**
- Consumes: green Task 6/7.
- Produces: PR URL; user-facing what/why report.

- [ ] **Step 1: Push**

```bash
git -C /home/omar/.config/nvim push -u origin feat/snacks-theme-picker
```

- [ ] **Step 2: Create PR**

```bash
gh pr create --repo oovaa/nvim-config --base master --head feat/snacks-theme-picker \
  --title "feat: snacks colorschemes picker, docs, tests" \
  --body "$(cat <<'EOF'
## What
- Replace themery.nvim with snacks.picker.colorschemes on <leader>ty
- Remove duplicate Themery keymap; key lives on snacks spec
- Correct docs that claimed Themery persistence (boot always tokyonight-night)
- Extend tests for snacks key + no themery
- Performance: baseline vs after (see notes); no speculative restructure

## Why
- Community-standard picker already used for all other pickes; drop a plugin
- Docs overstated persistence
- Align tests with picker stack

## How
- themes.lua: drop themery spec
- keymaps.lua: drop Themery map
- init.lua snacks keys: add colorschemes picker
- comment fixes in theme.lua / autocmds.lua

## Testing
- Headless boot CI mirror
- All tests/test_*.lua via plenary.busted
- stylua --check
- Headless pcall require('snacks').picker.colorschemes

## Risk / rollback
- Revert commit restores themery; <leader>ty is only user-visible break if snacks missing (snacks is core daily stack)
EOF
)"
```

Expected: PR URL printed.

- [ ] **Step 3: Write user report** (in chat): bullet list of every change and why, with PR link, baseline vs after ms, test results.

---

## Self-review (plan vs spec)

- Spec theme swap → Task 3 ✓
- No persistence (boot never restored) → Global Constraints + SETUP/CHEATSHEET wording ✓
- Perf measured-only → Task 5 ✓
- Legacy sweep → Task 5 ✓
- Heavy e2e + subagents → Tasks 6–7 ✓
- All docs → Task 4 + grep ✓
- PR + report → Task 8 ✓
- Placeholders: none left; all code/commands concrete ✓
