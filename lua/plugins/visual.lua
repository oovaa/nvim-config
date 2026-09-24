-- lua/plugins/visual.lua — SECTION 6.1: UI & VISUAL ENHANCEMENTS
-- Plugins that change how Neovim looks and feels.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- GUESS INDENT
  -- WHAT: Automatically detects indentation settings (tabs vs spaces, width)
  -- TO CHANGE: Remove this plugin if you prefer manual settings
  -- EFFECT: When you open a file, it detects if it uses 2-space, 4-space, or tabs
  --         and sets your indent settings accordingly. Very small, safe to keep.
  { 'NMAC427/guess-indent.nvim', event = 'BufReadPost', opts = {} },

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

  -- NOICE (removed — snacks notifier+input cover messages/cmdline/search;
  -- no heavy UI layer, no macro/notify interception. One-line revert below.)
  -- {
  --   'folke/noice.nvim',
  --   event = 'VeryLazy',
  --   dependencies = { 'MunifTanjim/nui.nvim', 'folke/snacks.nvim' },
  --   opts = {
  --     presets = {
  --       bottom_search = true,
  --       lsp_doc_border = true,
  --     },
  --   },
  -- },

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
        { '<leader>m', group = '[M]olten & Book[m]arks' },
        { '<leader>d', group = '[D]ebug' },
        { '<leader>f', group = '[F]ormat / [F]ind' },
        { '<leader>r', group = '[R]un' },
        { '<leader>g', group = '[G]it' },
        { '<leader>h', group = '[H]TTP' },
        { '<leader>u', group = '[U]I' },
        { '<leader>y', group = '[Y]ank' },
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
    -- ponytail: cmd-only library now — daily <leader>s*/ls keys moved to
    -- snacks.picker above. Kept for vim_bookmarks (<leader>mb) + ui-select.
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded. Need both make and cmake on some systems.
        cond = function() return vim.fn.executable 'make' == 1 and vim.fn.executable 'cmake' == 1 end,
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
      -- (picker keymaps live in the spec `keys` above so each loads the plugin on first press)
    end,
  },
}
