-- lua/plugins/formatting.lua — SECTION 6.4: FORMATTING
-- Plugins that auto-format your code on save.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

-- Shared values for plugin specs below.
-- conform fallback chain for all web languages.
-- ponytail: `prettier` only. prettierd's node cold start measured 850-2300ms
-- inside nvim on this box (vs 270-470ms for plain prettier, and 316ms for a
-- *warm* prettierd), so it blew the save timeout on the first save of every
-- session and reported "Formatter failed" while formatting nothing. It also
-- leaves an orphan daemon per session. Re-add 'prettierd' in front of
-- 'prettier' if a node start ever gets under ~200ms here.
local prettier = { 'prettier' }

---@module 'lazy'
---@type LazySpec
return {
  -- ACTIONS-PREVIEW: code-action picker with diff preview (same actions, readable UI)
  {
    'aznhe21/actions-preview.nvim',
    event = 'LspAttach',
    opts = { backend = { 'snacks' } },
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
      -- ponytail: format_on_save (sync), not format_after_save (async).
      -- The async path snapshots the buffer, formats in the background, and
      -- silently discards the result if you typed meanwhile (concurrent
      -- modification) — with auto-save writing every ~1s, fast typing meant
      -- formatting never stuck and looked "undone". Sync formats in
      -- BufWritePre before the write lands: one write, no race. Cost: saves
      -- block for the formatter run (ruff is ms, prettier ~300ms warm).
      format_on_save = function(bufnr)
        -- Skip auto-format for large files (large_file_mode set by
        -- config/autocmds.lua); manual <leader>ff still works.
        if vim.b[bufnr].large_file_mode then return nil end
        -- Skip auto-format while mid-typing: auto-save's FocusLost/BufLeave
        -- triggers write the buffer from inside insert mode, and a formatter
        -- rewriting a half-typed line (reflow + cursor jump) is worse than
        -- saving it raw. Same for Select (s*) and Replace (R*): a reflow
        -- under an active snippet placeholder shifts the selection anchors,
        -- so the next keystroke replaces more than the placeholder and eats
        -- code. (Select is s/S/^S — Lua is case-sensitive and ^S is byte
        -- 19, so all three are listed.) Next save outside insert formats
        -- it; <leader>ff formats on demand. ('ni*' = i_CTRL-O — :h mode().)
        local mode = vim.api.nvim_get_mode().mode
        local m0 = mode:sub(1, 1)
        if m0 == 'i' or mode:sub(1, 2) == 'ni' or m0 == 's' or m0 == 'S' or m0 == 'R' or m0 == '\19' then return nil end
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
          -- ponytail: nginx is NOT auto-formatted. conform's nginxfmt backend
          -- is a python package that mason cannot install here (no ensurepip),
          -- so listing it in enabled_filetypes only produced a silent no-op.
          -- `pip install nginx-config-formatter` enables it; the mapping below
          -- is already in place, so add `nginx = true` back then.
          nginx = false,
        }
        if enabled_filetypes[vim.bo[bufnr].filetype] then
          -- ponytail: 750 was too tight for prettier on large files, 1000 felt laggy;
          -- but 750 also timed out on prettier's ~470ms cold start, so the first
          -- save of a session silently skipped formatting. 2000 only costs you
          -- when the formatter is genuinely slow.
          return { timeout_ms = 2000 }
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
        -- markdown was in enabled_filetypes but missing here, so auto-format
        -- silently did nothing for it
        markdown = prettier,
        yaml = prettier,
        graphql = prettier,
        nginx = { 'nginxfmt' },
      },
    },
  },
}
