-- Python LSP ladder (lua/config/python_lsp.lua): ty -> pyrefly ->
-- pyright-langserver, first hit on PATH wins. vim.fn.executable is stubbed per
-- case, so every assertion is about the ladder and never about which of the
-- three this machine actually has installed.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_python_tools.lua")' -c 'qa!'

describe('python lsp ladder', function()
  local ladder = require 'config.python_lsp'
  local real_executable = vim.fn.executable

  --- Run `fn` with PATH holding exactly `present`. Install and restore are both
  --- pcall'd: a failing assertion must never leave executable() stubbed for the
  --- suites that run after this one.
  local function with_path(present, fn)
    local on = {}
    for _, bin in ipairs(present) do
      on[bin] = true
    end
    pcall(function()
      vim.fn.executable = function(name) return on[name] and 1 or 0 end
    end)
    local ok, err = pcall(fn)
    pcall(function() vim.fn.executable = real_executable end)
    if not ok then error(err, 0) end
  end

  it('picks ty when all three are installed', function()
    with_path({ 'ty', 'pyrefly', 'pyright-langserver' }, function()
      local py = ladder.resolve()
      assert.equals('ty', py.name)
      assert.same({ 'ty', 'server' }, py.cmd)
    end)
  end)

  it('falls back to pyrefly, carrying its typeCheckingMode setting', function()
    with_path({ 'pyrefly', 'pyright-langserver' }, function()
      local py = ladder.resolve()
      assert.equals('pyrefly', py.name)
      assert.same({ 'pyrefly', 'lsp' }, py.cmd)
      assert.equals('default', py.settings.python.pyrefly.typeCheckingMode)
    end)
  end)

  it('falls back to pyright-langserver, registered under the name pyright', function()
    with_path({ 'pyright-langserver' }, function()
      local py = ladder.resolve()
      assert.equals('pyright', py.name)
      assert.same({ 'pyright-langserver', '--stdio' }, py.cmd)
    end)
  end)

  it('resolves nothing when none of the three is installed', function()
    with_path({}, function()
      assert.is_nil(ladder.resolve())
      assert.same({}, ladder.installed())
    end)
  end)

  it('installed() reports the same PATH resolve() picked from', function()
    -- one predicate, not two copies of it: every rung, ladder order
    local cases = {
      { {}, nil },
      { { 'pyright-langserver' }, 'pyright' },
      { { 'pyrefly' }, 'pyrefly' },
      { { 'ty' }, 'ty' },
      { { 'ty', 'pyrefly' }, 'ty' },
      { { 'pyrefly', 'pyright-langserver' }, 'pyrefly' },
      { { 'ty', 'pyrefly', 'pyright-langserver' }, 'ty' },
    }
    for _, c in ipairs(cases) do
      local present, want = c[1], c[2]
      local label = '{' .. table.concat(present, ' ') .. '}'
      with_path(present, function()
        local py = ladder.resolve()
        assert.equals(want, py and py.name, 'resolve for ' .. label)
        assert.same(present, ladder.installed(), 'installed for ' .. label)
      end)
    end
  end)

  it('gives the real executable() back after every stub', function()
    local real = vim.fn.executable 'nvim'
    with_path({}, function() assert.equals(0, vim.fn.executable 'nvim', 'stub must be in force inside with_path') end)
    assert.equals(real, vim.fn.executable 'nvim', 'stub must not outlive with_path')
  end)

  it('registers the resolved server with vim.lsp.config (drives the spec)', function()
    -- Guards the real bug: the vim.lsp.config loop used to run BEFORE the
    -- resolver added the ladder winner, so enable('ty') was a silent no-op.
    -- This loads the plugin spec itself, not the resolver in isolation.
    with_path({ 'ty' }, function()
      for _, spec in ipairs(require 'plugins.lsp') do
        if spec.config then spec.config() end
      end
      local ty = vim.lsp.config['ty']
      assert.is_truthy(ty, 'ty-only host must get a ty config')
      assert.same({ 'ty', 'server' }, ty.cmd)
      assert.is_truthy(vim.lsp.config['pyrefly'], 'pyrefly fallback must stay registered')
    end)
  end)
end)
