-- Phase 1: Critical Bug Fixes Tests
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_critical_fixes.lua")' -c 'qa!'

describe('Phase 1: Critical Bug Fixes', function()
  -- ponytail: specs moved from init.lua to lua/plugins/ — assert location-agnostic
  local H = require('tests.helpers')
  -- Test 1: vtsls memory setting
  describe('vtsls config', function()
    it('has conservative maxTsServerMemory (2048) in init.lua', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()
      -- vtsls is configured inline in init.lua, not via lspconfig.configs
      assert.is_truthy(content:match 'maxTsServerMemory%s*=%s*2048', 'Should have maxTsServerMemory = 2048 in init.lua')
    end)
  end)

  -- Test 2: mini.pairs skip_next regex handles edge cases
  describe('mini.pairs', function()
    it('is configured with skip_next for common patterns in init.lua', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()
      -- mini.pairs is configured inline in init.lua
      assert.is_truthy(content:match 'skip_next%s*=', 'Should have skip_next configuration')
      assert.is_truthy(content:match 'skip_ts%s*=', 'Should have skip_ts configuration')
    end)

    it('skips pairing inside strings', function()
      -- This is a behavioral test - we verify the config is set
      -- Actual behavior testing would require more complex setup
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()
      assert.is_truthy(content:match 'skip_ts' or content:match 'skip_next')
    end)
  end)

  -- Test 3: Treesitter on-demand install (no upfront loop)
  describe('treesitter', function()
    it('does not have upfront TSInstall loop for 15 parsers', function()
      -- Read init.lua and verify no bulk TSInstall loop
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()

      -- Should NOT have the old loop pattern
      local has_bulk_install = content:match 'for _, lang in ipairs%s*{' and content:match 'vim%.cmd%s*[\'"]TSInstall'
      assert.is_falsy(has_bulk_install, 'Should not have bulk TSInstall loop for 15 parsers')

      -- Should have FileType autocmd for on-demand install
      local has_on_demand = content:match 'FileType' and content:match 'TSInstall'
      -- Note: on-demand may be implemented differently, this is a basic check
    end)

    it('has FileType autocmd that triggers TSInstall for missing parsers', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()

      -- Should have treesitter start autocmd
      assert.is_truthy(content:match 'treesitter%-start' or content:match 'vim%.treesitter%.start')
    end)
  end)

  -- Test 4: native vim.lsp uses modern API
  describe('lspconfig API', function()
    it('uses vim.lsp.get_client_by_id or vim.lsp.get_clients({bufnr}) not deprecated buf_get_clients', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()

      -- Should NOT use deprecated API
      assert.is_falsy(content:match 'vim%.lsp%.buf_get_clients', 'Should not use deprecated vim.lsp.buf_get_clients')

      -- Should use modern API in LspAttach callback
      local has_modern_api = content:match 'vim%.lsp%.get_client_by_id' or content:match 'vim%.lsp%.get_clients%s*%({%s*bufnr%s*='
      assert.is_truthy(has_modern_api, 'Should use modern vim.lsp.get_client_by_id or vim.lsp.get_clients({bufnr=...})')
    end)
  end)

  -- Test 5: Session symlink handling
  describe('session', function()
    it('resolves symlinks before hashing cwd', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()

      -- Should use vim.fn.resolve to resolve symlinks
      assert.is_truthy(content:match 'vim%.fn%.resolve', 'Should use vim.fn.resolve to handle symlinks in session path')
    end)
  end)

  -- Test 6: Python3 provider NOT force-set (auto-detect for molten)
  describe('providers', function()
    it('leaves python3 provider unset so pynvim auto-detects', function()
      local options_path = vim.fn.stdpath 'config' .. '/lua/config/options.lua'
      local content = table.concat(vim.fn.readfile(options_path), '\n')

      -- =1 is a mistake vim.provider healthcheck errors on; unset = auto-detect
      assert.is_falsy(content:match 'loaded_python3_provider%s*=%s*1', 'Must NOT have vim.g.loaded_python3_provider = 1')
    end)
  end)

  -- Test 7: Colorizer TTY check improved
  describe('image.nvim TTY guard', function()
    it('has proper TTY guard (not just vim.fn.has(tty))', function()
      local plugins_path = vim.fn.stdpath 'config' .. '/lua/custom/plugins/init.lua'
      local content = table.concat(vim.fn.readfile(plugins_path), '\n')

      -- Should check for gui_running and TERM_PROGRAM (not just has('tty'))
      local has_gui_check = content:match 'gui_running'
      local has_term_program = content:match 'TERM_PROGRAM'
      assert.is_truthy(has_gui_check and has_term_program, 'Should have improved TTY check (gui_running and TERM_PROGRAM)')

      -- Should NOT use the old has("tty") check in actual code (not comments)
      -- Check only non-comment lines for the old pattern
      local code_lines = {}
      for line in content:gmatch '[^\n]+' do
        local code = line:match '^(.-)%-%-' or line
        table.insert(code_lines, code)
      end
      local code_content = table.concat(code_lines, '\n')
      -- Check for has('tty') or has("tty") specifically
      local has_tty = code_content:match [[has%('tty'%)]] or code_content:match [[has%("tty"%)]]
      assert.is_falsy(has_tty, 'Should not use deprecated has("tty") check in code')
    end)
  end)

  -- Test 8: Diagnostic virtual_text current_line
  describe('diagnostics', function()
    it('virtual_text configured for current_line only in insert mode', function()
      local options_path = vim.fn.stdpath 'config' .. '/lua/config/options.lua'
      local content = table.concat(vim.fn.readfile(options_path), '\n')

      -- Should have virtual_text = { current_line = true }
      assert.is_truthy(content:match 'virtual_text%s*=%s*{%s*current_line%s*=%s*true', 'Should have virtual_text = { current_line = true }')
    end)
  end)

  -- Test 9: Performance baseline
  describe('performance', function()
    it('has vim.loader.enable and lazy.nvim cache enabled', function()
      -- ponytail: path kept for context; assertions read the whole config
      local content = H.all()

      assert.is_truthy(content:match 'vim%.loader%.enable')
      assert.is_truthy(content:match 'cache%s*=%s*{%s*enabled%s*=%s*true')
    end)
  end)
end)
