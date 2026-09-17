-- QoL (Quality of Life) plugins — high-impact workflow improvements
---@module 'lazy'
---@type LazySpec
return {
  -- Git blame inline + hover
  { 'FabijanZulj/blame.nvim', cmd = 'BlameToggle', keys = { { '<leader>gb', '<cmd>BlameToggle<cr>', desc = 'Git Blame' } }, opts = {} },

  -- Refactoring (uses LSP code actions + treesitter; async.nvim provides the async module)
  { 'ThePrimeagen/refactoring.nvim', dependencies = { 'lewis6991/async.nvim', 'nvim-treesitter/nvim-treesitter' }, keys = { { '<leader>rr', function() require('refactoring').select_refactor() end, mode = { 'n', 'v' }, desc = 'Refactor' } }, opts = {} },

  -- Test runner UI (neotest)
  { 'nvim-neotest/neotest', dependencies = { 'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter', 'antoinemadec/FixCursorHold.nvim', 'nvim-neotest/neotest-python' }, keys = { { '<leader>tr', function() require('neotest').run.run() end, desc = 'Test Run' }, { '<leader>ts', function() require('neotest').summary.toggle() end, desc = 'Test Summary' }, { '<leader>to', function() require('neotest').output_panel.toggle() end, desc = 'Test Output' } }, config = function() require('neotest').setup { adapters = { require('neotest-python')({ dap = { justMyCode = false } }) } } end },

  -- HTTP client (rest.nvim)
  { 'rest-nvim/rest.nvim', ft = 'http', dependencies = { 'nvim-lua/plenary.nvim' }, config = function() require('rest-nvim').setup({ result = { split = { horizontal = false } } }) end },

  -- Outline sidebar (aerial.nvim)
  { 'stevearc/aerial.nvim', keys = { { '<leader>o', '<cmd>AerialToggle<cr>', desc = 'Outline' } }, opts = { layout = { min_width = 28 }, attach_mode = 'global', backends = { 'lsp', 'treesitter', 'markdown', 'man' } } },

  -- Command palette (dressing.nvim - enhances vim.ui.select/input with telescope)
  { 'stevearc/dressing.nvim', event = 'VeryLazy', opts = { input = { enabled = true }, select = { enabled = true, backend = { 'telescope', 'builtin' } } } },

  -- Better quickfix (bqf.nvim)
  { 'kevinhwang91/nvim-bqf', ft = 'qf', opts = { preview = { win_height = 15, win_vheight = 15, delay_syntax = 50, border_chars = { '│', '│', '─', '─', '╭', '╮', '╰', '╯' } } } },

  -- Project-wide search/replace UI (grug-far.nvim — faster than spectre)
  { 'MagicDuck/grug-far.nvim', keys = { { '<leader>fr', function() require('grug-far').open() end, desc = 'Find & Replace (grug-far)' } }, opts = { engine = 'ripgrep' } },
}