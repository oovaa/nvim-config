-- lua/plugins/completion.lua — SECTION 6.5: AUTOCOMPLETION
-- Plugins that provide code completion as you type.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- BLINK.CMP
  -- WHAT: Fast autocompletion engine (replaces nvim-cmp)
  -- TO CHANGE: Change keymap preset, sources, or appearance settings
  -- EFFECT: Shows completion menu as you type; Tab/S-Tab to navigate
  --         Sources: LSP completions, file paths, snippets
  -- LOADING: InsertEnter = loads only when you start typing
  {
    'saghen/blink.cmp',
    event = 'InsertEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine: expands snippet placeholders
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- Pre-made snippets for many languages/frameworks
          {
            'rafamadriz/friendly-snippets',
            config = function() require('luasnip.loaders.from_vscode').lazy_load() end,
          },
        },
        opts = {},
      },
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        -- PRESET OPTIONS:
        -- 'default'  = <C-y> to accept, Tab/S-Tab to navigate
        -- 'super-tab' = Tab to accept
        -- 'enter'    = Enter to accept
        -- 'none'     = no mappings
        -- SEE: `:help blink-cmp-config-keymap`
        preset = 'default',

        ['<Tab>'] = { 'accept', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'fallback' },
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 300,
          window = {
            border = 'rounded',
            max_width = 60,
            max_height = 15,
          },
        },
        list = {
          selection = { preselect = true, auto_insert = true },
        },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- See :h blink-cmp-config-fuzzy for more information
      -- fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },
}
