-- Phase 2: Performance Optimizations Tests
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_performance.lua")' -c 'qa!'

describe('Phase 2: Performance Optimizations', function()

  -- Test 1: Themes load lazily except tokyonight
  describe('themes', function()
    it('11 extra themes are lazy=true, only tokyonight is eager', function()
      local themes_path = vim.fn.stdpath('config') .. '/lua/custom/plugins/themes.lua'
      print('DEBUG test: themes_path =', themes_path)
      local content = table.concat(vim.fn.readfile(themes_path), '\n')
      print('DEBUG test: content len =', #content)
      -- Convert to single line for multiline pattern matching
      local content_single_line = content:gsub('\n', ' ')
      print('DEBUG test: single line len =', #content_single_line)
      print('DEBUG test: single line[600:700] =', content_single_line:sub(600, 700))

      local theme_names = {'catppuccin','rose-pine','gruvbox','kanagawa','onedark',
                           'nightfox','everforest','dracula','github-theme',
                           'melange','poimandres'}
      for _, name in ipairs(theme_names) do
        -- Each theme should have lazy = true
        -- Escape magic characters in name for Lua pattern matching
        local escaped_name = name:gsub('%-', '%%-')
        local pattern = escaped_name .. '.*lazy%s*=%s*true'
        local match = content_single_line:match(pattern)
        print('DEBUG test: name =', name, 'match =', match and 'YES' or 'NO')
        assert.is_truthy(match, name .. ' should have lazy = true')
      end
      -- tokyonight should NOT be lazy (it's in init.lua with lazy=false or default eager loading)
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local init_content = table.concat(vim.fn.readfile(init_path), '\n')
      -- Check that tokyonight doesn't have lazy = true (meaning it loads eagerly)
      local tokyonight_section = init_content:match("folke/tokyonight%.nvim[^}]*}")
      assert.is_not_nil(tokyonight_section, 'tokyonight should be in init.lua')
      assert.is_falsy(tokyonight_section:match('lazy%s*=%s*true'), 'tokyonight should not have lazy = true')
      assert.is_truthy(init_content:match('tokyonight.*priority%s*=%s*1000'), 'tokyonight should have priority=1000')
    end)
  end)

  -- Test 2: LSP uses native vim.lsp.config (nvim-lspconfig removed)
  describe('lspconfig (removed)', function()
    it('has no nvim-lspconfig dependency; servers defined natively', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')
      content = content:gsub('%-%-[^\n]*', '') -- strip comments: check code, not prose

      -- nvim-lspconfig and its mason bridge must be gone
      assert.is_falsy(content:match('nvim%-lspconfig'),
        'should not depend on nvim-lspconfig')
      assert.is_falsy(content:match('mason%-lspconfig'),
        'should not depend on mason-lspconfig')
      assert.is_falsy(content:match("require%s*%(?%s*['\"]lspconfig"),
        'should not require lspconfig anywhere')
      -- ...with native definitions carrying their own cmd/filetypes
      assert.is_truthy(content:match("vim%.lsp%.config%('vtsls'"),
        'vtsls should be defined via vim.lsp.config')
      assert.is_truthy(content:match('docker%-langserver'),
        'dockerls cmd should be defined natively')
      assert.is_truthy(content:match('docker%-compose%-langserver'),
        'docker_compose_language_service cmd should be defined natively')
    end)
  end)

  -- Test 3: snacks.nvim only enables needed modules
  describe('snacks.nvim', function()
    it('only enables input, notifier, scratch, scope, words, indent', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      assert.is_truthy(content:match("snacks%.nvim"), 'snacks.nvim should exist')

      -- Check enabled modules
      assert.is_truthy(content:match("input%s*=%s*{%s*enabled%s*=%s*true"), 'input should be enabled')
      assert.is_truthy(content:match("notifier%s*=%s*{%s*enabled%s*=%s*true"), 'notifier should be enabled')
      assert.is_truthy(content:match("scratch%s*=%s*{%s*ft%s*=%s*['\"]markdown"), 'scratch should have ft=markdown')
      assert.is_truthy(content:match("scope%s*=%s*{%s*enabled%s*=%s*true"), 'scope should be enabled')
      assert.is_truthy(content:match("words%s*=%s*{%s*enabled%s*=%s*true"), 'words should be enabled')

      -- Check disabled modules
      assert.is_truthy(content:match("indent%s*=%s*{%s*enabled%s*=%s*true"), 'indent should be enabled (replaces hlchunk)')
      assert.is_truthy(content:match("scroll%s*=%s*{%s*enabled%s*=%s*false"), 'scroll should be disabled')
      assert.is_truthy(content:match("statuscolumn%s*=%s*{%s*enabled%s*=%s*false"), 'statuscolumn should be disabled')
      assert.is_truthy(content:match("toggle%s*=%s*{%s*enabled%s*=%s*false"), 'toggle should be disabled')
    end)
  end)

  -- Test 4: treesitter parsers install on-demand
  describe('treesitter', function()
    it('has no upfront TSInstall loop for 15 parsers', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      local has_bulk_install = content:match('for _, lang in ipairs%s*{') and content:match('vim%.cmd%s*[\'"]TSInstall')
      assert.is_falsy(has_bulk_install, 'Should not have bulk TSInstall loop for 15 parsers')
    end)

    it('has FileType autocmd that triggers TSInstall for missing parsers', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      assert.is_truthy(content:match('treesitter%-start') or content:match('vim%.treesitter%.start'))
      assert.is_truthy(content:match('fs_stat%(parser%)') and content:match('TSInstall'),
        'Should check for parser and install on demand')
    end)
  end)

  -- Test 5: fzf-native has cmake cond
  describe('telescope-fzf-native', function()
    it('has cond checking for make and cmake', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      assert.is_truthy(content:match("telescope%-fzf%-native%.nvim"), 'fzf-native should be a dependency')
      assert.is_truthy(content:match("executable.*make.*==.*1") and content:match("executable.*cmake.*==.*1"),
        'fzf-native cond should check for both make and cmake')
    end)
  end)

  -- Test 6: nvim-ts-autotag loads on ft
  describe('nvim-ts-autotag', function()
    it('loads on specific filetypes (html, jsx, tsx, etc.)', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      assert.is_truthy(content:match("nvim%-ts%-autotag"), 'nvim-ts-autotag should exist')
      assert.is_truthy(content:match("nvim%-ts%-autotag.-ft%s*="), 'Should have ft configuration')
      assert.is_truthy(content:match("typescriptreact"), 'Should include typescriptreact')
      assert.is_truthy(content:match("javascriptreact"), 'Should include javascriptreact')
    end)
  end)

  -- Test 7: Startup performance target
  describe('startup performance', function()
    it('has vim.loader.enable and lazy.nvim cache enabled', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local content = table.concat(vim.fn.readfile(init_path), '\n')

      assert.is_truthy(content:match('vim%.loader%.enable'))
      assert.is_truthy(content:match('cache%s*=%s*{%s*enabled%s*=%s*true'))
      assert.is_truthy(content:match('disabled_plugins'))
    end)
  end)

  -- Test 8: hlchunk deleted, colorizer/image narrowly triggered
  describe('hlchunk/colorizer/image triggers', function()
    it('hlchunk spec is gone; colorizer+image load on ft only', function()
      local init_path = vim.fn.stdpath('config') .. '/init.lua'
      local init_content = table.concat(vim.fn.readfile(init_path), '\n')
      local code = init_content:gsub('%-%-[^\n]*', '') -- strip comments: check code, not prose
      assert.is_nil(code:match('hlchunk'), 'hlchunk spec should be deleted (snacks.indent owns guides)')
      -- scope assertions to each plugin's spec block (nearest closing `},`)
      local cz = code:match("'catgoose/nvim%-colorizer%.lua'.-\n  %},")
      assert.is_not_nil(cz, 'colorizer spec should exist')
      assert.is_truthy(cz:match("ft%s*=%s*{[^}]*'css'"), 'colorizer should load on ft, not every BufReadPost')
      assert.is_falsy(cz:match("event%s*="), 'colorizer must not load on every file open')
      local plugins_path = vim.fn.stdpath('config') .. '/lua/custom/plugins/init.lua'
      local plugins_code = table.concat(vim.fn.readfile(plugins_path), '\n'):gsub('%-%-[^\n]*', '')
      local img = plugins_code:match("'3rd/image%.nvim',.-\n  %},")
      assert.is_not_nil(img, 'image.nvim spec should exist')
      assert.is_truthy(img:match("ft%s*=%s*{[^}]*'markdown'"), 'image.nvim should load for markdown only')
      assert.is_falsy(img:match("event%s*="), 'image.nvim must not load on every file open')
    end)
  end)

end)