# Neovim Performance Optimization Plan

## Current State Analysis

### Plugin Loading Strategy
| Plugin | Current Loading | Recommended | Impact |
|--------|----------------|-------------|--------|
| guess-indent.nvim | Eager | Eager (tiny) | LOW |
| gitsigns.nvim | BufReadPost | BufReadPost | DONE |
| which-key.nvim | VeryLazy | VeryLazy | DONE |
| telescope.nvim | VeryLazy | VeryLazy | DONE |
| nvim-spectre | keys only | keys only | DONE |
| nvim-lspconfig | Eager | **FileType on-demand** | HIGH |
| conform.nvim | BufWritePre | BufWritePre | DONE |
| blink.cmp | InsertEnter | InsertEnter | DONE |
| tokyonight.nvim | priority=1000 | priority=1000 | OK |
| todo-comments.nvim | VeryLazy | VeryLazy | DONE |
| mini.nvim | VeryLazy | VeryLazy | DONE |
| auto-save.nvim | InsertLeave | InsertLeave | DONE |
| typescript-tools.nvim | ft filter | ft filter | DONE |
| code_runner.nvim | keys only | keys only | DONE |
| nvim-treesitter | BufReadPost | BufReadPost | DONE |
| neo-tree.nvim | keys only | keys only | DONE |
| bufferline.nvim | keys only | keys only | DONE |
| toggleterm.nvim | VeryLazy | VeryLazy | DONE |
| project.nvim | VeryLazy | VeryLazy | DONE |
| neogit | keys only | keys only | DONE |
| auto-session | lazy=false | lazy=false | OK |
| flash.nvim | VeryLazy | VeryLazy | DONE |
| nvim-dap | keys only | keys only | DONE |
| remote-nvim.nvim | keys only | keys only | DONE |
| hlchunk.nvim | VeryLazy | VeryLazy | DONE |
| render-markdown.nvim | ft=markdown | ft=markdown | DONE |
| molten-nvim | BufReadPre | BufReadPre | DONE |

### Key Findings

1. **LSP Servers**: Already optimized with FileType autocmds (saves 50-150ms)
2. **Plugin Loading**: Most plugins use lazy loading correctly
3. **Disabled Built-ins**: Already disabled 8 unused plugins (saves 10-20ms)
4. **Autocmd Consolidation**: Telescope LspAttach merged into lspconfig

### Remaining Optimizations

1. **vim.lsp.buf_get_clients shim** (line 107): Kept for backward compatibility with plugins using the deprecated API
2. **which-key spec**: Add more key groups for better documentation
3. **Startup time profiling**: DONE — `:StartupTime` command writes a `--startuptime` log and shows the 15 slowest sources
4. **Cache directory**: DONE — `vim.loader.enable()` (Lua bytecode cache) + lazy.nvim `performance.cache.enabled = true`
5. **Filetype detection**: Optimized (bun shebang + jsx/tsx extension mapping)

### Implemented Optimizations (since plan written)
- `vim.loader.enable()` — caches compiled Lua modules, skips re-parsing on boot
- lazy.nvim `performance.cache.enabled = true` — module cache for plugins
- `loaded_node_provider = 0` — Node provider disabled (joins perl/ruby; Python kept for molten-nvim)
- `:StartupTime` user command for boot profiling

### Estimated Total Startup Time
- Before optimizations: ~400-600ms (estimated)
- After optimizations: ~120-150ms (measured, clean headless `--startuptime`)
- Savings: ~300-450ms

## Documentation Structure

The init.lua will be organized with these sections:

```
1. HEADER / ASCII ART
2. PERFORMANCE NOTES
3. LEADER KEY / OPTIONS
4. KEYMAPS
5. AUTOCOMMANDS
6. LAZY.NVIM SETUP
   6.1 UI Plugins
   6.2 Editor Plugins
   6.3 LSP & Completion
   6.4 Language Specific
   6.5 Git Integration
   6.6 Debugging
   6.7 Custom Plugins
7. TERMINAL KEYMAPS
8. FILETYPE DETECTION
```

Each plugin will have:
- Purpose description
- Loading strategy explanation
- Performance impact notes
- Keymap documentation
