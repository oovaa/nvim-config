-- lua/plugins/editing.lua — SECTION 6.7: EDITING UTILITIES
-- Plugins that enhance text editing and manipulation.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- TODO-COMMENTS
  -- WHAT: Highlights TODO, FIXME, NOTE, WARN, etc. in comments with colors
  -- TO CHANGE: Remove this plugin if you don't want comment highlighting
  -- EFFECT: Words like TODO, FIXME, HACK get colored backgrounds in comments
  --         Helps you find important notes in your code
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
    cmd = 'TodoTelescope',
    keys = { { '<leader>st', '<cmd>TodoTelescope<cr>', desc = '[S]earch [T]odo comments' } },
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  -- MINI.NVIM
  -- WHAT: Collection of small, independent modules for text editing
  -- TO CHANGE: Add/remove mini.* modules in the config function
  -- EFFECT: Provides surround (gs prefix), ai textobjects, statusline
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'nvim-mini/mini.nvim',
    event = 'VeryLazy',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
        mappings = {
          around_next = 'aa',
          inside_next = 'ii',
        },
        n_lines = 500,
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- Use `gs` prefix instead of `s` to avoid conflict with flash.nvim
      -- - gsaiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - gsd'   - [S]urround [D]elete [']quotes
      -- - gsr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          replace = 'gsr',
          update_n_lines = 'gsn',
          suffix_last = 'l',
          suffix_next = 'n',
        },
      }
      -- gss<surrounding> to surround current line (e.g. gss" -> "line")
      vim.keymap.set('n', 'gss', 'gsa_', { remap = true })

       -- Auto-pair brackets, parens, quotes: when you type ( it adds ), etc.
       -- LazyVim-style: skip next char, skip inside treesitter strings.
        require('mini.pairs').setup {
          modes = { insert = true, command = true, terminal = false },
          skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
          skip_ts = { 'string' },
          skip_unbalanced = true,
          markdown = true,
        }

        -- Bracketed navigation: [b/]b buffers, [q/]q quickfix, [t/]t
        -- treesitter, [u/]u undo states... (zero new dep — ships inside
        -- mini.nvim). Diagnostic suffix disabled: [d/]d already jump with
        -- a float in lua/config/keymaps.lua. See :help mini.bracketed.
        require('mini.bracketed').setup { diagnostic = { suffix = '' } }

       -- Statusline is builtin (see lua/custom/ui/spec.lua).

       -- ... and there is more!
       --  Check out: https://github.com/nvim-mini/mini.nvim
     end,
   },

   -- TS-COMMENTS (#6 LazyVim gap): treesitter-aware commenting.
   -- Without it `gc` uses one commentstring per filetype; with it embedded
   -- languages get the right string (e.g. JS inside vue/svelte, lua docs).
   { 'folke/ts-comments.nvim', event = 'VeryLazy', opts = {} },

  -- AUTO-SAVE
  -- WHAT: Automatically saves your file when you leave insert mode or stop typing
  -- TO CHANGE: Remove this plugin if you prefer manual saving
  -- EFFECT: Your work is saved automatically - no need to press :w constantly
  -- LOADING: InsertLeave/TextChanged = loads when you type or leave insert mode
  {
    'okuuva/auto-save.nvim',
    cmd = 'ASToggle',
    event = { 'InsertLeave', 'TextChanged' },
    opts = {
      -- Save once per edit session, not per text change: TextChanged queues a
      -- write per keystroke burst, then BufWritePre -> prettier -> tsserver
      -- recheck thrashes the whole file.
      --
      -- immediate_save restores the stock safety net (esp. QuitPre): without
      -- it, edits made <1s before quitting hit the debounce timer and are
      -- silently lost.
      trigger_events = {
        immediate_save = { 'QuitPre', 'FocusLost', 'BufLeave', 'VimSuspend' },
        defer_save = { 'InsertLeave' },
        cancel_deferred_save = { 'InsertEnter' },
      },
    },
  },

  -- VTSLS (fast TypeScript LSP via @vtsls/language-server)
  -- WHAT: Replaces ts_ls/typescript-tools with direct IPC, optimized memory
  -- TO CHANGE: Remove if you prefer built-in ts_ls
  -- EFFECT: Faster completions, better Drizzle/NestJS inference, lower CPU
  -- LOADING: ft = only loads for JavaScript/TypeScript files
  {
    'yioneko/nvim-vtsls',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      -- Native equivalent of the old require('vtsls').lspconfig bridge:
      -- same cmd/filetypes/root priority, same settings (user's plus the
      -- updateImportsOnFileMove/enableMoveToFileCodeAction defaults lspconfig merged in).
      vim.lsp.config('vtsls', {
        cmd = { 'vtsls', '--stdio' },
        filetypes = { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx' },
        root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
        capabilities = capabilities,
        settings = {
          typescript = {
            updateImportsOnFileMove = 'always',
            suggest = { completeFunctionCalls = true },
            -- 'on' forces a package.json dependency scan on every completion;
            -- 'auto' only when an import statement needs it (much cheaper).
            preferences = { includePackageJsonAutoImports = 'auto' },
            tsserver = {
              maxTsServerMemory = 2048,
              -- inotify-based watching instead of polling node_modules:
              -- keeps tsserver CPU flat in large repos.
              watchOptions = {
                watchFile = 'useFsEvents',
                watchDirectory = 'useFsEvents',
                fallbackPolling = 'dynamicPriority',
              },
            },
          },
          javascript = {
            updateImportsOnFileMove = 'always',
          },
          vtsls = {
            autoUseWorkspaceTsdk = true,
            enableMoveToFileCodeAction = true,
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
                entriesLimit = 30,
              },
            },
          },
        },
      })
      vim.lsp.enable 'vtsls'
    end,
  },

  -- CODE RUNNER (builtin — replaces code_runner.nvim, zero loss via :terminal)
}
