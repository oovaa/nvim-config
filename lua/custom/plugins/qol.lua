-- QoL (Quality of Life) plugins — high-impact workflow improvements
---@module 'lazy'
---@type LazySpec
return {
  -- Git blame inline + hover
  { 'FabijanZulj/blame.nvim', cmd = 'BlameToggle', keys = { { '<leader>gb', '<cmd>BlameToggle<cr>', desc = 'Git Blame' } }, opts = {} },

  -- Merge conflict resolution: highlights conflicted hunks, maps co/ct/cb/c0 +
  -- ]x/[x (buffer-local, conflicted files only). BufReadPre is deliberate: the
  -- plugin fetches conflicts on its own BufRead autocmd, which only exists once
  -- setup() ran — any later trigger (VeryLazy) would miss the file you opened
  -- nvim with. version='*' = newest tag (upstream: main can be unstable).
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    event = 'BufReadPre',
    config = true,
    -- Upstream (last release 2024-11) still calls the deprecated
    -- vim.highlight / vim.validate{table} forms, which trip
    -- `:checkhealth vim.deprecated`. Re-apply the minimal modernization on
    -- every install/update so a clean machine stays deprecation-clean.
    build = function()
      local root = vim.fn.stdpath 'data' .. '/lazy/git-conflict.nvim'
      local edits = {
        { root .. '/lua/git-conflict/git-conflict.lua', { { 'vim%.highlight%.priorities%.user', 'vim.hl.priorities.user' } } },
        {
          root .. '/lua/git-conflict/colors.lua',
          { { "vim%.validate%({ rgb_24bit = { rgb_24bit, 'n', true } }%)", "vim.validate('rgb_24bit', rgb_24bit, 'number', true)" } },
        },
      }
      for _, item in ipairs(edits) do
        if vim.fn.filereadable(item[1]) == 1 then
          local lines = vim.fn.readfile(item[1])
          for i, line in ipairs(lines) do
            for _, r in ipairs(item[2]) do
              lines[i] = (lines[i] or line):gsub(r[1], r[2])
            end
          end
          vim.fn.writefile(lines, item[1])
        end
      end
    end,
  },

  -- Refactoring (uses LSP code actions + treesitter; async.nvim provides the async module)
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = { 'lewis6991/async.nvim', 'nvim-treesitter/nvim-treesitter' },
    keys = { { '<leader>rr', function() require('refactoring').select_refactor() end, mode = { 'n', 'v' }, desc = 'Refactor' } },
    opts = {},
  },

  -- Test runner UI (neotest)
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
      'marilari88/neotest-vitest',
      'nvim-neotest/neotest-jest',
      'fredrikaverpil/neotest-golang',
    },
    keys = {
      { '<leader>tr', function() require('neotest').run.run() end, desc = 'Test Run' },
      { '<leader>ts', function() require('neotest').summary.toggle() end, desc = 'Test Summary' },
      { '<leader>to', function() require('neotest').output_panel.toggle() end, desc = 'Test Output' },
    },
    config = function()
      local adapters = { require 'neotest-python' { dap = { justMyCode = false } } }
      -- Optional adapters: missing plugins must not break the others.
      for _, spec in ipairs { 'neotest-vitest', 'neotest-jest', 'neotest-golang' } do
        local ok, adapter = pcall(require, spec)
        if ok then
          if type(adapter) == 'function' then adapter = adapter {} end
          table.insert(adapters, adapter)
        end
      end
      require('neotest').setup { adapters = adapters }
    end,
  },

  -- HTTP client (rest.nvim)
  {
    'rest-nvim/rest.nvim',
    ft = 'http',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function() require('rest-nvim').setup { result = { split = { horizontal = false } } } end,
  },

  -- Outline sidebar (aerial.nvim)
  {
    'stevearc/aerial.nvim',
    keys = { { '<leader>o', '<cmd>AerialToggle<cr>', desc = 'Outline' } },
    opts = { layout = { min_width = 28 }, attach_mode = 'global', backends = { 'lsp', 'treesitter', 'markdown', 'man' } },
  },

  -- Command palette: vim.ui.input via snacks.nvim; vim.ui.select is claimed by
  -- snacks in lua/plugins/ui.lua (the spec's own config function).

  -- Better quickfix (bqf.nvim)
  {
    'kevinhwang91/nvim-bqf',
    ft = 'qf',
    opts = { preview = { win_height = 15, win_vheight = 15, delay_syntax = 50, border_chars = { '│', '│', '─', '─', '╭', '╮', '╰', '╯' } } },
  },

  -- Project-wide search/replace UI (grug-far.nvim — faster than spectre)
  {
    'MagicDuck/grug-far.nvim',
    keys = { { '<leader>fr', function() require('grug-far').open() end, desc = 'Find & Replace (grug-far)' } },
    opts = { engine = 'ripgrep' },
  },

  -- Paste clipboard image into markdown (img-clip.nvim)
  {
    'HakonHarnes/img-clip.nvim',
    ft = 'markdown',
    keys = { { '<leader>p', '<cmd>PasteImage<cr>', desc = 'Paste image from clipboard', ft = 'markdown' } },
    opts = {
      default = {
        dir_path = 'assets',
        relative_to_current_file = true,
      },
      -- ponytail: stock markdown template leaves alt text empty ($CURSOR);
      -- filetype opts beat default.*, so the override must live here, not in
      -- default. Reuses the prompted file name: ![name](path), no 2nd edit.
      filetypes = {
        markdown = {
          template = '![$FILE_NAME_NO_EXT]($FILE_PATH)',
        },
      },
    },
  },
}
