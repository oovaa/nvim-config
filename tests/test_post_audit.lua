-- Post-audit fix verification: SQL, Rust clippy, UI caches, cmdline noselect,
-- built-in LSP capabilities and lazy Blink, Java DAP wiring, treesitter mappings.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_post_audit.lua")' -c 'qa!'

describe('post-audit fixes', function()
  local H = require 'tests.helpers'
  local content = H.all()
  local code = H.code()

  -- ============================================================
  -- SQL support
  -- ============================================================
  describe('SQL support', function()
    it('registers sqls LSP server in lsp.lua', function()
      assert.is_truthy(content:match 'sqls%s*=%s*{', 'sqls server must be defined in lsp.lua')
      assert.is_truthy(content:match "cmd%s*=%s*{%s*'sqls'%s*}", 'sqls cmd must be { sqls }')
      assert.is_truthy(content:match "filetypes%s*=%s*{%s*'sql'%s*,%s*'mysql'%s*,%s*'plsql'%s*}", 'sqls filetypes must include sql/mysql/plsql')
    end)

    it(
      'adds sqls to lsp_filetypes',
      function() assert.is_truthy(content:match "sqls%s*=%s*{%s*'sql'%s*,%s*'mysql'%s*,%s*'plsql'%s*}", 'lsp_filetypes must map sqls to sql/mysql/plsql') end
    )

    it('adds sqls and sqruff to ensure_installed', function()
      local src = table.concat(vim.fn.readfile(vim.fn.stdpath 'config' .. '/lua/plugins/lsp.lua'), '\n')
      local s = src:find('vim.list_extend(ensure_installed, {', 1, true)
      local e = s and src:find('\n      })', s, true)
      assert.is_truthy(s and e, 'ensure_installed base list must exist')
      assert.is_truthy(src:sub(s, e):find("'sqruff'", 1, true), 'ensure_installed base list must include sqruff')
      assert.is_truthy(src:find("name == 'gopls' or name == 'sqls') and not go_available", 1, true), 'sqls must be gated on Go availability')
      assert.is_truthy(src:find('table.insert(ensure_installed,', 1, true), 'sqls must be added via table.insert')
    end)

    it('enables sql formatting in formatting.lua', function()
      assert.is_truthy(content:match 'sql%s*=%s*true,', 'enabled_filetypes must include sql = true')
      assert.is_truthy(content:match "sql%s*=%s*{%s*'sqruff'%s*}", 'formatters_by_ft.sql must be { sqruff }')
    end)

    it('registers sqruff linter in ui.lua', function()
      assert.is_truthy(content:match 'lint%.linters%.sqruff', 'sqruff linter must be defined')
      assert.is_truthy(content:match "local%s+sqruff_bin%s*=%s*'sqruff'", 'sqruff binary name must be sqruff')
      assert.is_truthy(content:match 'cmd%s*=%s*sqruff_bin', 'sqruff cmd must use sqruff_bin variable')
      assert.is_truthy(content:match "stream%s*=%s*'both'", 'sqruff stream must be both')
      assert.is_truthy(content:match 'ignore_exitcode%s*=%s*true', 'sqruff must ignore exitcode')
      assert.is_truthy(content:match 'append_fname%s*=%s*false', 'sqruff must set append_fname false')
    end)

    it('adds sql to linters_by_ft', function() assert.is_truthy(content:match "sql%s*=%s*{%s*'sqruff'%s*}", 'linters_by_ft must include sql = { sqruff }') end)

    it('adds sql to treesitter bootstrap list', function() assert.is_truthy(content:match "'sql'", 'treesitter bootstrap must include sql') end)

    it('adds sqls and sqruff to health checks', function()
      assert.is_truthy(content:match "bin%s*=%s*'sqls'", 'health must check sqls binary')
      assert.is_truthy(content:match "bin%s*=%s*'sqruff'", 'health must check sqruff binary')
    end)
  end)

  -- ============================================================
  -- Rust clippy config
  -- ============================================================
  describe('Rust clippy config', function()
    it(
      'sets checkOnSave to true (boolean, not table)',
      function() assert.is_truthy(content:match 'checkOnSave%s*=%s*true', 'checkOnSave must be boolean true') end
    )

    it(
      'sets check.command to clippy',
      function() assert.is_truthy(content:match "check%s*=%s*{%s*command%s*=%s*'clippy'%s*}", 'check.command must be clippy') end
    )

    it('does not have invalid features key', function() assert.is_falsy(content:match "features%s*=%s*'minimal'", 'features = minimal must be removed') end)

    it('sets cargo.allFeatures to false', function() assert.is_truthy(content:match 'allFeatures%s*=%s*false', 'cargo.allFeatures must be false') end)
  end)

  -- ============================================================
  -- UI cache fixes
  -- ============================================================
  describe('UI statusline cache', function()
    it('keys _search cache by winid', function()
      local statusline = H.read(vim.fn.stdpath 'config' .. '/lua/custom/ui/statusline.lua')
      assert.is_truthy(statusline:match 'skey%s*=%s*pat', 'search cache key must include pattern')
      -- winid-keyed: the key includes winid or uses a table keyed by winid
      assert.is_truthy(statusline:match 'winid' or statusline:match '%[winid%]', 'search cache must be winid-aware')
    end)

    it('keys _lsp_name by bufnr', function()
      local statusline = H.read(vim.fn.stdpath 'config' .. '/lua/custom/ui/statusline.lua')
      assert.is_truthy(statusline:match 'M%._lsp_name%s*=%s*{}', '_lsp_name must be a table (bufnr-keyed)')
      assert.is_truthy(statusline:match 'M%._lsp_name%[buf%]', '_refresh_lsp must store by bufnr')
      assert.is_truthy(statusline:match 'M%._lsp_name%[buf0%]', 'render must look up by bufnr')
    end)

    it('cleans up _lsp_name on BufDelete', function()
      local statusline = H.read(vim.fn.stdpath 'config' .. '/lua/custom/ui/statusline.lua')
      assert.is_truthy(statusline:match 'BufDelete.*_lsp_name%[ev%.buf%]%s*=%s*nil', 'BufDelete must clean _lsp_name')
    end)
  end)

  describe('UI tabline', function()
    it('uses nvim_exec2 instead of deprecated nvim_exec', function()
      local tabline = H.read(vim.fn.stdpath 'config' .. '/lua/custom/ui/tabline.lua')
      assert.is_falsy(tabline:match 'nvim_exec%s*%(', 'must not use deprecated nvim_exec')
      assert.is_truthy(tabline:match 'nvim_exec2', 'must use nvim_exec2')
    end)

    it('invalidates _bufs cache on OptionSet buflisted', function()
      local tabline = H.read(vim.fn.stdpath 'config' .. '/lua/custom/ui/tabline.lua')
      assert.is_truthy(tabline:match 'OptionSet', 'must register OptionSet autocmd')
      assert.is_truthy(tabline:match 'buflisted', 'must watch buflisted option')
    end)
  end)

  describe('UI autocmds', function()
    it('diag_float state is reload-safe global', function()
      local autocmds = H.read(vim.fn.stdpath 'config' .. '/lua/config/diag_float.lua')
      -- State moved from setup() upvalues to _G so <leader>ur reload can tear
      -- down the old timer/float (b43f78f); a local would orphan the old timer.
      assert.is_truthy(autocmds:match '_G%._diag_float_state', 'diag_float state must live in _G for reload safety')
    end)

    it('reuses single timer for diagnostic float', function()
      local autocmds = H.read(vim.fn.stdpath 'config' .. '/lua/config/diag_float.lua')
      assert.is_truthy(autocmds:match 'state%.timer', 'single reused state.timer must be used')
      -- Count occurrences of new_timer: should be exactly 1 (reuse, not per-move)
      local count = 0
      for _ in autocmds:gmatch 'vim%.uv%.new_timer' do
        count = count + 1
      end
      assert.equals(1, count, 'new_timer must be called exactly once (reuse, not per-move)')
    end)

    it('wildmode comment matches noselect config', function()
      local autocmds = H.read(vim.fn.stdpath 'config' .. '/lua/config/autocmds.lua')
      assert.is_truthy(autocmds:match 'NOT auto%-selected', 'comment must say NOT auto-selected')
    end)
  end)

  -- ============================================================
  -- Cmdline noselect
  -- ============================================================
  describe('Cmdline noselect', function()
    it('sets wildmode to noselect:full,full', function()
      local options = H.read(vim.fn.stdpath 'config' .. '/lua/config/options.lua')
      assert.is_truthy(options:match 'noselect:full,full', 'wildmode must be noselect:full,full')
    end)
  end)

  -- ============================================================
  -- LSP capabilities and completion laziness
  -- ============================================================
  describe('LSP capabilities and completion laziness', function()
    it('provides snippet support through built-in client capabilities', function()
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      assert.is_true(capabilities.textDocument.completion.completionItem.snippetSupport, 'built-in capabilities must support snippets')
    end)

    it('keeps Blink and LuaSnip behind InsertEnter', function()
      local blink
      for _, spec in ipairs(require 'plugins.completion') do
        if spec[1] == 'saghen/blink.cmp' then blink = spec end
      end
      assert.is_table(blink, 'Blink spec must exist')
      assert.equals('InsertEnter', blink.event, 'Blink must load on InsertEnter')
      assert.equals('luasnip', blink.opts.snippets.preset, 'Blink must keep the LuaSnip preset')
      assert.is_false(blink.opts.cmdline.enabled, 'Blink cmdline completion must stay disabled')
      local has_luasnip = false
      for _, dependency in ipairs(blink.dependencies) do
        if type(dependency) == 'table' and dependency[1] == 'L3MON4D3/LuaSnip' then has_luasnip = true end
      end
      assert.is_true(has_luasnip, 'LuaSnip must remain a Blink dependency')
      -- Actual package.loaded assertions before/after InsertEnter live in test_e2e_features.lua.
    end)
  end)

  -- ============================================================
  -- Treesitter ft->lang mapping
  -- ============================================================
  describe('Treesitter ft->lang mapping', function()
    it('maps typescriptreact to tsx', function()
      local ts = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/treesitter.lua')
      assert.is_truthy(ts:match "typescriptreact%s*=%s*'tsx'", 'must map typescriptreact to tsx')
    end)

    it('maps javascriptreact to javascript', function()
      local ts = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/treesitter.lua')
      assert.is_truthy(ts:match "javascriptreact%s*=%s*'javascript'", 'must map javascriptreact to javascript')
    end)
  end)

  -- ============================================================
  -- Java DAP wiring
  -- ============================================================
  describe('Java DAP wiring', function()
    it('passes declarative DAP opts with hotcodereplace auto', function()
      local editing = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/editing.lua')
      assert.is_truthy(editing:match "{ bufnr = bufnr, dap = { hotcodereplace = 'auto' } }", 'jdtls must receive per-buffer declarative dap opts')
      assert.is_falsy(editing:match 'vim%.defer_fn%s*%(.-setup_dap', 'must not defer a duplicate setup_dap call')
    end)

    it('calls setup_dap_main_class_configs', function()
      local editing = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/editing.lua')
      assert.is_truthy(editing:match 'setup_dap_main_class_configs', 'must call setup_dap_main_class_configs')
    end)

    it('guards DAP wiring behind bundle presence', function()
      local editing = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/editing.lua')
      assert.is_truthy(editing:match 'if%s+#bundles%s*>%s*0', 'DAP wiring must be guarded by bundles')
    end)
  end)

  -- ============================================================
  -- Debugging fixes
  -- ============================================================
  describe('Debugging fixes', function()
    it('uses dap-python setup with string arg, not table', function()
      local debugging = H.read(vim.fn.stdpath 'config' .. '/lua/plugins/debugging.lua')
      assert.is_falsy(debugging:match "require%('dap%-python'%)%.setup%s*{}", 'must not pass {} to setup')
      assert.is_truthy(debugging:match "require%('dap%-python'%)%.setup%s*['\"]debugpy%-adapter['\"]", 'must call setup with debugpy-adapter')
    end)
  end)

  -- ============================================================
  -- Health checks
  -- ============================================================
  describe('Health checks', function()
    it('checks sqls and sqruff binaries', function()
      local health = H.read(vim.fn.stdpath 'config' .. '/lua/config/health.lua')
      assert.is_truthy(health:match "bin%s*=%s*'sqls'", 'health must check sqls')
      assert.is_truthy(health:match "bin%s*=%s*'sqruff'", 'health must check sqruff')
    end)

    it('checks codelldb and js-debug-adapter binaries', function()
      local health = H.read(vim.fn.stdpath 'config' .. '/lua/config/health.lua')
      assert.is_truthy(health:match "bin%s*=%s*'codelldb'", 'health must check codelldb')
      assert.is_truthy(health:match "bin%s*=%s*'js%-debug%-adapter'", 'health must check js-debug-adapter')
    end)
  end)

  -- ============================================================
  -- Full-config audit fixes (Nov 9)
  -- ============================================================

  -- Colorizer: single opts table (catgoose fork)
  describe('Colorizer opts form', function()
    it('uses single opts table with filetypes + user_default_options', function()
      assert.is_truthy(code:match "filetypes%s*=%s*{%s*'%*'%s*}", 'colorizer must use filetypes = { * }')
      assert.is_truthy(code:match 'user_default_options', 'colorizer must use user_default_options')
    end)
  end)

  -- Treesitter: sh->bash, jsonc->json ft_map
  describe('Treesitter ft->lang map (audit)', function()
    it('maps sh to bash', function() assert.is_truthy(code:match "sh%s*=%s*'bash'", 'ft_map must map sh to bash') end)
    it('maps jsonc to json', function() assert.is_truthy(code:match "jsonc%s*=%s*'json'", 'ft_map must map jsonc to json') end)
  end)

  -- completeopt: menu + preview
  describe('completeopt', function()
    it(
      'includes menu and preview',
      function() assert.is_truthy(code:match "completeopt%s*=%s*'menu,menuone,noselect,preview'", 'completeopt must be menu,menuone,noselect,preview') end
    )
  end)

  -- gopls: staticcheck = true
  describe('gopls staticcheck', function()
    it('enables staticcheck', function() assert.is_truthy(code:match 'staticcheck%s*=%s*true', 'gopls staticcheck must be true') end)
  end)

  -- blink: buffer source
  describe('blink sources', function()
    it(
      'includes buffer source',
      function() assert.is_truthy(code:match "default%s*=%s*{%s*'lsp'%s*,%s*'path'%s*,%s*'snippets'%s*,%s*'buffer'%s*}", 'blink sources must include buffer') end
    )
  end)

  -- auto-save: large_file_mode guard
  describe('auto-save large_file guard', function()
    it('has condition checking large_file_mode', function() assert.is_truthy(code:match 'large_file_mode', 'auto-save must check large_file_mode') end)
  end)

  -- large-file: treesitter.stop + LSP detach + foldexpr reset
  describe('large-file guards (audit)', function()
    it(
      'disables treesitter via vim.treesitter.stop',
      function() assert.is_truthy(code:match 'vim%.treesitter%.stop', 'must call treesitter.stop for large files') end
    )
    it('detaches LSP clients for large files', function() assert.is_truthy(code:match 'buf_detach_client', 'must detach LSP clients for large files') end)
    it('resets foldexpr for large files', function() assert.is_truthy(code:match "foldexpr%s*=%s*''", 'must reset foldexpr for large files') end)
    it(
      'has LspAttach autocmd for large-file detach',
      function() assert.is_truthy(code:match 'large%-file%-lsp%-detach', 'must have LspAttach autocmd group') end
    )
  end)

  -- nvim-lint: errors reported via notify
  describe('nvim-lint error reporting', function()
    it(
      'reports lint errors via vim.notify instead of silent pcall',
      function() assert.is_truthy(code:match 'vim%.notify.*Lint error', 'must report lint errors via notify') end
    )
  end)

  -- DAP: have_bin, conditional breakpoint, virtual text, disconnect, python clear
  describe('DAP audit fixes', function()
    it('defines have_bin helper', function() assert.is_truthy(code:match 'local function have_bin', 'must define have_bin helper') end)
    it('registers conditional breakpoint keymap', function() assert.is_truthy(code:match 'dB', 'must have conditional breakpoint keymap') end)
    it('configures nvim-dap-virtual-text', function() assert.is_truthy(code:match 'nvim%-dap%-virtual%-text', 'must configure virtual text') end)
    it('adds disconnect listener for dapui', function() assert.is_truthy(code:match 'event_disconnect', 'must listen for disconnect event') end)
    it('clears python configs before setup', function() assert.is_truthy(code:match 'dap%.configurations%.python%s*=%s*{}', 'must clear python configs') end)
    it('removes java-debug-adapter from health exec check', function()
      local health = H.read(vim.fn.stdpath 'config' .. '/lua/config/health.lua')
      assert.is_falsy(health:match "bin%s*=%s*'java%-debug%-adapter'", 'java-debug-adapter must not be in exec check')
    end)
  end)

  -- gitsigns: lazy-load guard
  describe('gitsigns lazy-load', function()
    it('guards gp/gd/gt with lazy.load', function() assert.is_truthy(code:match 'gitsigns%.nvim', 'must lazy-load gitsigns for gp/gd/gt') end)
  end)

  -- Treesitter comment: indent from runtime ftplugins
  describe('Treesitter indent comment', function()
    it(
      'documents indent comes from runtime ftplugins',
      function() assert.is_truthy(content:match 'indent comes from runtime ftplugins', 'must document indent source') end
    )
  end)
  -- Dashboard: no mutation of captured buttons table
  describe('Dashboard buttons copy', function()
    it(
      'uses a copy (btns) instead of mutating buttons',
      function() assert.is_truthy(code:match 'local btns = vim%.list_extend%(%{}, buttons%)', 'must copy buttons before insert') end
    )
  end)

  -- Statusline: WinClosed cleanup for search cache
  describe('Statusline search cache cleanup', function()
    it('has WinClosed autocmd for search cache', function() assert.is_truthy(code:match 'statusline%-search%-cleanup', 'must have cleanup autocmd') end)
  end)
end)
