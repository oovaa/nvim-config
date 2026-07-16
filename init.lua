--[[

================================================================================
NEOVIM CONFIGURATION GUIDE
================================================================================

This is your Neovim configuration. Every setting is explained so you can
understand what it does, change it safely, and know the effect of your changes.

WHAT IS KICKSTART?
  Kickstart.nvim is a starting point for your own configuration, not a distribution.
  Read every line, understand it, and modify it to suit your needs.

GETTING STARTED:
  1. Read through this file top to bottom
  2. Try changing a setting and see what happens
  3. Use `:help <option>` to learn more about any option
  4. Use `:Telescope keymaps` to see all available keybindings

LEADER KEY: <Space> (Section 2)

SECTION INDEX:
  1.  Provider Disables        - Disable unused language providers
  2.  Leader Key               - Set your leader key (MUST be before plugins)
  3.  Options                  - Core Neovim settings
  4.  Keymaps                  - Custom keybindings
  5.  Autocommands             - Auto-run code on events
  6.  Plugins (lazy.nvim)      - All plugin configurations
     6.1  UI & Visual         - Indent, git signs, which-key
     6.2  Fuzzy Finding       - Telescope, spectre
     6.3  LSP                 - Language servers, Mason
     6.4  Formatting          - Auto-format on save
     6.5  Completion          - Autocompletion (blink.cmp)
     6.6  Colorscheme         - TokyoNight theme
     6.7  Editing Utilities   - Todo, mini.nvim, auto-save
     6.8  Language Tools      - TypeScript, code runner
     6.9  Syntax              - Treesitter highlighting
     6.10 UI Components       - File explorer, tabs, terminal
     6.11 Git Integration     - Neogit, sessions
     6.12 Navigation          - Flash, projects, bookmarks
     6.13 Visual              - Indent lines, markdown
     6.14 Python Dev          - Debugger (DAP)
     6.15 Remote Dev          - SSH into remote machines
  7.  Terminal Keymaps         - Better terminal navigation
  8.  Project Switching        - Quick project switching
  9.  Filetype Detection       - Custom filetype rules

KEYBINDINGS QUICK REFERENCE:
  <leader>s  = Search          <leader>t  = Terminal
  <leader>f  = File/Git        <leader>d  = Debug
  <leader>g  = Git             <leader>m  = Bookmarks/Molten
  <leader>r  = Run/Remote      gr         = LSP actions
  mm         = Toggle bookmark S/s        = Flash jump

--]]

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
vim.g.loaded_perl_provider = 0  -- Disable Perl provider (not used by any plugin)
vim.g.loaded_ruby_provider = 0  -- Disable Ruby provider (not used by any plugin)
-- python3 is intentionally NOT disabled because molten-nvim needs it
-- node is intentionally NOT disabled because some plugins may need it

-- COMPATIBILITY SHIM
-- WHAT: Some older plugins use vim.lsp.buf_get_clients() which was renamed to
--        vim.lsp.get_clients(). This maps the old name to the new one.
-- TO CHANGE: Remove this line if all your plugins are up to date
-- EFFECT: Prevents breakage in plugins using the deprecated function
vim.lsp.buf_get_clients = vim.lsp.get_clients

-- ============================================================================
-- SECTION 2: LEADER KEY CONFIGURATION
-- ============================================================================
-- WHAT: Sets your "leader" key - the prefix for custom keybindings.
--        Your leader key is used constantly throughout this config.
--
-- IMPORTANT: This MUST happen BEFORE plugins are loaded.
--
-- TO CHANGE:
--   Common alternatives to Space:
--     vim.g.mapleader = ','      -- Comma (popular with Vim users)
--     vim.g.mapleader = ';'      -- Semicolon
--     vim.g.mapleader = '\\'     -- Backslash
--
-- EFFECT:
--   All <leader>X keybindings will use your new leader key instead of Space.
--   Example: If leader is ',', then <leader>sf becomes ,sf
--
-- SEE: `:help mapleader`
-- ============================================================================
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ============================================================================
-- SECTION 3: NEOVIM OPTIONS
-- ============================================================================
-- WHAT: Controls Neovim's behavior, appearance, and editing features.
--        Each option is a setting that changes how Neovim works.
--
-- HOW TO CHANGE: Toggle by commenting/uncommenting (add or remove --)
--                Change values by editing the right side of the =
--                Test with `:source %` or restart Neovim
--
-- SEE: `:help vim.o` for all available options
-- ============================================================================

-- NERD FONT SUPPORT
-- WHAT: Enables special icons in the UI (file explorer, statusline, etc.)
-- TO CHANGE: Set to false if you don't have a Nerd Font installed
-- EFFECT: false = no icons (works with any terminal font)
--         true = icons everywhere (requires a Nerd Font like JetBrainsMono Nerd Font)
vim.g.have_nerd_font = true

-- LINE NUMBERS
-- WHAT: Shows line numbers in the left gutter
-- TO CHANGE: Uncomment relative line numbers for a different experience
-- EFFECT: true = absolute numbers (1, 2, 3, 4, 5...)
--         relative = relative numbers (cursor line shows absolute, others show distance)
vim.o.number = true
-- vim.o.relativenumber = true  -- Uncomment for relative line numbers

-- MOUSE SUPPORT
-- WHAT: Allows using the mouse in Neovim
-- TO CHANGE: Set to '' to disable mouse completely
-- EFFECT: 'a' = all modes (normal, insert, visual, command)
--         'n' = normal mode only
--         '' = no mouse support
vim.o.mouse = 'a'

-- SHOW MODE
-- WHAT: Shows current mode (INSERT, NORMAL, VISUAL) in the command line
-- TO CHANGE: Set to true if you want to see the mode indicator
-- EFFECT: false = cleaner command line (mode shown in statusline instead)
--         true = mode shown in command line bottom-left
vim.o.showmode = false

-- CLIPBOARD
-- WHAT: Syncs Neovim's clipboard with your system clipboard
-- TO CHANGE: Set to 'unnamed' for primary selection (Linux) or 'unnamedplus' for clipboard
-- EFFECT: You can paste system clipboard with p and copy to system clipboard with y
-- NOTE: Scheduled to avoid startup delay
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- BREAK INDENT
-- WHAT: Indents wrapped lines to match the first line's indent
-- TO CHANGE: Set to false to disable
-- EFFECT: true = wrapped lines align with the start of the visual line
vim.o.breakindent = true

-- UNDO FILE
-- WHAT: Saves undo history to a file, so you can undo even after closing
-- TO CHANGE: Set to false if you don't want persistent undo
-- EFFECT: true = undo history survives Neovim restart
vim.o.undofile = true

-- SEARCH SETTINGS
-- WHAT: Controls how search behaves (case sensitivity)
-- TO CHANGE: Set ignorecase to false for case-sensitive search by default
-- EFFECT: ignorecase + smartcase = case-insensitive unless you type uppercase
--         Example: "foo" matches "FOO", "Foo", "foo"
--                  "Foo" matches "Foo" but not "foo" or "FOO"
vim.o.ignorecase = true
vim.o.smartcase = true

-- SIGN COLUMN
-- WHAT: The column left of line numbers where git signs and diagnostics appear
-- TO CHANGE: Set to 'auto' to only show when there are signs
-- EFFECT: 'yes' = always visible (prevents layout shifting)
vim.o.signcolumn = 'yes'

-- UPDATE TIME
-- WHAT: How often Neovim checks for changes (in milliseconds)
-- TO CHANGE: Lower = more responsive but higher CPU
-- EFFECT: Affects CursorHold timing, swap file writes, and some plugin behaviors
vim.o.updatetime = 250

-- TIMEOUT LENGTH
-- WHAT: How long to wait for a key sequence to complete (in milliseconds)
-- TO CHANGE: Lower = faster timeout for multi-key sequences
-- EFFECT: Affects which-key display timing and key sequence completion
vim.o.timeoutlen = 300

-- SPLIT BEHAVIOR
-- WHAT: Controls where new windows open
-- TO CHANGE: Set to false for opposite behavior (traditional Vim)
-- EFFECT: splitright = true: vertical splits open to the right
--         splitbelow = true: horizontal splits open below
vim.o.splitright = true
vim.o.splitbelow = true

-- WHITESPACE DISPLAY
-- WHAT: Shows invisible characters (tabs, trailing spaces, etc.)
-- TO CHANGE: Set list = false to hide all, or modify listchars
-- EFFECT: Shows tabs as », trailing spaces as ·, nbsp as ␣
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- LIVE SUBSTITUTION PREVIEW
-- WHAT: Shows a split preview when using :substitute (:%s/old/new/g)
-- TO CHANGE: Set to 'nosplit' for inline preview, or 'false' to disable
-- EFFECT: 'split' = shows preview in a split window below
vim.o.inccommand = 'split'

-- CURSOR LINE
-- WHAT: Highlights the line where your cursor is
-- TO CHANGE: Set to false to disable
-- EFFECT: true = current line has a subtle highlight (helps find cursor)
vim.o.cursorline = true

-- SCROLL OFFSET
-- WHAT: Keeps this many lines visible above/below cursor when scrolling
-- TO CHANGE: Increase for more context, decrease for less
-- EFFECT: Higher values = more context visible (cursor stays centered-ish)
vim.o.scrolloff = 10

-- CONFIRM DIALOG
-- WHAT: Shows a confirmation when trying to quit with unsaved changes
-- TO CHANGE: Set to false for classic behavior (error message instead)
-- EFFECT: true = asks "Save changes?" dialog instead of error
vim.o.confirm = true

-- ============================================================================
-- SECTION 4: KEYMAPS
-- ============================================================================
-- WHAT: Defines custom keybindings for Neovim.
--
-- HOW TO ADD YOUR OWN:
--   vim.keymap.set({mode}, {lhs}, {rhs}, {options})
--   - mode: 'n' (normal), 'i' (insert), 'v' (visual), 't' (terminal)
--   - lhs: the key sequence to press (e.g., '<leader>w')
--   - rhs: what it does (a string command or a Lua function)
--   - options: table with 'desc', 'silent', 'noremap', etc.
--
-- SEE: `:help vim.keymap.set()` for full documentation
-- ============================================================================

-- Clear search highlighting when pressing <Esc>
-- WHAT: Removes the highlight from the last search
-- TO CHANGE: Set to a different key like <C-l> (Ctrl+L)
-- EFFECT: Pressing <Esc> in normal mode clears search highlights
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Delete previous word with Ctrl+Backspace
-- WHAT: Standard editor behavior - delete the word before cursor
-- TO CHANGE: Remove this line if you prefer default behavior
-- EFFECT: Works in both normal and insert mode
vim.keymap.set({ 'n', 'i' }, '<C-BS>', '<C-w>', { desc = 'Delete previous word' })

-- ============================================================================
-- DIAGNOSTIC CONFIGURATION & KEYMAPS
-- ============================================================================
-- WHAT: Configures how Neovim shows errors, warnings, and hints
-- TO CHANGE: Set virtual_text = false to hide inline error text
-- EFFECT: Controls appearance of LSP/linter diagnostics
vim.diagnostic.config {
  update_in_insert = false,        -- Don't update diagnostics while typing
  severity_sort = true,            -- Sort by severity (errors first)
  float = { border = 'rounded', source = 'if_many' },  -- Floating window style
  underline = { severity = { min = vim.diagnostic.severity.WARN } },  -- Underline warnings+
  virtual_text = true,             -- Show diagnostic text at end of line
  virtual_lines = false,           -- Alternative: show text below the line
  jump = { on_jump = true },       -- Auto-open float when jumping to diagnostic
}

-- Open diagnostic quickfix list
-- WHAT: Opens a list of all diagnostics in the current buffer
-- TO CHANGE: Map to a different key like <leader>x
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>uc', '<cmd>ColorizerToggle<cr>', { desc = '[U]I [C]olorizer toggle' })

-- ============================================================================
-- TERMINAL MODE KEYMAPS
-- ============================================================================
-- WHAT: Exit terminal mode with double <Esc>
-- TO CHANGE: Use a different escape sequence if needed
-- EFFECT: Pressing <Esc><Esc> returns to normal mode from terminal
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ============================================================================
-- WINDOW NAVIGATION KEYMAPS
-- ============================================================================
-- WHAT: Switch between split windows using Ctrl+{h,j,k,l}
-- TO CHANGE: Use different keys if you prefer
-- EFFECT: Ctrl+H/J/K/L moves between windows in that direction
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- ============================================================================
-- SECTION 5: AUTOCOMMANDS
-- ============================================================================
-- WHAT: Defines functions that run automatically on certain events.
--        For example: "when I save a file, do X" or "when I open a Python file, do Y"
--
-- HOW TO ADD YOUR OWN:
--   vim.api.nvim_create_autocmd({event}, {
--     group = vim.api.nvim_create_augroup('name', { clear = true }),
--     callback = function(args) -- your code here end,
--   })
--
-- COMMON EVENTS:
--   BufReadPost = after opening a file, BufWritePre = before saving,
--   InsertEnter = entering insert mode, CursorHold = cursor idle
--
-- SEE: `:help lua-guide-autocommands`
-- ============================================================================

-- Highlight yanked (copied) text briefly
-- WHAT: Briefly highlights text when you copy it (yank)
-- TO CHANGE: Remove this autocommand to disable, or change the highlight group
-- EFFECT: When you press y (yank), the copied text flashes briefly
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- NEON UI: theme + smooth cursor (no external plugins needed, safe to run now).
-- Plugin-dependent UI (lualine/bufferline/mini.starter) is wired via each
-- plugin's lazy `config` below, since they aren't loaded this early.
pcall(function()
  require('custom.ui.theme').setup()
  require('custom.ui').setup_smooth_cursor()
end)

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
      delay = 200,  -- Delay before showing which-key (ms)
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains (groups of related keymaps)
      -- Add your own groups here for better organization
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
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
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'projects')
      pcall(require('telescope').load_extension, 'file_browser')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sp', function() require('telescope').extensions.projects.projects {} end, { desc = '[S]earch [P]rojects' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

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
      vim.keymap.set('n', '<leader>fe', '<cmd>Telescope file_browser<CR>', { desc = '[F]ile [E]xplorer (Telescope)' })
      vim.keymap.set('n', '<leader>fE', '<cmd>Telescope file_browser path=%:p:h<CR>', { desc = '[F]ile [E]xplorer (cwd)' })
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

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --  See `:help lsp-config` for information about keys and how to configure
      ---@type table<string, vim.lsp.Config>
      local servers = {
        -- clangd = {},
        -- gopls = {},
        pyright = {},
        -- rust_analyzer = {},
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},

        stylua = {}, -- Used to format Lua code

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
      local ensure_installed = vim.tbl_keys(servers or {})

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Configure servers but don't enable them globally
      -- Instead, enable on-demand via FileType autocmds for better startup performance
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      -- Only enable LSP servers when their filetype is opened
      local lsp_filetypes = {
        pyright = { 'python' },
        lua_ls = { 'lua' },
        stylua = { 'lua' },
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
  -- EFFECT: When you save a Python file, it runs ruff; for JS/TS, it runs prettier
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
      format_on_save = function(bufnr)
        -- TO CHANGE: Add or remove filetypes from this table
        -- EFFECT: Only files matching these types will auto-format on save
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
          return { timeout_ms = 500 }
        else
          return nil
        end
      end,
      default_format_opts = {
        lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
      },
      -- You can also specify external formatters in here.
      formatters_by_ft = {
        python = { 'ruff_organize_imports', 'ruff_format' },
        javascript = { 'prettierd', 'prettier' },
        typescript = { 'prettierd', 'prettier' },
        javascriptreact = { 'prettierd', 'prettier' },
        typescriptreact = { 'prettierd', 'prettier' },
        vue = { 'prettierd', 'prettier' },
        json = { 'prettierd', 'prettier' },
        html = { 'prettierd', 'prettier' },
        css = { 'prettierd', 'prettier' },
        scss = { 'prettierd', 'prettier' },
        less = { 'prettierd', 'prettier' },
        markdown = { 'prettierd', 'prettier' },
        yaml = { 'prettierd', 'prettier' },
        graphql = { 'prettierd', 'prettier' },
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
            config = function()
              require('luasnip.loaders.from_vscode').lazy_load()
            end,
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
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
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
      require('mini.surround').setup({
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
      })

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
    "okuuva/auto-save.nvim",
    cmd = "ASToggle", 
    event = { "InsertLeave", "TextChanged" }, 
    opts = {},
  },

  -- TYPESCRIPT-TOOLS
  -- WHAT: Enhanced TypeScript/JavaScript LSP features (better than ts_ls)
  -- TO CHANGE: Remove if you prefer the built-in ts_ls
  -- EFFECT: Adds better type checking, refactoring, and code actions for TS/JS
  -- LOADING: ft = only loads for JavaScript/TypeScript files
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    init = function()
      vim.filetype.add({ extension = { ["jsx"] = "javascript.jsx" } })
      vim.filetype.add({ extension = { ["tsx"] = "typescript.tsx" } })
    end,
    opts = {
      settings = {
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
      },
    },
  },

  -- CODE RUNNER
  -- WHAT: Run code directly from the editor with a single keypress
  -- TO CHANGE: Modify the filetype table to add/change run commands
  -- EFFECT: <leader>r runs the current file; <leader>rf also runs the file
  --         Output appears in a terminal split below
  -- LOADING: keys = only loads when you press the keybindings
  {
    "CRAG666/code_runner.nvim",
    config = function()
      require('code_runner').setup({
        mode = "term",
        focus = true,
        startinsert = true,
        filetype = {
          javascript = "bun",
          python = "python3 -u",
          typescript = "bun",
          typescriptreact = "bun",
          cpp = { "cd $dir && g++ $fileName -o $fileNameWithoutExt && ./$fileNameWithoutExt" },
          c = { "cd $dir && gcc $fileName -o $fileNameWithoutExt && ./$fileNameWithoutExt" },
        },
      })
    end,
    keys = {
      { "<leader>r", ":RunCode<CR>", desc = "[R]un [C]ode" },
      { "<leader>rf", ":RunFile<CR>", desc = "[R]un [F]ile" },
    },
  },

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
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      -- main branch of nvim-treesitter only handles parser install dir
      require('nvim-treesitter').setup({})

      -- Enable treesitter highlighting via Neovim built-in APIs (main branch doesn't support old config)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(args)
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
  -- WHAT: A file explorer sidebar that shows your project's file tree
  -- TO CHANGE: Modify filesystem.hijack_netrw_behavior or keybindings
  -- EFFECT: Press <leader>e to toggle the file explorer on the left
  --         Replaces netrw (the built-in file browser)
  -- LOADING: keys = only loads when you press <leader>e
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle File [E]xplorer" },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = "open_default",
      },
    },
  },

  -- BUFFERLINE
  -- WHAT: Shows open buffers as tabs at the top of the screen
  -- TO CHANGE: See lua/custom/ui/spec.lua setup_bufferline
  -- EFFECT: Shift+H/L to switch buffers; <leader>bd to delete a buffer
  --         Shows LSP diagnostics indicators on buffer tabs
  -- LOADING: keys = only loads when you press the keybindings
  -- CONFIG: Tuning lives in lua/custom/ui/spec.lua (diagnostics + icons)
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    config = function() require('custom.ui.spec').setup_bufferline() end,
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bd", "<cmd>bdelete<cr>", desc = "[B]uffer [D]elete" },
    },
  },

  -- LUALINE
  -- WHAT: Statusline + winbar (mode-aware, tokyonight theme)
  -- CONFIG: Tuning lives in lua/custom/ui/spec.lua setup_lualine
  {
    'nvim-lualine/lualine.nvim',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    config = function() require('custom.ui.spec').setup_lualine() end,
  },

  -- ALPHA (DASHBOARD)
  -- WHAT: Modern startup screen - banner, quick actions, recent files
  -- CONFIG: Tuning lives in lua/custom/ui/spec.lua setup_starter
  {
    'goolord/alpha-nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VimEnter',
    config = function() require('custom.ui.spec').setup_starter() end,
  },

  -- LAZYGIT
  -- WHAT: Opens LazyGit (a terminal git UI) in a floating window
  -- TO CHANGE: Change the keybinding or remove this plugin
  -- EFFECT: Press <leader>fg to open a full git interface in a floating window
  --         Much faster than command-line git for common operations
  -- LOADING: cmd/keys = only loads when you press the keybinding
  {
    'kdheepak/lazygit.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'LazyGit', 'LazyGitConfig' },
    keys = {
      { "<leader>fg", "<cmd>LazyGit<cr>", desc = "[F]ile [G]it (LazyGit)" },
    },
  },

  -- TOGGLETERM
  -- WHAT: Better terminal management with multiple terminal support
  -- TO CHANGE: Modify direction, size, or keybindings
  -- EFFECT: <C-\> to toggle terminal; <leader>tt for horizontal terminal
  --         <leader>tf for floating terminal; <leader>t1/t2/t3 for numbered terminals
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    event = 'VeryLazy',
    opts = {
      open_mapping = [[<c-\>]],
      direction = 'horizontal',
      size = 15,
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      close_on_exit = true,
    },
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "[T]oggle [T]erminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "[T]erminal [F]loat" },
      { "<leader>tm", "<cmd>TermExec cmd='tmux new -s float 2>/dev/null || tmux attach -t float' direction=float<cr>", desc = "[T]erminal t[M]ux" },
      { "<leader>ht", "<cmd>TermExec cmd='herdr' direction=float<cr>", desc = "[H]erdr [T]erminal" },
      { "<leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Terminal [1]" },
      { "<leader>t2", "<cmd>2ToggleTerm<cr>", desc = "Terminal [2]" },
      { "<leader>t3", "<cmd>3ToggleTerm<cr>", desc = "Terminal [3]" },
      { "<leader>tn", "<cmd>TermExec cmd=''<cr>", desc = "[T]erminal [N]ew" },
    },
  },

  -- PROJECT.NVIM
  -- WHAT: Auto-detects project root directories (where .git, package.json, etc. are)
  -- TO CHANGE: Modify patterns to add/remove root markers
  -- EFFECT: Enables project-aware features like Telescope project switching
  --         Helps plugins know where your project starts and ends
  -- LOADING: VeryLazy = loads after UI is ready
  {
    "folke/project.nvim",
    event = 'VeryLazy',
    config = function()
      require("project_nvim").setup({
        detection_methods = { "lsp", "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
      })
    end,
  },

  -- ============================================================================
  -- SECTION 6.10: GIT INTEGRATION
  -- ============================================================================
  -- Plugins for working with git inside Neovim.

  -- NEOGIT
  -- WHAT: A full git interface inside Neovim (like Magit for Emacs)
  -- TO CHANGE: Remove if you prefer LazyGit or command-line git
  -- EFFECT: Press <leader>gs to open git status; <leader>gc to commit
  --         Press <leader>gp to push; provides staging, diffing, and more
  -- LOADING: keys = only loads when you press the keybindings
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
    keys = {
      { "<leader>gs", "<cmd>Neogit<cr>", desc = "[G]it [S]tatus (Neogit)" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "[G]it [C]ommit" },
      { "<leader>gp", "<cmd>Neogit push<cr>", desc = "[G]it [P]ush" },
    },
  },

  -- AUTO-SESSION
  -- WHAT: Automatically saves and restores Neovim sessions
  -- TO CHANGE: Modify suppressed_dirs to prevent session saving in certain dirs
  -- EFFECT: When you open Neovim in a directory, it restores your previous session
  --         (open files, window layout, cursor positions)
  -- IMPORTANT: Must load at startup (lazy=false) for auto-restore to work
  {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
      require("auto-session").setup({
        log_level = "error",
        suppressed_dirs = { "~/", "~/Downloads", "/etc" },
        pre_save_cmds = {
          function()
            pcall(vim.cmd, 'Neotree close')
          end,
        },
      })
    end,
  },

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
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
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
      'rcarriga/nvim-dap-ui',      -- Visual UI for the debugger
      'nvim-neotest/nvim-nio',     -- Required by dap-ui
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
      local ok_dap, dap = pcall(require, 'dap')
      if not ok_dap then return end

      local ok_dapui, dapui = pcall(require, 'dapui')
      if ok_dapui then
        dapui.setup()
        dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
        dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
        dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end
      end

      -- Python debugging with debugpy
      local debugpy_path = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
      local ok_dap_python, dap_python = pcall(require, 'dap-python')
      if ok_dap_python then
        dap_python.setup(debugpy_path)
      end
    end,
  },

  -- ============================================================================
  -- SECTION 6.14: REMOTE DEVELOPMENT
  -- ============================================================================
  -- Plugins for working on remote machines.

  -- REMOTE-NVIM
  -- WHAT: SSH into remote machines and develop there with full Neovim features
  -- TO CHANGE: Remove if you don't do remote development
  -- EFFECT: <leader>rc to connect to a remote machine; <leader>rd to disconnect
  --         You get LSP, debugging, and all your plugins on the remote machine
  -- LOADING: keys = only loads when you press the keybindings
  {
    'amitds1997/remote-nvim.nvim',
    version = '0.*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'mfussenegger/nvim-dap',
    },
    opts = {},
    keys = {
      { '<leader>rc', '<cmd>RemoteConnect<cr>', desc = '[R]emote [C]onnect' },
      { '<leader>rd', '<cmd>RemoteDisconnect<cr>', desc = '[R]emote [D]isconnect' },
      { '<leader>rs', '<cmd>RemoteStop<cr>', desc = '[R]emote [S]top' },
      { '<leader>rl', '<cmd>RemoteLog<cr>', desc = '[R]emote [L]og' },
    },
  },

  -- ============================================================================
  -- SECTION 6.15: BOOKMARKS
  -- ============================================================================
  -- Plugins for marking and navigating to important lines.

  -- TELESCOPE-VIM-BOOKMARKS
  -- WHAT: Toggle bookmarks and list them with Telescope
  -- TO CHANGE: Remove if you don't use bookmarks
  -- EFFECT: mm to toggle bookmark; mn/mp to jump between bookmarks
  --         <leader>mb to list all bookmarks in Telescope
  -- LOADING: keys = only loads when you press the keybindings
  {
    'tom-anders/telescope-vim-bookmarks.nvim',
    dependencies = { 'MattesGroeger/vim-bookmarks' },
    keys = {
      { 'mm', '<cmd>BookmarkToggle<cr>', desc = '[B]ookmark [T]oggle' },
      { 'mi', '<cmd>BookmarkAnnotate<cr>', desc = '[B]ookmark [A]nnotate' },
      { 'mn', '<cmd>BookmarkNext<cr>', desc = '[B]ookmark [N]ext' },
      { 'mp', '<cmd>BookmarkPrev<cr>', desc = '[B]ookmark [P]revious' },
      { '<leader>mb', '<cmd>Telescope vim_bookmarks<cr>', desc = '[B]ookmark [L]ist' },
    },
    config = function()
      require('telescope').load_extension('vim_bookmarks')
    end,
  },

  -- ============================================================================
  -- SECTION 6.16: VISUAL ENHANCEMENTS
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
      require('hlchunk').setup({
        chunk = {
          enable = true,
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
          delay = 0,
          chars = { '│' },
          style = { { fg = '#4a4560' } },
        },
      })
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
    'norcalli/nvim-colorizer.lua',
    event = 'BufRead',
    opts = {},
  },

  -- NEOSCROLL
  -- WHAT: Smooth animated scrolling on wheel and Ctrl-u/d
  -- TO CHANGE: Adjust lines/time in setup
  -- EFFECT: Scrolling feels eased instead of jumping
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'karb94/neoscroll.nvim',
    event = 'VeryLazy',
    config = function()
      require('neoscroll').setup {
        -- ponytail: defaults are fine; tuned easing for feel
        easing_function = 'quadratic',
        hide_cursor = true,
      }
    end,
  },

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, { ---@diagnostic disable-line: missing-fields
  rocks = { enabled = false },
  performance = {
    rtp = {
      -- Disable unused built-in Neovim plugins for faster startup (saves 10-20ms)
      disabled_plugins = {
        'gzip',       -- Gzip file reading/writing (not needed)
        'tar',        -- Tar file reading/writing (not needed)
        'tohtml',     -- Convert to HTML (not needed)
        'tutor',      -- Vim tutorial (not needed)
        'netrwPlugin', -- Netrw file browser (replaced by neo-tree)
        'matchit',    -- Extended % matching (replaced by mini.ai)
        'matchparen', -- Highlight matching parentheses (replaced by mini.ai)
        '2html_plugin', -- Convert to HTML (not needed)
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

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et

-- ============================================================================
-- SECTION 7: TERMINAL KEYMAPS
-- ============================================================================
-- WHAT: Adds better navigation keybindings when inside a terminal buffer
-- TO CHANGE: Remove this autocmd if you don't use terminal mode
-- EFFECT: In terminal mode: jk exits to normal mode, Ctrl+H/J/K/L switches windows
--         Ctrl+W works normally (passes through to window commands)
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('terminal-keymaps', { clear = true }),
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
    vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
    vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
  end,
})

-- ============================================================================
-- SECTION 8: PROJECT SWITCHING
-- ============================================================================
-- WHAT: Quick project switching via Telescope (like VS Code's Ctrl+R)
-- TO CHANGE: Change <C-r> to your preferred key
-- EFFECT: Opens a list of recently used projects; select one to switch to
vim.keymap.set('n', '<C-r>', '<cmd>Telescope projects<cr>', { desc = 'Open [R]ecent Projects' })

-- ============================================================================
-- SECTION 9: FILETYPE DETECTION
-- ============================================================================
-- WHAT: Custom rules for detecting file types based on file content
-- TO CHANGE: Add more patterns for your specific file types
-- EFFECT: Files matching the pattern get the correct filetype and LSP

-- BUN SHEBANG DETECTION
-- WHAT: Detects Bun runtime in shebang lines and sets filetype to typescript
-- TO CHANGE: Modify the pattern to match different shebangs
-- EFFECT: Files with #!/usr/bin/env bun become TypeScript files,
--         so TypeScript LSP and formatting work correctly
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('bun-shebang-detection', { clear = true }),
  callback = function(args)
    local first_line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ""
    if first_line:match('^#!.*bin.*[ /]bun%s*$') or first_line:match('^#!.*bin.*[ /]bun ') then
      -- FIX: Index vim.bo like a table instead of calling it
      vim.bo[args.buf].filetype = 'typescript'
      
      -- Trigger FileType autocommands so LSPs attach after filetype is set
      vim.api.nvim_exec_autocmds('FileType', { buffer = args.buf })
    end
  end,
})
