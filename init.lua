--[[

================================================================================
NEOVIM CONFIGURATION GUIDE
================================================================================

This is your Neovim configuration. Every setting is explained so you can
understand what it does, change it safely, and know the effect of your changes.

7. vim.loader bytecode cache enabled (re-parse avoidance)
8. lazy.nvim module cache enabled (enabled = true)
9. Node provider disabled (joins perl/ruby)


MEASURED STARTUP TIME: ~120ms (clean headless --startuptime; was ~400-600ms)

GETTING STARTED:
  1. Read through this file top to bottom
  2. Try changing a setting and see what happens
  3. Use `:help <option>` to learn more about any option
  4. Use `:Telescope keymaps` to see all available keybindings

LEADER KEY: <Space> (Section 2)

SECTION INDEX:
  1.  Provider Disables        - Disable unused language providers
  2.  Core Options             - lua/config/options.lua (leader key, editor settings)
  3.  Keymaps                  - lua/config/keymaps.lua (global mappings)
  4.  Autocommands             - lua/config/autocmds.lua (global autocmds)
  5.  Theme & Filetypes        - Theme persistence, docker-compose filetype
  6.  Plugins (lazy.nvim)      - All plugin configurations
     6.1  UI & Visual         - Indent, git signs, which-key, telescope
     6.3  LSP                 - Language servers, Mason, vtsls
     6.4  Formatting          - Auto-format on save
     6.5  Completion          - Autocompletion (blink.cmp)
     6.6  Colorscheme         - TokyoNight theme
     6.7  Editing Utilities   - Todo, mini.nvim, auto-save
     6.8  Syntax              - Treesitter highlighting
     6.9  UI Components       - File explorer, tabs, terminal
     6.10 Sessions           - Session save/restore
     6.11 Navigation         - Flash jumps
     6.12 Custom Plugins     - lua/custom/plugins/init.lua
     6.13 Python Dev         - Debugger (DAP)
     6.14 Bookmarks         - Mark & jump to lines
     6.15 Visual            - Indent lines, markdown, colorizer

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Key Mappings Reference:
----------------------
  Leader key: <Space>

  Search:      <leader>s{f,g,p,w,/,n,r,.,c,d,k}  (<leader><leader> = find files)
  Terminal:    <leader>t{t,f,m,1,2,3,n}
  Git:         <leader>fg (LazyGit)
  Debug:       <leader>d{b,c,i,o,O,r,l,t,n,f,s}
  LSP:         K(grn,a,D), grr, gri, grd, grt, gO, gW
  Symbols:     <leader>ls, <leader>lS
  Bookmarks:   <leader>mt/mc/mj/mk/mb
  Molten:      <leader>m{i,l,v,r,h,d,n,p,o}
  Theme:       <leader>ty
  Profiling:   :StartupTime

--]]

-- ============================================================================
-- BYTECODE CACHE (fastest, safest startup win)
-- Caches compiled Lua modules so Neovim doesn't re-parse every file on boot.
-- Requires Neovim >= 0.9. Pairs well with lazy.nvim's own module cache below.
-- ============================================================================
vim.loader.enable()

-- ponytail: node shim removed; tsserver_path is set explicitly in
-- typescript-tools config, and the old node->bun shim broke node formatters
-- (prettierd/prettier run via real linuxbrew node now).

-- ============================================================================
-- SECTION 1: PROVIDER DISABLES
-- ============================================================================
-- WHAT: Neovim can connect to external language tools (Python, Ruby, Perl,
--        Node.js) called "providers". Each adds startup time even if unused.
--        Disabling them speeds up startup by ~5-10ms each.
--
-- TO CHANGE:
--   - If you use Python plugins (like molten-nvim), keep python3 enabled
--   - If you use Ruby plugins, remove the ruby line
--   - If you use Perl plugins, remove the perl line
--   - Check active providers: `:checkhealth provider`
--
-- EFFECT:
--   Setting a provider to 0 = disabled (faster startup, but plugins needing it break)
--   Removing the line = provider enabled (slower startup, but plugins can use it)
-- ============================================================================
-- Core config lives in lua/config/:
--   config/options.lua  — provider disables, leader key, editor options, diagnostics
--   config/keymaps.lua  — global keymaps (plugin keymaps stay with their specs)
--   config/autocmds.lua — global autocommands
require 'config.options'
require 'config.keymaps'
require 'config.autocmds'

-- :StartupTime — profile boot time and show the 15 slowest sources.
-- Writes a --startuptime log and prints the tail so you can spot regressions.
vim.api.nvim_create_user_command('StartupTime', function()
  local log = vim.fn.stdpath 'cache' .. '/startup.log'
  vim.cmd('!nvim --startuptime ' .. log .. ' +q && sort -k2 ' .. log .. ' | tail -n 15')
end, { desc = 'Profile Neovim startup time' })

-- docker-compose files get the docker-compose LSP (docker_compose_language_service)
vim.filetype.add {
  pattern = {
    ['docker%-compose.*%.ya?ml'] = 'yaml.docker-compose',
    ['compose.*%.ya?ml'] = 'yaml.docker-compose',
  },
}

-- THEME: persistence + mode-colored line numbers live in custom/ui/theme.lua.
pcall(function() require('custom.ui.theme').setup() end)

-- ============================================================================
-- SECTION 6: LAZY.NVIM PLUGIN MANAGER
-- ============================================================================
-- WHAT: Lazy.nvim manages all your plugins. It handles downloading, updating,
--        loading, and configuring them automatically.
--
-- HOW PLUGINS ARE LOADED:
--   Plugins can be loaded in different ways for performance:
--
--   event = 'VeryLazy'          Load after UI is ready (non-critical plugins)
--   event = 'InsertEnter'       Load only when entering insert mode
--   event = 'BufReadPost'       Load only when opening a file
--   ft = { 'python', 'lua' }    Load only for specific filetypes
--   cmd = { 'Telescope' }       Load only when running specific commands
--   keys = { '<leader>f' }      Load only when specific keymaps are pressed
--   lazy = false                Load immediately at startup (use sparingly!)
--
-- HOW TO ADD A NEW PLUGIN:
--   1. Find the plugin on GitHub (e.g., 'user/plugin-name')
--   2. Add it to the list below with the appropriate loading strategy
--   3. Run `:Lazy sync` to install it
--
-- USEFUL COMMANDS:
--   :Lazy          Open the Lazy.nvim UI (see all plugins, update, clean)
--   :Lazy sync     Update all plugins
--   :Lazy clean    Remove unused plugins
--   :Lazy profile  See plugin load times
--
-- SEE: `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim
-- ============================================================================

-- Bootstrap lazy.nvim (auto-install if not present)
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- Shared values for plugin specs below.
-- conform fallback chain for all web languages (prettierd first, prettier second)
local prettier = { 'prettierd', 'prettier' }

-- ============================================================================
-- PLUGIN LIST
-- ============================================================================
-- All your plugins are listed below. Each plugin has:
--   - Plugin name (GitHub shorthand)
--   - Loading strategy (event, cmd, keys, ft, or lazy=false)
--   - Configuration (opts, config, or setup)
--   - Dependencies (other plugins needed)
--
-- TO DISABLE A PLUGIN: Set enabled = false
-- TO CHANGE LOADING: Modify the event/cmd/keys/ft
-- TO ADD CONFIGURATION: Add opts = {} or config = function() ... end
-- ============================================================================
require('lazy').setup({
  -- ============================================================================
  -- SECTION 6.1: UI & VISUAL ENHANCEMENTS
  -- ============================================================================
  -- Plugins that change how Neovim looks and feels.

  -- GUESS INDENT
  -- WHAT: Automatically detects indentation settings (tabs vs spaces, width)
  -- TO CHANGE: Remove this plugin if you prefer manual settings
  -- EFFECT: When you open a file, it detects if it uses 2-space, 4-space, or tabs
  --         and sets your indent settings accordingly. Very small, safe to keep.
  { 'NMAC427/guess-indent.nvim', opts = {} },

  -- GITSIGNS
  -- WHAT: Shows git change indicators in the left gutter (next to line numbers)
  -- TO CHANGE: Modify the sign characters in opts.signs, or set enabled = false
  -- EFFECT: + = added line, ~ = changed line, _ = deleted line
  --         Also provides git hunk navigation and staging
  -- LOADING: BufReadPost = loads when you open a file (not at startup)
  -- PERFORMANCE: Saves ~20-60ms by deferring load
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' }, ---@diagnostic disable-line: missing-fields
        change = { text = '~' }, ---@diagnostic disable-line: missing-fields
        delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
        topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
        changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
      },
    },
  },

  -- NOICE
  -- WHAT: Replaces the default UI for messages, cmdline and popupmenu.
  --       :messages become a scrollable popup, search/cmdline get floating
  --       boxes, LSP hover/docs render as markdown with a rounded border.
  -- TO CHANGE: `:Noice` opens the message history; :Noice errors for errors.
  -- EFFECT: Nicer message UX. If anything looks off, `:Noice disable`
  --         temporarily reverts to stock UI without uninstalling.
  -- LOADING: VeryLazy = after UI is ready (recommended by upstream)
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      presets = {
        -- keep search at the bottom like classic vim (floating search box off)
        bottom_search = true,
        -- rounded border on hover/signature docs (matches diagnostic floats)
        lsp_doc_border = true,
      },
    },
  },

  -- WHICH-KEY
  -- WHAT: Shows a popup with available keybindings after you press a key
  -- TO CHANGE: Add more groups in opts.spec, or change delay
  -- EFFECT: After pressing <leader>, you'll see a list of available keys
  --         and what they do. Helps discover and remember keybindings.
  -- LOADING: VeryLazy = loads after UI is ready
  -- PERFORMANCE: 200ms delay balances responsiveness with performance
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      delay = 200, -- Delay before showing which-key (ms)
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains (groups of related keymaps)
      -- Add your own groups here for better organization
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle & [T]erminal' },
        { '<leader>m', group = '[B]ookmarks & [M]olten' },
        { '<leader>d', group = '[D]ebug' },
        { '<leader>f', group = '[F]ormat / [F]ind' },
        { '<leader>r', group = '[R]un' },
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    -- By default, Telescope is included and acts as your picker for everything.

    -- If you would like to switch to a different picker (like snacks, or fzf-lua)
    -- you can disable the Telescope plugin by setting enabled to false and enable
    -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

    -- Note: If you customize your config for yourself,
    -- it’s best to remove the Telescope plugin config entirely
    -- instead of just disabling it here, to keep your config clean.
    enabled = true,
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        defaults = {
          file_ignore_patterns = {
            'node_modules',
            '__pycache__',
            '.venv',
            'venv',
            '.mypy_cache',
            '.pytest_cache',
            '.git',
            'dist',
            'build',
          },
          layout_strategy = 'flex',
        },
        pickers = {
          find_files = {
            hidden = true,
            -- file_ignore_patterns below already filters junk; do NOT set
            -- no_ignore=true or it bypasses those patterns (node_modules, .venv, ...).
          },
          live_grep = {
            additional_args = { '--hidden' },
          },
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable core Telescope extensions (needed for builtin pickers)
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      -- NOTE: projects & file_browser extensions loaded lazily on <leader>sp, <leader>fe, <leader>fE
      -- vim_bookmarks extension loaded lazily on <leader>mb (see telescope-vim-bookmarks spec)

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      -- double-space alias: fastest way to find files
      vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sp', function()
        local root = vim.fs.root(0, { '.git', '_darcs', '.hg', '.bzr', '.svn', 'Makefile', 'package.json' }) or vim.fn.getcwd()
        require('telescope.builtin').find_files { cwd = root, prompt_title = 'Projects: ' .. vim.fn.fnamemodify(root, ':~') }
      end, { desc = '[S]earch [P]rojects (builtin root)' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', function()
        builtin.diagnostics {
          layout_strategy = 'vertical',
          layout_config = { height = 0.9, width = 0.9, preview_height = 0.6 },
          attach_mappings = function(_, map)
            -- <C-y> copies the full message of the diagnostic under the selection.
            -- Bound in insert mode too, since the picker starts in insert mode.
            map({ 'i', 'n' }, '<C-y>', function(prompt_bufnr)
              local entry = require('telescope.actions.state').get_selected_entry()
              require('telescope.actions').close(prompt_bufnr)
              if not entry then return end
              vim.fn.setreg('+', entry.text)
              vim.notify('Copied diagnostic: ' .. entry.text:gsub('\n', ' '):sub(1, 60), vim.log.levels.INFO)
            end)
            return true
          end,
        }
      end, { desc = '[S]earch [D]iagnostics (navigate + <C-y> copy)' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
      vim.keymap.set('n', '<leader>fe', '<cmd>Neotree toggle<CR>', { desc = '[F]ile [E]xplorer (Neo-tree)' })
      vim.keymap.set('n', '<leader>fE', '<cmd>Neotree reveal<CR>', { desc = '[F]ile [E]xplorer (reveal)' })
      -- List functions/symbols in the current file via Telescope (requires LSP)
      vim.keymap.set('n', '<leader>ls', builtin.lsp_document_symbols, { desc = '[L]ist [S]ymbols in file' })
      vim.keymap.set('n', '<leader>lS', builtin.lsp_workspace_symbols, { desc = '[L]ist [S]ymbols in workspace' })
    end,
  },

  {
    'nvim-pack/nvim-spectre',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<leader>fr', function() require('spectre').open() end, desc = '[F]ind & [R]eplace' },
    },
    opts = {},
  },

  -- ============================================================================
  -- SECTION 6.3: LANGUAGE SERVER PROTOCOL (LSP)
  -- ============================================================================
  -- LSP provides code intelligence: go-to-definition, find references,
  -- autocompletion, diagnostics, and more.

  -- NVIM-LSPCONFIG
  -- WHAT: Configures language servers for Neovim (the main LSP plugin)
  -- TO CHANGE: Add/remove servers in the `servers` table below
  -- EFFECT: Each server provides language-specific features (e.g., pyright for Python)
  --         Servers are loaded on-demand via FileType autocmds for performance
  -- PERFORMANCE: FileType autocmds save ~50-150ms startup time
  {
    'neovim/nvim-lspconfig',
    -- Load on first file open (not at startup) to keep the LSP stack out of
    -- the startup path; BufReadPre fires before FileType so the on-demand
    -- enable-autocmds below still win.
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      -- Mason: auto-installs LSP servers and tools
      -- TO CHANGE: Add tools to ensure_installed to auto-install them
      -- EFFECT: Mason downloads and manages language servers for you
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      -- Bridges mason.nvim with nvim-lspconfig
      'mason-org/mason-lspconfig.nvim',
      -- Auto-installs tools listed in ensure_installed
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Shows LSP loading progress in the bottom-right corner
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Hover: show function signature, args, return type, docs
          map('K', vim.lsp.buf.hover, '[H]over')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end

          -- Telescope LSP keymaps (moved from telescope-lsp-attach autocmd)
          local ok, builtin = pcall(require, 'telescope.builtin')
          if ok then
            vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = event.buf, desc = '[G]oto [R]eferences' })
            vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = event.buf, desc = '[G]oto [I]mplementation' })
            vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = event.buf, desc = '[G]oto [D]efinition' })
            vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = event.buf, desc = 'Open Document Symbols' })
            vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = event.buf, desc = 'Open Workspace Symbols' })
            vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = event.buf, desc = '[G]oto [T]ype Definition' })
          end
        end,
      })

      -- Language servers managed by Mason (automatically installed via `:Mason`)
      --  See `:help lsp-config` for information about keys and how to configure
      ---@type table<string, vim.lsp.Config>
      local servers = {
        -- clangd = {},
        docker_compose_language_service = {},
        dockerls = {},
        -- run='onSave': lint on save instead of every keystroke (pairs with
        -- auto-save on InsertLeave); big CPU cut in large TS repos
        eslint = { settings = { eslint = { run = 'onSave' } } },
        -- gopls = {},
        pyrefly = {
          cmd = { 'pyrefly', 'lsp' },
          settings = { python = { pyrefly = { typeCheckingMode = 'default' } } },
        }, -- LSP: fast type-checking for Python (installed via brew)
        -- rust_analyzer = {},
        --
        -- Some languages (like typescript) have enhanced LSP plugins:
        --    https://github.com/yioneko/nvim-vtsls (faster TS LSP)
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},

        -- Special Lua Config, as recommended by neovim help docs
        lua_ls = {
          on_init = function(client)
            client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
                --  See https://github.com/neovim/nvim-lspconfig/issues/3189
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          ---@type lspconfig.settings.lua_ls
          settings = {
            Lua = {
              format = { enable = false }, -- Disable formatting (formatting is done by stylua)
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      -- NOTE: pyrefly is installed globally via brew (not managed by Mason); skip it.
      local ensure_installed = vim.tbl_filter(function(name) return name ~= 'pyrefly' end, vim.tbl_keys(servers))
      vim.list_extend(ensure_installed, {
        'prettier', -- unified JS/TS/JSON/HTML/CSS formatter used by conform
        'debugpy', -- Python debugger used by nvim-dap
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Configure servers but don't enable them globally
      -- Instead, enable on-demand via FileType autocmds for better startup performance
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      -- Only enable LSP servers when their filetype is opened
      local lsp_filetypes = {
        pyrefly = { 'python' },
        lua_ls = { 'lua' },
        eslint = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        docker_compose_language_service = { 'yaml.docker-compose' },
        dockerls = { 'dockerfile' },
      }
      for server, filetypes in pairs(lsp_filetypes) do
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('lsp-on-demand-' .. server, { clear = true }),
          pattern = filetypes,
          once = true,
          callback = function() vim.lsp.enable(server) end,
        })
      end
    end,
  },

  -- ============================================================================
  -- SECTION 6.4: FORMATTING
  -- ============================================================================
  -- Plugins that auto-format your code on save.

  -- CONFORM.NVIM
  -- WHAT: Auto-formats your code when you save (uses external formatters)
  -- TO CHANGE: Add/remove formatters in formatters_by_ft, or modify enabled_filetypes
  -- EFFECT: When you save a Python file, it runs ruff; JS/TS/JSON/HTML/CSS
  --         use prettier; markdown/yaml use prettier
  --         Press <leader>f to format manually at any time
  -- LOADING: BufWritePre = loads only when you're about to save a file
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_after_save = function(bufnr)
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
          prepend_args = { '--config', vim.fn.expand '~/.config/nvim/prettier.config.json' },
        },
        prettierd = {
          stdin = true,
          prepend_args = { '--config=' .. vim.fn.expand '~/.config/nvim/prettier.config.json' },
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

  -- ============================================================================
  -- SECTION 6.5: AUTOCOMPLETION
  -- ============================================================================
  -- Plugins that provide code completion as you type.

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

  -- ============================================================================
  -- SECTION 6.6: COLORSCHEME
  -- ============================================================================
  -- Controls the colors and visual appearance of Neovim.

  -- TOKYONIGHT
  -- WHAT: A clean, dark color scheme for Neovim
  -- TO CHANGE: Change 'tokyonight-night' to 'tokyonight-storm', 'tokyonight-moon',
  --            or 'tokyonight-day' for different styles
  -- EFFECT: Changes all colors in the editor (syntax highlighting, UI, etc.)
  -- LOADING: priority=1000 ensures it loads before all other plugins
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
        on_colors = function(colors)
          colors.border = colors.blue -- brighter UI borders
        end,
        on_highlights = function(hl, c)
          hl.WinSeparator = { fg = c.blue, bg = 'NONE' }
          hl.CursorLineNr = { fg = c.orange, bold = true }
          hl.CursorLine = { bg = '#1a1b2a' } -- subtle pop on the cursor line
          hl.FloatBorder = { fg = c.blue, bg = 'NONE' }
          hl.NormalFloat = { bg = '#16161e' } -- slightly lifted panel
        end,
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- ============================================================================
  -- SECTION 6.7: EDITING UTILITIES
  -- ============================================================================
  -- Plugins that enhance text editing and manipulation.

  -- TODO-COMMENTS
  -- WHAT: Highlights TODO, FIXME, NOTE, WARN, etc. in comments with colors
  -- TO CHANGE: Remove this plugin if you don't want comment highlighting
  -- EFFECT: Words like TODO, FIXME, HACK get colored backgrounds in comments
  --         Helps you find important notes in your code
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
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
      require('mini.pairs').setup {}

      -- Statusline is handled by lualine.nvim (see LUALINE plugin entry below).

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

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
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    config = function()
      require('lspconfig.configs').vtsls = require('vtsls').lspconfig
      local lspconfig = require 'lspconfig'
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      lspconfig.vtsls.setup {
        capabilities = capabilities,
        settings = {
          vtsls = {
            autoUseWorkspaceTsdk = true,
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
                entriesLimit = 30,
              },
            },
          },
          typescript = {
            suggest = { completeFunctionCalls = true },
            -- 'on' forces a package.json dependency scan on every completion;
            -- 'auto' only when an import statement needs it (much cheaper).
            preferences = { includePackageJsonAutoImports = 'auto' },
            tsserver = {
              maxTsServerMemory = 4096,
              -- inotify-based watching instead of polling node_modules:
              -- keeps tsserver CPU flat in large repos.
              watchOptions = {
                watchFile = 'useFsEvents',
                watchDirectory = 'useFsEvents',
                fallbackPolling = 'dynamicPriority',
              },
            },
          },
        },
      }
    end,
  },

  -- CODE RUNNER (builtin — replaces code_runner.nvim, zero loss via :terminal)

  -- ============================================================================
  -- SECTION 6.8: SYNTAX HIGHLIGHTING
  -- ============================================================================
  -- Plugins that provide syntax highlighting and code parsing.

  -- TREESITTER
  -- WHAT: Provides accurate, incremental syntax highlighting and text objects
  -- TO CHANGE: Install more parsers with `:TSInstall <language>`
  -- EFFECT: Better syntax highlighting than traditional regex-based highlighting
  --         Enables features like incremental selection, text objects
  -- LOADING: BufReadPost = loads when you open a file
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      -- main branch of nvim-treesitter only handles parser install dir
      require('nvim-treesitter').setup {}
      -- Install missing parsers on load (ensure_installed is unsupported in the rewrite)
      for _, lang in ipairs { 'dockerfile', 'yaml' } do
        local parser = vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'parser', lang .. '.so')
        if vim.fn.filereadable(parser) ~= 1 then vim.cmd('TSInstall ' .. lang) end
      end

      -- Enable treesitter highlighting via Neovim built-in APIs (main branch doesn't support old config)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(args)
          -- ponytail: skip treesitter on minified bundles / huge files (>200KB);
          -- the parser chokes on them. Legacy regex highlighting covers it.
          -- Raise/lower the size cap here if you want treesitter everywhere.
          local name = vim.api.nvim_buf_get_name(args.buf)
          local ok_stat, stat = pcall(vim.uv.fs_stat, name)
          if name:match '%.min%.' or (ok_stat and stat and stat.size > 200 * 1024) then return end
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- ============================================================================
  -- SECTION 6.9: UI COMPONENTS
  -- ============================================================================
  -- Plugins that add visual UI elements to Neovim.

  -- NEO-TREE
  -- WHAT: A file explorer that shows your project's file tree
  -- TO CHANGE: Modify filesystem.hijack_netrw_behavior or keybindings
  -- EFFECT: Press <leader>e to toggle a floating file explorer
  --         Replaces netrw (the built-in file browser)
  -- LOADING: keys = only loads when you press <leader>e
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>e', '<cmd>Neotree float toggle<cr>', desc = 'Toggle File [E]xplorer (float)' },
    },
    opts = {
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
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
  },

  -- ============================================================================
  -- SECTION 6.10: SESSIONS (builtin — replaces auto-session, zero loss)
  -- ============================================================================
  -- (builtin session handling is set up after lazy.nvim — see bottom of file)

  -- ============================================================================
  -- SECTION 6.11: NAVIGATION
  -- ============================================================================
  -- Plugins for jumping around your code and files.

  -- FLASH.NVIM
  -- WHAT: Jump to any visible location using labeled targets (like hop.nvim)
  -- TO CHANGE: Remove if you prefer sneak or easymotion
  -- EFFECT: Press s to see jump labels; press the label letter to jump there
  --         Press S for treesitter-aware jumps (jumps to function/class boundaries)
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash Jump' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
    },
  },

  -- ============================================================================
  -- SECTION 6.12: CUSTOM PLUGINS
  -- ============================================================================
  -- Custom plugin definitions from `lua/custom/plugins/*.lua`
  { import = 'custom.plugins' },

  -- ============================================================================
  -- SECTION 6.13: PYTHON DEVELOPMENT
  -- ============================================================================
  -- Plugins for Python debugging and development.

  -- NVIM-DAP
  -- WHAT: Debug Adapter Protocol (DAP) implementation for step-through debugging
  -- TO CHANGE: Modify debug keybindings or add more language adapters
  -- EFFECT: Set breakpoints (<leader>db), step through code (<leader>dc/di/do),
  --         inspect variables, and debug Python tests
  -- LOADING: keys = only loads when you press debug keybindings
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui', -- Visual UI for the debugger
      'nvim-neotest/nvim-nio', -- Required by dap-ui
      'mfussenegger/nvim-dap-python', -- Python-specific debugging
    },
    keys = {
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = '[D]ebug [B]reakpoint' },
      { '<leader>dc', function() require('dap').continue() end, desc = '[D]ebug [C]ontinue' },
      { '<leader>di', function() require('dap').step_into() end, desc = '[D]ebug Step [I]nto' },
      { '<leader>do', function() require('dap').step_over() end, desc = '[D]ebug Step [O]ver' },
      { '<leader>dO', function() require('dap').step_out() end, desc = '[D]ebug Step [O]ut' },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = '[D]ebug [R]epl' },
      { '<leader>dl', function() require('dap').run_last() end, desc = '[D]ebug Run [L]ast' },
      { '<leader>dt', function() require('dap').terminate() end, desc = '[D]ebug [T]erminate' },
      { '<leader>dn', function() require('dap-python').test_method() end, desc = '[D]ebug [N]earest Test' },
      { '<leader>df', function() require('dap-python').test_class() end, desc = '[D]ebug Test [F]ile' },
      { '<leader>ds', function() require('dap-python').debug_selection() end, mode = 'v', desc = '[D]ebug [S]election' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      dapui.setup()
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      -- Python debugging with debugpy (Mason-installed venv). If debugpy isn't
      -- installed yet, skip setup so dap-python falls back to python3.
      local debugpy_path = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
      if vim.fn.filereadable(debugpy_path) == 1 then require('dap-python').setup(debugpy_path) end
    end,
  },

  -- ============================================================================
  -- SECTION 6.14: BOOKMARKS
  -- ============================================================================
  -- Plugins for marking and navigating to important lines.

  -- TELESCOPE-VIM-BOOKMARKS
  -- WHAT: Toggle bookmarks and list them with Telescope
  -- TO CHANGE: Remove if you don't use bookmarks
  -- EFFECT: <leader>mt to toggle bookmark; <leader>mj/mk to jump between bookmarks
  --         <leader>mc to annotate; <leader>mb to list all bookmarks in Telescope
  -- LOADING: keys = only loads when you press the keybindings
  --          vim_bookmarks telescope extension loads lazily on <leader>mb
  {
    'tom-anders/telescope-vim-bookmarks.nvim',
    dependencies = { 'MattesGroeger/vim-bookmarks' },
    keys = {
      { '<leader>mt', '<cmd>BookmarkToggle<cr>', desc = '[B]ookmark [T]oggle' },
      { '<leader>mc', '<cmd>BookmarkAnnotate<cr>', desc = '[B]ookmark [A]nnotate' },
      { '<leader>mj', '<cmd>BookmarkNext<cr>', desc = '[B]ookmark [N]ext' },
      { '<leader>mk', '<cmd>BookmarkPrev<cr>', desc = '[B]ookmark [P]revious' },
      { '<leader>mb', function()
          require('telescope').load_extension('vim_bookmarks')
          vim.cmd('Telescope vim_bookmarks')
        end, desc = '[B]ookmark [L]ist' },
    },
  },

  -- ============================================================================
  -- SECTION 6.15: VISUAL ENHANCEMENTS
  -- ============================================================================
  -- Plugins that enhance the visual appearance of code.

  -- HLCHUNK
  -- WHAT: Shows colored indent lines and highlights the current code chunk
  -- TO CHANGE: Modify colors in opts.chunk.style or opts.indent.style
  -- EFFECT: Purple/red chunk highlighting for the current block
  --         Dimmed indent lines (│) for visual structure
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'shellRaining/hlchunk.nvim',
    event = { 'VeryLazy' },
    config = function()
      require('hlchunk').setup {
        chunk = {
          enable = true,
          -- treesitter is available, but indentation-based detection is
          -- lighter and works uniformly without parser-specific quirks.
          use_treesitter = false,
          style = {
            { fg = '#806d9c' },
            { fg = '#c21f30' },
          },
          chars = {
            horizontal_line = '─',
            vertical_line = '│',
            left_top = '╭',
            left_bottom = '╰',
            right_arrow = '─',
          },
        },
        indent = {
          enable = true,
          delay = 300,
          chars = { '│' },
          style = { { fg = '#4a4560' } },
        },
      }
    end,
  },

  -- RENDER-MARKDOWN
  -- WHAT: Better markdown rendering with icons, boxes, and formatting
  -- TO CHANGE: Remove if you prefer plain markdown
  -- EFFECT: Markdown headings get icons, code blocks get boxes,
  --         checkboxes get rendered as [ ] and [x]
  -- LOADING: ft = only loads for markdown files
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  -- COLORIZER
  -- WHAT: Highlights hex (#ff00aa) and named colors inline
  -- TO CHANGE: <leader>uc to toggle
  -- EFFECT: Color swatches appear behind color codes in any buffer
  -- LOADING: BufRead = loads when a file opens
  {
    -- Maintained drop-in fork of norcalli/nvim-colorizer.lua (the original is
    -- unmaintained and uses vim.tbl_flatten, removed in Nvim 0.13).
    'catgoose/nvim-colorizer.lua',
    event = 'BufRead',
  },

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, { ---@diagnostic disable-line: missing-fields
  rocks = { enabled = false },
  performance = {
    -- Cache compiled plugin modules so lazy.nvim doesn't re-require them on
    -- every startup. Works alongside vim.loader.enable() above.
    cache = {
      enabled = true,
    },
    rtp = {
      -- Disable unused built-in Neovim plugins for faster startup (saves 10-20ms)
      disabled_plugins = {
        'gzip', -- Gzip file reading/writing (not needed)
        'tar', -- Tar file reading/writing (not needed)
        'tohtml', -- Convert to HTML (not needed)
        'tutor', -- Vim tutorial (not needed)
        'netrwPlugin', -- Netrw file browser (replaced by neo-tree)
        'matchit', -- Extended % matching (replaced by mini.ai)
        -- matchparen is kept: mini.ai/mini.surround don't replicate its
        -- matching-paren highlight under the cursor.
        'zip', -- Zip archive reading/writing (not needed)
      },
    },
  },
  -- Lazy.nvim UI configuration
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- BUILTIN UI: statusline/tabline/dashboard (replaces lualine/bufferline/alpha)
pcall(function() require('custom.ui.spec').setup_lualine() end)
pcall(function() require('custom.ui.spec').setup_bufferline() end)
pcall(function() require('custom.ui.spec').setup_starter() end)
vim.keymap.set('n', '<S-h>', '<cmd>bprev<cr>', { desc = 'Prev Buffer' })
vim.keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<cr>', { desc = '[B]uffer [D]elete' })

-- BUILTIN SESSIONS (replaces rmagatti/auto-session, zero loss via :mksession)
-- ponytail: native mksession + VimEnter/VimLeave autocmds; no plugin needed
-- `nvim` with no args in a cwd restores that cwd's session if present (buffers + last file)
do
  vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'
  local suppressed = { ['~/'] = true, ['~/Downloads'] = true, ['/etc'] = true, ['/tmp'] = true }
  local function suppressed_dir(cwd)
    cwd = (cwd or vim.fn.getcwd()):gsub('/+$', '')
    if cwd == '' then cwd = '/' end
    for d in pairs(suppressed) do
      local e = vim.fn.expand(d):gsub('/+$', '')
      if e == '' then e = '/' end
      if cwd == e then return true end -- exact only; not subdirs (fixes ~/ blocking ~/projects/*)
    end
    return false
  end
  local function session_file_for(cwd)
    cwd = cwd and vim.fn.fnamemodify(cwd, ':p') or vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
    return vim.fn.stdpath 'data' .. '/sessions/' .. cwd:gsub('[^%w]+', '%%') .. '.vim'
  end
  local function session_file() return session_file_for(nil) end
  -- find existing session for cwd by scanning cd line (supports legacy %2F names)
  local function find_session_for(cwd)
    cwd = cwd and vim.fn.fnamemodify(cwd, ':p') or vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
    local f = session_file_for(cwd)
    local function has_badd(p)
      if vim.fn.filereadable(p) ~= 1 then return false end
      for _, l in ipairs(vim.fn.readfile(p)) do if l:match('^badd') then return true end end
      return false
    end
    if has_badd(f) then return f end
    local norm = cwd:gsub('/+$', '')
    if norm == '' then norm = '/' end
    local dir = vim.fn.stdpath('data') .. '/sessions'
    local best, best_time = nil, -1
    for _, path in ipairs(vim.fn.glob(dir .. '/*.vim', false, true)) do
      if has_badd(path) then
        for _, l in ipairs(vim.fn.readfile(path)) do
          local cd = l:match('^cd%s+(.+)$')
          if cd then
            cd = vim.fn.fnamemodify(vim.fn.expand(cd), ':p'):gsub('/+$', '')
            if cd == '' then cd = '/' end
            if cd == norm then
              local t = vim.fn.getftime(path)
              if t > best_time then best, best_time = path, t end
            end
            break
          end
        end
      end
    end
    if best then return best end
    return f
  end
  -- expose for dashboard s picker
  _G._builtin_session_file_for = session_file_for
  _G._builtin_session_file = session_file
  _G._builtin_find_session = find_session_for
  _G._builtin_suppressed_dir = suppressed_dir
  -- ponytail: no auto-restore on VimEnter; dashboard is default, `s` restores (see spec.lua)
  -- helpers kept for `s` (find_session_for / session_file)
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if suppressed_dir() then return end
      -- don't overwrite good session with empty dashboard/no-file state
      local has_file = false
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == '' and vim.api.nvim_buf_get_name(b) ~= '' and vim.bo[b].filetype ~= 'dashboard' then has_file = true; break end
      end
      if not has_file then return end
      pcall(vim.cmd, 'silent! Neotree close')
      vim.fn.mkdir(vim.fn.stdpath 'data' .. '/sessions', 'p')
      vim.cmd('silent! mksession! ' .. vim.fn.fnameescape(session_file()))
    end,
  })
end

-- BUILTIN TERMINAL (replaces toggleterm.nvim + lazygit.nvim, zero loss via :terminal)
-- ponytail: :terminal + TermOpen autocmd (lua/config/autocmds.lua) already handles jk/C-hjkl
do
  -- ponytail: single reusable buf per kind; hide/show = close win, keep buf (no new split each time)
  local horiz = { buf = nil, win = nil }
  local float = { buf = nil, win = nil }
  local last = 'horiz' -- ponytail: C-\ targets last opened kind (like toggleterm)
  local function is_win_valid(w) return w and vim.api.nvim_win_is_valid(w) end
  local function is_buf_valid(b) return b and vim.api.nvim_buf_is_valid(b) end
  local function toggle_horiz(cmd)
    last = 'horiz'
    if is_win_valid(horiz.win) then vim.api.nvim_win_close(horiz.win, true); horiz.win = nil; return end
    -- also handle case win was closed manually (buf still valid)
    if is_buf_valid(horiz.buf) then
      for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_buf(w) == horiz.buf then vim.api.nvim_set_current_win(w); vim.cmd.startinsert(); horiz.win = w; return end end
      vim.cmd 'botright split'
      vim.cmd 'resize 15'
      vim.api.nvim_win_set_buf(0, horiz.buf)
      horiz.win = vim.api.nvim_get_current_win()
      vim.cmd.startinsert()
    else
      vim.cmd('botright split | terminal ' .. cmd)
      vim.cmd 'resize 15'
      horiz.buf = vim.api.nvim_get_current_buf()
      horiz.win = vim.api.nvim_get_current_win()
      vim.cmd.startinsert()
    end
  end
  local function toggle_float(cmd)
    last = 'float'
    if is_win_valid(float.win) then
      vim.api.nvim_win_close(float.win, true)
      float.win = nil
      return
    end
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * 0.85)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    if is_buf_valid(float.buf) then
      float.win = vim.api.nvim_open_win(float.buf, true, { relative = 'editor', width = width, height = height, row = row, col = col, style = 'minimal', border = 'rounded' })
      vim.cmd.startinsert()
    else
      float.buf = vim.api.nvim_create_buf(false, true)
      float.win = vim.api.nvim_open_win(float.buf, true, { relative = 'editor', width = width, height = height, row = row, col = col, style = 'minimal', border = 'rounded' })
      vim.fn.termopen(cmd, { on_exit = function() end })
      vim.cmd.startinsert()
    end
  end
  local function new_horiz(cmd)
    vim.cmd('botright split | terminal ' .. cmd)
    vim.cmd 'resize 15'
    vim.cmd.startinsert()
  end
  vim.keymap.set('n', '<leader>tt', function() toggle_horiz(vim.o.shell) end, { desc = '[T]oggle [T]erminal' })
  vim.keymap.set('n', '<leader>tf', function() toggle_float(vim.o.shell) end, { desc = '[T]erminal [F]loat' })
  vim.keymap.set('n', '<leader>fg', function() toggle_float('lazygit') end, { desc = '[F]ile [G]it (LazyGit)' })
  vim.keymap.set('n', '<leader>tm', function() toggle_float('tmux new -s float 2>/dev/null || tmux attach -t float') end, { desc = '[T]erminal t[M]ux' })
  vim.keymap.set('n', '<leader>ht', function() toggle_float('herdr') end, { desc = '[H]erdr [T]erminal' })
  vim.keymap.set('n', '<leader>t1', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [1]' })
  vim.keymap.set('n', '<leader>t2', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [2]' })
  vim.keymap.set('n', '<leader>t3', function() new_horiz(vim.o.shell) end, { desc = 'Terminal [3]' })
  vim.keymap.set('n', '<leader>tn', function() new_horiz(vim.o.shell) end, { desc = '[T]erminal [N]ew' })
  local function toggle_last()
    -- ponytail: C-\ mirrors toggleterm — if any terminal visible, hide it; else reopen last kind
    if is_win_valid(float.win) then vim.api.nvim_win_close(float.win, true); float.win = nil; return end
    if is_win_valid(horiz.win) then vim.api.nvim_win_close(horiz.win, true); horiz.win = nil; return end
    -- also hunt for manually-opened wins still showing our bufs
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local b = vim.api.nvim_win_get_buf(w)
      if b == float.buf then vim.api.nvim_win_close(w, true); return end
      if b == horiz.buf then vim.api.nvim_win_close(w, true); horiz.win = nil; return end
    end
    if last == 'float' then toggle_float(vim.o.shell) else toggle_horiz(vim.o.shell) end
  end
  vim.keymap.set({ 'n', 't' }, '<c-\\>', toggle_last, { desc = 'Toggle Terminal' })
end

-- BUILTIN CODE RUNNER (replaces CRAG666/code_runner.nvim, zero loss via :terminal)
do
  local runners = {
    javascript = 'bun',
    typescript = 'bun',
    javascriptreact = 'bun',
    typescriptreact = 'bun',
    python = 'python3 -u',
  }
  local function run_file()
    local ft = vim.bo.filetype
    local file = vim.fn.expand '%:p'
    if file == '' then vim.notify('No file to run', vim.log.levels.WARN) return end
    local cmd
    if runners[ft] then
      cmd = runners[ft] .. ' ' .. vim.fn.shellescape(file)
    elseif ft == 'cpp' then
      local out = '/tmp/' .. vim.fn.expand '%:t:r'
      cmd = string.format('g++ %s -o %s && %s', vim.fn.shellescape(file), vim.fn.shellescape(out), vim.fn.shellescape(out))
    elseif ft == 'c' then
      local out = '/tmp/' .. vim.fn.expand '%:t:r'
      cmd = string.format('gcc %s -o %s && %s', vim.fn.shellescape(file), vim.fn.shellescape(out), vim.fn.shellescape(out))
    else
      vim.notify('No runner for filetype: ' .. ft, vim.log.levels.WARN) return
    end
    vim.cmd('split | terminal ' .. cmd)
    vim.cmd 'wincmd J | resize 15'
    vim.cmd.startinsert()
  end
  vim.keymap.set('n', '<leader>r', run_file, { desc = '[R]un [C]ode' })
  vim.keymap.set('n', '<leader>rf', run_file, { desc = '[R]un [F]ile' })
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
