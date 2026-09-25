-- lua/plugins/ui.lua — SECTION 6.9: UI COMPONENTS
-- Plugins that add visual UI elements to Neovim.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- NEO-TREE
  -- WHAT: A file explorer that shows your project's file tree
  -- TO CHANGE: Modify filesystem.hijack_netrw_behavior or keybindings
  -- EFFECT: fallback explorer — daily <leader>e/fe/fE moved to snacks.explorer
  --         (faster, no plenary). :Neotree still works; delete next release.
  -- LOADING: cmd = only loads on explicit :Neotree
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    opts = {
      window = {
        mappings = {
          -- ponytail: nil-guard for upstream toggle_auto_expand_width crash
          -- (passes nil last_user_width to nvim_win_set_width when the
          -- pre-render path never recorded one). Pre-seed, then delegate.
          ['e'] = function(state)
            if state.window.last_user_width == nil then state.window.last_user_width = require('neo-tree.utils').resolve_width(state.window.width) end
            require('neo-tree.sources.common.commands').toggle_auto_expand_width(state)
          end,
        },
      },
      filesystem = {
        hijack_netrw_behavior = 'open_default',
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          always_show = { '.env', '.gitignore', '.github' },
        },
      },
    },
  },

  -- BUILTIN UI (replaces bufferline/lualine/alpha — no plugin, zero loss)
  -- statusline/tabline/dashboard via lua/custom/ui/spec.lua (pure nvim 0.12)
  -- keys S-h/S-l/<leader>bd preserved via builtin :bprev/:bnext/:bdelete
  -- (ponytail: mini.icons spec deleted — zero requires anywhere; neo-tree
  -- uses nvim-web-devicons, which-key degrades gracefully without it.)

  -- SNACKS.NVIM (#1 LazyVim gap)
  -- The swiss-army knife: picker, scratch buffer, dashboard,
  -- notifier, terminal navigation, big-file, quick-file, words.
  -- LazyVim wires it into which-key, lualine, lsp, treesitter, etc.
  -- We keep it minimal here; expand opts as you adopt features.
  {
    'folke/snacks.nvim',
    -- ponytail: keys-only meant notifier/input stayed dead until first keypress
    -- (only loaded transitively via noice); VeryLazy makes it self-sufficient.
    event = 'VeryLazy',
    opts = {
      indent = {
        enabled = true,
        -- ponytail: chunk box replaces hlchunk.nvim (deleted); chars match the old chunk spec
        chunk = {
          enabled = true,
          char = { corner_top = '╭', corner_bottom = '╰', horizontal = '─', vertical = '│', arrow = '─' },
        },
        -- ponytail: scope follows the code block, not the cursor column;
        -- without this the chunk jumps to the outer scope on col-0/blank lines
        -- edge=false: TS field-climbing merged try/catch/else into one block
        -- (with_edge walks body/handler fields up to try_statement/if_statement)
        scope = { cursor = false, edge = false },
      },
      input = { enabled = true },
      notifier = { enabled = true },
      -- ponytail: picker + explorer own daily search/files (migrated from
      -- telescope/neo-tree — no plenary, faster; telescope stays cmd-only
      -- for vim_bookmarks + ui-select, neo-tree cmd-only as fallback).
      picker = {
        enabled = true,
        -- ponytail: show dotfiles (.env, .gitignore) + gitignored in the
        -- explorer by default; toggle at runtime with `h` / `i`.
        -- ponytail: build/dependency dirs stay out of every picker (fd/rg/tree
        -- all take the same glob; `i` toggling ignored can't bring them back).
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            exclude = {
              'node_modules',
              'dist',
              'build',
              'out',
              'target',
              'vendor',
              'coverage',
              '__pycache__',
              '.venv',
              '.next',
              '.nuxt',
              '.git',
              '.turbo',
              '.pytest_cache',
            },
          },
          files = {
            hidden = true,
            ignored = true,
            exclude = {
              'node_modules',
              'dist',
              'build',
              'out',
              'target',
              'vendor',
              'coverage',
              '__pycache__',
              '.venv',
              '.next',
              '.nuxt',
              '.git',
              '.turbo',
              '.pytest_cache',
            },
          },
          grep = {
            exclude = {
              'node_modules',
              'dist',
              'build',
              'out',
              'target',
              'vendor',
              'coverage',
              '__pycache__',
              '.venv',
              '.next',
              '.nuxt',
              '.git',
              '.turbo',
              '.pytest_cache',
            },
          },
        },
        -- ponytail: builtin `yank` copies the full item text
        -- (diagnostics items carry the untruncated message); free in both wins.
        win = {
          input = { keys = { ['<c-y>'] = { 'yank', mode = { 'i', 'n' } } } },
          list = { keys = { ['<c-y>'] = 'yank' } },
        },
      },
      explorer = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = false }, -- ponytail: vim.o.smoothscroll owns smooth scrolling; snacks scroll fought it
      scratch = { ft = 'markdown' }, -- ponytail: always markdown, never inherits python/js ft (no pyrefly/eslint in scratch)
      statuscolumn = { enabled = false },
      toggle = { enabled = false },
      words = { enabled = true },
    },
    keys = {
      { '<leader>.', function() require('snacks').scratch() end, desc = 'Toggle Scratch Buffer' },
      { '<leader>S', function() require('snacks').scratch.select() end, desc = 'Select Scratch Buffer' },
      {
        '<leader>n',
        function()
          if require('snacks.config').picker and require('snacks.config').picker.enabled then
            require('snacks').picker.notifications()
          else
            require('snacks').notifier.show_history()
          end
        end,
        desc = 'Notification History',
      },
      { '<leader>un', function() require('snacks').notifier.hide() end, desc = 'Dismiss All Notifications' },
      -- Picker: daily search, migrated from telescope (keys identical).
      { '<leader>sh', function() require('snacks').picker.help() end, desc = '[S]earch [H]elp' },
      { '<leader>sk', function() require('snacks').picker.keymaps() end, desc = '[S]earch [K]eymaps' },
      { '<leader>sf', function() require('snacks').picker.files() end, desc = '[S]earch [F]iles' },
      { '<leader><leader>', function() require('snacks').picker.files() end, desc = '[S]earch [F]iles' },
      {
        '<leader>sp',
        function()
          local root = vim.fs.root(0, { '.git', '_darcs', '.hg', '.bzr', '.svn', 'Makefile', 'package.json' }) or vim.uv.cwd() or vim.fn.getcwd()
          require('snacks').picker.files { cwd = root }
        end,
        desc = '[S]earch [P]rojects (builtin root)',
      },
      { '<leader>ss', function() require('snacks').picker() end, desc = '[S]earch [S]elect picker' },
      { '<leader>sw', function() require('snacks').picker.grep_word() end, mode = { 'n', 'x' }, desc = '[S]earch current [W]ord' },
      { '<leader>sg', function() require('snacks').picker.grep() end, desc = '[S]earch by [G]rep' },
      { '<leader>sd', function() require('snacks').picker.diagnostics() end, desc = '[S]earch [D]iagnostics' },
      { '<leader>sr', function() require('snacks').picker.resume() end, desc = '[S]earch [R]esume' },
      { '<leader>s.', function() require('snacks').picker.recent() end, desc = '[S]earch Recent Files ("." for repeat)' },
      { '<leader>sc', function() require('snacks').picker.commands() end, desc = '[S]earch [C]ommands' },
      { '<leader>/', function() require('snacks').picker.lines() end, desc = '[/] Fuzzily search in current buffer' },
      { '<leader>s/', function() require('snacks').picker.grep_buffers() end, desc = '[S]earch [/] in Open Files' },
      { '<leader>sn', function() require('snacks').picker.files { cwd = vim.fn.stdpath 'config' } end, desc = '[S]earch [N]eovim files' },
      { '<leader>ls', function() require('snacks').picker.lsp_symbols() end, desc = '[L]ist [S]ymbols in file' },
      { '<leader>lS', function() require('snacks').picker.lsp_workspace_symbols() end, desc = '[L]ist [S]ymbols in workspace' },
      -- Explorer trial (neo-tree kept cmd-only one release as fallback).
      { '<leader>e', function() require('snacks').explorer() end, desc = 'Toggle File [E]xplorer' },
      { '<leader>fe', function() require('snacks').explorer() end, desc = '[F]ile [E]xplorer' },
      { '<leader>fE', function() require('snacks').explorer.reveal() end, desc = '[F]ile [E]xplorer (reveal)' },
      -- Theme picker (snacks.picker.colorschemes, LazyVim default — live
      -- preview included); choice persists via custom/ui/theme.lua.
      -- ponytail: keys entry (not keymaps.lua) so snacks lazy-loads on first press.
      { '<leader>ty', function() require('snacks').picker.colorschemes() end, desc = 'Switch [T]heme (picker)' },
    },
  },

  -- NVIM-LINT (#4): async linters complement conform (format) — oxlint/ruff via mason
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        -- ponytail: oxlint over eslint — ms per save, no daemon; type-aware rules don't fire (that's the RAM hog)
        javascript = { 'oxlint' },
        typescript = { 'oxlint' },
        javascriptreact = { 'oxlint' },
        typescriptreact = { 'oxlint' },
        python = { 'ruff' },
      }
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        callback = function() pcall(lint.try_lint) end,
      })
    end,
  },

  -- SNACKS SCRATCH BUFFERS: create a named scratch via :lua Snacks.scratch { name = 'notes' }
  -- Named scratches persist separately; pick all with <leader>S

  -- ============================================================================
  -- SECTION 6.10: SESSIONS (builtin — replaces auto-session, zero loss)
  -- ============================================================================
  -- (builtin session handling lives in lua/config/sessions.lua)
}
