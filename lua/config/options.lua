---@module 'config.options'
-- Editor options, leader key, provider disables, diagnostics config.
-- Loaded from init.lua before lazy.nvim so <leader> and vim.o apply early.

-- ============================================================================
-- PROVIDER DISABLES
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
vim.g.loaded_perl_provider = 0 -- Disable Perl provider (not used)
vim.g.loaded_ruby_provider = 0 -- Disable Ruby provider (not used)
vim.g.loaded_node_provider = 0 -- Disable Node provider (no :Node remote plugins used)

-- ============================================================================
-- BUILT-IN PLUGIN DISABLES
-- ============================================================================
-- WHAT: Neovim ships legacy Vimscript plugins that load on their trigger.
--        neo-tree replaces netrw; the rest are unused. Skipping them saves
--        a few ms and avoids netrw/neo-tree explorer conflicts.
-- TO CHANGE: Remove any line if you want that built-in back.
-- EFFECT: 0 = never sourced. Check with `:checkhealth vim` or :scriptnames.
-- ============================================================================
vim.g.loaded_netrw = 1 -- File explorer (replaced by neo-tree)
vim.g.loaded_netrwPlugin = 1 -- netrw remote reading (curl/wget wrappers)
vim.g.loaded_2html_plugin = 1 -- :TOhtml export
vim.g.loaded_gzip = 1 -- Transparent .gz editing
vim.g.loaded_tarPlugin = 1 -- Transparent .tar browsing
vim.g.loaded_zipPlugin = 1 -- Transparent .zip browsing
vim.g.loaded_tutor_mode_plugin = 1 -- :Tutor

-- ============================================================================
-- LEADER KEY
-- ============================================================================
-- MUST be set before plugins load: plugin specs define <leader> keymaps.
vim.g.mapleader = ' '

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
vim.o.clipboard = 'unnamedplus'

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

-- REDRAW BEHAVIOR
-- WHAT: Defers intermediate screen redraws while running macros/scripts
-- TO CHANGE: Set to false if you want every intermediate visual update
-- EFFECT: true = smoother/faster macros and large multi-step edits
-- NOTE: Disabled because it conflicts with Noice.nvim
vim.o.lazyredraw = false

-- SYNTAX COLUMN LIMIT
-- WHAT: Stops regex syntax highlighting after this many columns on a line
-- TO CHANGE: Increase for full long-line highlighting, decrease for more speed
-- EFFECT: Improves responsiveness on minified/very long lines
vim.o.synmaxcol = 300

-- LARGE FILE THRESHOLD
-- WHAT: Shared size cap (bytes) for "large file mode" safeguards in autocmds/plugins
-- TO CHANGE: Raise/lower based on your machine and file mix
-- EFFECT: Files above this size get less expensive runtime features
vim.g.large_file_size = 1024 * 1024 -- 1 MiB

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

-- SMOOTH SCROLL (replaces neoscroll.nvim — builtin line-wise smooth scroll)
vim.o.smoothscroll = true

-- FLOAT BORDER (builtin, replaces dressing.nvim — borders on cmdline, quickfix,
-- help peek, incsearch split preview, terminal float, etc.)
-- Plugins that set their own borders (noice, blink, telescope) are unaffected.
vim.o.winborder = 'rounded'

-- CONFIRM DIALOG
-- WHAT: Shows a confirmation when trying to quit with unsaved changes
-- TO CHANGE: Set to false for classic behavior (error message instead)
-- EFFECT: true = asks "Save changes?" dialog instead of error
vim.o.confirm = true

-- ============================================================================
-- DIAGNOSTIC CONFIGURATION
-- ============================================================================
-- WHAT: Configures how Neovim shows errors, warnings, and hints
-- TO CHANGE: Set virtual_text = false to hide inline error text
-- EFFECT: Controls appearance of LSP/linter diagnostics
vim.diagnostic.config {
  update_in_insert = false, -- Don't update diagnostics while typing
  severity_sort = true, -- Sort by severity (errors first)
  float = { border = 'rounded', source = 'if_many' }, -- Floating window style
  underline = { severity = { min = vim.diagnostic.severity.WARN } }, -- Underline warnings+
  virtual_text = true, -- Inline error text at end of line
  jump = { on_jump = true }, -- Auto-open float when jumping to diagnostic
}
