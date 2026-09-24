-- lua/plugins/formatting.lua — SECTION 6.4: FORMATTING
-- Plugins that auto-format your code on save.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

-- Shared values for plugin specs below.
-- conform fallback chain for all web languages (prettierd first, prettier second)
-- (ponytail: duplicated one-liner from init.lua's old `local prettier`;
-- a shared module isn't worth it for a single line.)
local prettier = { 'prettierd', 'prettier' }

---@module 'lazy'
---@type LazySpec
return {
  -- ACTIONS-PREVIEW: code-action picker with diff preview (same actions, readable UI)
  {
    'aznhe21/actions-preview.nvim',
    event = 'LspAttach',
    opts = { backend = { 'telescope' } },
  },

  -- CONFORM.NVIM
  -- WHAT: Auto-formats your code when you save (uses external formatters)
  -- TO CHANGE: Add/remove formatters in formatters_by_ft, or modify enabled_filetypes
  -- EFFECT: When you save a Python file, it runs ruff; JS/TS/JSON/HTML/CSS
  --         use prettier; markdown/yaml use prettier
  --         Press <leader>ff to format manually at any time
  -- LOADING: BufWritePre = loads only when you're about to save a file
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        -- ponytail: <leader>ff (not f) — bare `f` is a prefix for
        -- fe/fE/fg/fr, so a bare-f action delayed every one of them.
        '<leader>ff',
        function() require('conform').format { async = true } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      -- ponytail: true so formatter failures (e.g. broken json) notify
      -- instead of silently skipping the format
      notify_on_error = true,
      format_after_save = function(bufnr)
        -- Skip auto-format for large files (large_file_mode set by
        -- config/autocmds.lua); manual <leader>ff still works.
        if vim.b[bufnr].large_file_mode then return nil end
        -- TO CHANGE: Add or remove filetypes from this table
        -- EFFECT: Only files matching these types will auto-format after save
        local enabled_filetypes = {
          python = true,
          javascript = true,
          typescript = true,
          javascriptreact = true,
          typescriptreact = true,
          vue = true,
          json = true,
          jsonc = true,
          html = true,
          css = true,
          scss = true,
          less = true,
          markdown = true,
          yaml = true,
          graphql = true,
        }
        if enabled_filetypes[vim.bo[bufnr].filetype] then
          return { timeout_ms = 750 } -- ponytail: 500 was too tight for prettier on large files, 1000 felt laggy; 750 is middle
        else
          return nil
        end
      end,
      default_format_opts = {
        lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
      },
      formatters = {
        prettier = {
          prepend_args = { '--config', vim.fs.normalize '~/.config/nvim/prettier.config.json' },
        },
        prettierd = {
          stdin = true,
          prepend_args = { '--config=' .. vim.fs.normalize '~/.config/nvim/prettier.config.json' },
        },
      },
      -- You can also specify external formatters in here.
      formatters_by_ft = {
        python = { 'ruff_organize_imports', 'ruff_format' },
        -- Prefer prettier (matches .prettierrc in projects; biome ignores it)
        javascript = prettier,
        typescript = prettier,
        javascriptreact = prettier,
        typescriptreact = prettier,
        vue = prettier,
        json = prettier,
        jsonc = prettier,
        html = prettier,
        css = prettier,
        scss = prettier,
        less = prettier,
        graphql = prettier,
        markdown = prettier,
        yaml = prettier,
      },
    },
  },
}
