# Neovim Performance Optimization Plan (Config-Wide)

## Goal

Optimize the full editing experience, not only startup time:

- fast boot
- responsive typing/navigation
- stable behavior on large files
- predictable LSP/completion performance
- low UI overhead during normal workflows

## Baseline (Already in Config)

- `vim.loader.enable()` and lazy.nvim module cache enabled
- aggressive lazy-loading for most plugins
- provider and built-in plugin disables
- `:StartupTime` command for startup regression checks
- treesitter guarded against minified/large files

## New Optimizations Added

1. **Shared large-file threshold**
   - `vim.g.large_file_size = 1024 * 1024` (1 MiB) in `/home/runner/work/nvim-config/nvim-config/lua/config/options.lua`
   - Reused across runtime guards

2. **Runtime redraw optimization**
   - `lazyredraw = true` to reduce unnecessary intermediate redraw work during macros and scripted edits

3. **Long-line syntax cap**
   - `synmaxcol = 300` globally
   - additional `synmaxcol = 200` in large-file mode buffers

4. **Large-file mode autocmds**
   - auto-detect files larger than threshold
   - per-buffer safeguards:
     - disable swapfile
     - disable undofile
     - set manual folding
     - disable diagnostics updates in that buffer
   - skip cursor-hold diagnostic popup in large-file mode buffers

5. **Treesitter threshold alignment**
   - treesitter file-size guard now uses shared `vim.g.large_file_size`

## Optimization Tracks (Next Iterations)

### 1) Startup Path
- keep startup-critical set minimal
- regularly profile with `:StartupTime` after plugin additions

### 2) Editing Runtime
- keep expensive real-time features off in large-file mode
- tune debounce-sensitive options (`updatetime`, completion/lsp delays) based on observed usage

### 3) LSP + Completion
- keep LSP server attach on-demand by filetype
- avoid enabling expensive per-language extras globally
- monitor per-server responsiveness before adding new capabilities

### 4) UI/Rendering
- keep non-essential UI plugins on `VeryLazy`/event-based loading
- avoid heavy animations/effects by default

### 5) Search/Grep/Navigation
- prefer external fast backends (`rg`, `fd`)
- scope expensive workspace searches when possible

### 6) Validation Loop
- profile startup (`:StartupTime`)
- verify interactive responsiveness on:
  - normal code files
  - very large logs/minified files
  - LSP-heavy project buffers

## Success Criteria

- startup stays near current baseline
- no noticeable typing lag in normal projects
- large files remain navigable without freezing
- diagnostics/LSP remain responsive in day-to-day editing
