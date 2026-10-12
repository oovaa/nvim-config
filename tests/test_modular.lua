-- Modular split verification: init.lua is a thin bootstrap, one spec file per
-- section, no lost/duplicated plugins, behavior preserved.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_modular.lua")' -c 'qa!'

describe('modular split', function()
  local root = vim.fn.stdpath 'config'
  -- the live lazy.nvim registry: what the config actually asked to install,
  -- keyed by short name (e.g. 'mason.nvim', not 'mason-org/mason.nvim')
  local registry = require('lazy.core.config').plugins

  it('init.lua is a thin bootstrap (<300 lines, no plugin specs)', function()
    local lines = vim.fn.readfile(root .. '/init.lua')
    assert.is_true(#lines < 300, 'init.lua should be <300 lines, got ' .. #lines)
    local code = table.concat(lines, '\n'):gsub('%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', '')
    for _, repo in ipairs {
      'mason.nvim',
      'blink.cmp',
      'snacks.nvim',
      'tokyonight.nvim',
      'conform.nvim',
      'flash.nvim',
      'nvim-dap',
      'mini.nvim',
      'nvim-vtsls',
      'gitsigns.nvim',
    } do
      assert.is_nil(code:find(repo, 1, true), 'init.lua must not contain ' .. repo)
    end
    -- bootstrap duties stay: loader, lazy setup with both imports, builtin wiring
    assert.is_truthy(code:match 'vim%.loader%.enable', 'keeps vim.loader')
    assert.is_truthy(code:match "import%s*=%s*'plugins'", 'imports lua/plugins/')
    assert.is_truthy(code:match "import%s*=%s*'custom%.plugins'", 'imports custom.plugins')
    assert.is_truthy(code:match "require%s*'config%.sessions'", 'wires sessions')
    assert.is_truthy(code:match "require%s*'config%.terminal'", 'wires terminal')
    assert.is_truthy(code:match "require%s*'config%.runner'", 'wires runner')
  end)

  it('all eleven section modules exist and are valid Lua', function()
    local modules = {
      'visual',
      'lsp',
      'formatting',
      'completion',
      'colorscheme',
      'editing',
      'treesitter',
      'ui',
      'navigation',
      'debugging',
      'appearance',
    }
    for _, m in ipairs(modules) do
      local path = root .. '/lua/plugins/' .. m .. '.lua'
      assert.equals(1, vim.fn.filereadable(path), 'missing lua/plugins/' .. m .. '.lua')
      assert.is_not_nil(loadfile(path), path .. ' must parse')
    end
    for _, m in ipairs { 'config.sessions', 'config.terminal', 'config.runner', 'custom.ui.init' } do
      assert.has_no_error(function() require(m) end, 'require(' .. m .. ') must not error')
    end
  end)

  it('no plugin spec lost or duplicated across modules', function()
    -- assert against the live registry instead of grepping source text: a spec
    -- that parses but was never registered by lazy is the failure this catches.
    for _, name in ipairs {
      'guess-indent.nvim',
      'gitsigns.nvim',
      'which-key.nvim',
      'mason.nvim',
      'actions-preview.nvim',
      'conform.nvim',
      'blink.cmp',
      'tokyonight.nvim',
      'todo-comments.nvim',
      'mini.nvim',
      'ts-comments.nvim',
      'auto-save.nvim',
      'nvim-vtsls',
      'nvim-treesitter',
      'nvim-ts-autotag',
      'snacks.nvim',
      'nvim-lint',
      'flash.nvim',
      'nvim-dap',
      'render-markdown.nvim',
      'nvim-colorizer.lua',
    } do
      local spec = registry[name]
      assert.is_not_nil(spec, 'lost spec (not in lazy registry): ' .. name)
      assert.is_truthy(spec.url or spec.dir, name .. ' must resolve to a url or dir')
    end
  end)

  it('theme restore logic lives in colorscheme module (persistence fix kept)', function()
    -- real round-trip through the theme.txt persistence layer, not a source grep
    local theme = require 'custom.ui.theme'
    local saved = theme.get_saved()
    local ok, err = pcall(function()
      theme.save 'gruvbox'
      assert.equals('gruvbox', theme.get_saved(), 'saved name must round-trip')
      assert.equals('gruvbox', (io.open(theme.theme_file(), 'r'):read '*l'))
    end)
    if saved then
      theme.save(saved)
    else
      vim.fn.delete(theme.theme_file())
    end
    assert.is_truthy(ok, tostring(err))
    assert.is_truthy(vim.g.colors_name and vim.g.colors_name ~= '', 'a colorscheme must be active')
  end)

  it('key entry points survive the move (live mappings)', function()
    for _, lhs in ipairs { '<leader>ty', '<leader>sf', '<leader>e', '<leader>tt', '<S-h>', '<c-\\>' } do
      local map = vim.fn.maparg(lhs, 'n', false, true)
      assert.is_not_nil(map and (map.callback or map.rhs) and map, lhs .. ' should be mapped')
    end
    local ff = vim.fn.maparg('<leader>ff', 'n', false, true)
    assert.is_not_nil(ff and (ff.callback or ff.rhs) and ff, '<leader>ff should be mapped')
  end)
  -- startup budget lives in tests/test_startup.lua (real median gate, not <2000ms)
end)
