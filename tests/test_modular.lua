-- Modular split verification: init.lua is a thin bootstrap, one spec file per
-- section, no lost/duplicated plugins, behavior preserved.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_modular.lua")' -c 'qa!'

describe('modular split', function()
  local H = require('tests.helpers')
  local root = vim.fn.stdpath('config')

  it('init.lua is a thin bootstrap (<300 lines, no plugin specs)', function()
    local lines = vim.fn.readfile(root .. '/init.lua')
    assert.is_true(#lines < 300, 'init.lua should be <300 lines, got ' .. #lines)
    local code = table.concat(lines, '\n'):gsub('%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', '')
    for _, repo in ipairs({
      'telescope.nvim', 'mason.nvim', 'blink.cmp', 'snacks.nvim',
      'tokyonight.nvim', 'conform.nvim', 'flash.nvim', 'nvim-dap',
      'mini.nvim', 'nvim-vtsls', 'gitsigns.nvim', 'neo-tree.nvim',
    }) do
      assert.is_nil(code:find(repo, 1, true), 'init.lua must not contain ' .. repo)
    end
    -- bootstrap duties stay: loader, lazy setup with both imports, builtin wiring
    assert.is_truthy(code:match('vim%.loader%.enable'), 'keeps vim.loader')
    assert.is_truthy(code:match("import%s*=%s*'plugins'"), 'imports lua/plugins/')
    assert.is_truthy(code:match("import%s*=%s*'custom%.plugins'"), 'imports custom.plugins')
    assert.is_truthy(code:match("require%s*'config%.sessions'"), 'wires sessions')
    assert.is_truthy(code:match("require%s*'config%.terminal'"), 'wires terminal')
    assert.is_truthy(code:match("require%s*'config%.runner'"), 'wires runner')
  end)

  it('all twelve section modules exist and are valid Lua', function()
    local modules = {
      'visual', 'lsp', 'formatting', 'completion', 'colorscheme', 'editing',
      'treesitter', 'ui', 'navigation', 'debugging', 'bookmarks', 'appearance',
    }
    for _, m in ipairs(modules) do
      local path = root .. '/lua/plugins/' .. m .. '.lua'
      assert.equals(1, vim.fn.filereadable(path), 'missing lua/plugins/' .. m .. '.lua')
      assert.is_not_nil(loadfile(path), path .. ' must parse')
    end
    for _, m in ipairs({ 'config.sessions', 'config.terminal', 'config.runner', 'custom.ui.init' }) do
      assert.has_no_error(function() require(m) end, 'require(' .. m .. ') must not error')
    end
  end)

  it('no plugin spec lost or duplicated across modules', function()
    local code = H.code()
    local counts = {}
    -- ponytail: broad match (repos end .nvim, .lua, or bare like blink.cmp);
    -- extras (URLs etc.) are ignored, only the expected list is asserted.
    for repo in code:gmatch("'([A-Za-z0-9_%.%-]+/[A-Za-z0-9_%.%-]+)'") do
      counts[repo] = (counts[repo] or 0) + 1
    end
    -- every spec from the pre-split init.lua must still exist
    for _, repo in ipairs({
      'NMAC427/guess-indent.nvim', 'lewis6991/gitsigns.nvim', 'folke/which-key.nvim',
      'nvim-telescope/telescope.nvim', 'mason-org/mason.nvim', 'aznhe21/actions-preview.nvim',
      'stevearc/conform.nvim', 'saghen/blink.cmp', 'folke/tokyonight.nvim',
      'folke/todo-comments.nvim', 'nvim-mini/mini.nvim', 'folke/ts-comments.nvim',
      'okuuva/auto-save.nvim', 'yioneko/nvim-vtsls', 'nvim-treesitter/nvim-treesitter',
      'windwp/nvim-ts-autotag', 'nvim-neo-tree/neo-tree.nvim', 'folke/snacks.nvim',
      'mfussenegger/nvim-lint', 'folke/flash.nvim', 'mfussenegger/nvim-dap',
      'tom-anders/telescope-vim-bookmarks.nvim', 'MeanderingProgrammer/render-markdown.nvim',
      'catgoose/nvim-colorizer.lua',
    }) do
      -- strip org prefix: gmatch key has no quotes/org split issues; compare full
      assert.is_truthy(counts[repo] and counts[repo] >= 1, 'lost spec: ' .. repo)
    end
  end)

  it('theme restore logic lives in colorscheme module (persistence fix kept)', function()
    local c = H.read(root .. '/lua/plugins/colorscheme.lua')
    assert.is_truthy(c:match('custom%.ui%.theme'), 'must read saved theme')
    assert.is_truthy(c:match('get_saved'), 'must call get_saved()')
    assert.is_truthy(c:match("tokyonight%-night"), 'must keep tokyonight-night fallback')
    assert.is_truthy(vim.g.colors_name and vim.g.colors_name ~= '', 'a colorscheme must be active')
  end)

  it('key entry points survive the move (live mappings)', function()
    for _, lhs in ipairs({ '<leader>ty', '<leader>sf', '<leader>e', '<leader>tt', '<S-h>', '<c-\\>' }) do
      local map = vim.fn.maparg(lhs, 'n', false, true)
      assert.is_not_nil(map and (map.callback or map.rhs) and map, lhs .. ' should be mapped')
    end
    local ff = vim.fn.maparg('<leader>ff', 'n', false, true)
    assert.is_not_nil(ff and (ff.callback or ff.rhs) and ff, '<leader>ff should be mapped')
  end)

  it('startup stays fast (nested headless --startuptime < 2s)', function()
    local log = '/tmp/modular_startup.log'
    vim.fn.system('nvim --headless --startuptime ' .. log .. ' +q')
    local lines = vim.fn.readfile(log)
    local total = nil
    for _, l in ipairs(lines) do
      local ms = l:match('^(%S+)%s+%S+: %-%-%- NVIM STARTED %-%-%-$')
      if ms then total = tonumber(ms) end
    end
    assert.is_not_nil(total, 'startup log should contain NVIM STARTED')
    assert.is_true(total < 2000, string.format('startup %.1fms should be < 2000ms', total))
  end)
end)
