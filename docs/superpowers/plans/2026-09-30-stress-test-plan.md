# Stress-test plan — nvim config (2026-09-30)

One script: `tests/stress.lua` (+ `tests/stress_child.lua`, `tests/stress_harness.lua`).
Run headless with the real config loaded.

```
nvim --headless -c 'luafile tests/stress.lua' -c 'qa!'
```

Exit code 0 = all green, 1 = at least one failure. Full report written to
`tests/stress-report.md`; short summary on stdout. ~2 minutes.

## Areas (17)

1. **Syntax** — `loadfile()` every `.lua` under the config root.
2. **Warm-up** — load the whole plugin tree so later checks see real state.
3. **Options** — every option `lua/config/options.lua` documents is really set,
   plus the provider/builtin-plugin disables and the notify throttle.
4. **Keymap sanity** — duplicate lhs, unreachable prefixes, which-key groups.
5. **Autocmds** — fire each event by hand; every handler must be error-free.
6. **Filetypes** — docker-compose / compose / composer (negative control) /
   Dockerfile / nginx.conf / bun shebangs (positive + negative).
7. **Statusline** — render in 20 buffer states, evaluate the format string with
   `nvim_eval_statusline`, and validate every clickable `%N@…@` buffer index.
8. **Tabline** — same, plus the click handler with valid/invalid buffers.
9. **Diagnostic cache** — counts refresh on `DiagnosticChanged`, survive a second
   window, and are dropped on `BufWipeout`.
10. **Sessions** — write/find/restore roundtrip, suppressed dirs, empty-exit
    guard, hostile cwds (spaces, unicode, `%`, trailing slash, missing).
11. **Theme** — save/restore roundtrip, bogus name, and a real fresh-start child.
12. **Runner** — the command actually spawned, read from the `term://` buffer name.
13. **Write path** — auto-mkdir, large-file mode, conform on save (polled).
14. **LSP** — two-buffer attach, the LspAttach augroup surviving its own run,
    mason package names, server binaries, jsonls attach.
15. **Conform** — `enabled_filetypes` ⊆ `formatters_by_ft`, binaries available.
16. **Integrity** — every `require()` resolves, every command the config binds to
    exists, nvim-treesitter branch vs. the plugins written for `master`.
17. **Reload + misc** — `<leader>ur` idempotency, `:SudoWrite`, `:DiffOrig`,
    clipboard, undo file, `%`/yank/paste sanity.

Child sections (pristine nvim, or they hang the run): `boot` (`:messages` +
`:checkhealth config`), `keymaps` (every non-default mapping invoked),
`terminal` (`tt`/`tf`/`fg`/`C-\` state machine), `dashboard` (render, highlight
extmarks, `<CR>` row math), `themes` (all colorschemes on rtp).

## Ground rules

- Every test is `xpcall`'d with a traceback; one crash never aborts the run.
- Children stream results to a file as they go, so a child that dies mid-section
  still reports what it finished plus the key it died on.
- Each test restores what it touched (buffers, options, autocmds) so ordering
  cannot mask a failure.
- No network, no plugin installs. Missing binaries are warnings, not failures.

