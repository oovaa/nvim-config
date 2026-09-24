-- Phase 3: QoL Plugins Tests
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_qol.lua")' -c 'qa!'

describe('Phase 3: QoL Plugins', function()
  -- ponytail: specs moved from init.lua to lua/plugins/ — assert location-agnostic
  local H = require('tests.helpers')
  local qol_path = vim.fn.stdpath 'config' .. '/lua/custom/plugins/qol.lua'
  local plugins_path = vim.fn.stdpath 'config' .. '/lua/custom/plugins/init.lua'

  local function read(path) return table.concat(vim.fn.readfile(path), '\n') end

  it('qol.lua exists and is imported', function()
    assert.equals(1, vim.fn.filereadable(qol_path))
    assert.is_truthy(read(plugins_path):match "import%s*=%s*'custom%.plugins%.qol'")
  end)

  it('blame.nvim on <leader>gb', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'blame%.nvim')
    assert.is_truthy(c:match '<leader>gb')
    assert.is_truthy(c:match 'BlameToggle')
  end)

  it('markdown-preview.nvim removed', function()
    local c = read(qol_path)
    assert.is_falsy(c:match 'markdown%-preview%.nvim', 'markdown-preview should be gone')
    assert.is_falsy(c:match '<leader>mP', '<leader>mP should be gone')
  end)

  it('refactoring.nvim depends on async.nvim', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'lewis6991/async%.nvim', 'refactoring needs async.nvim for the async module')
  end)

  it('refactoring.nvim on <leader>rr (n+v mode)', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'refactoring%.nvim')
    assert.is_truthy(c:match '<leader>rr')
    assert.is_truthy(c:match "mode%s*=%s*{%s*'n'%s*,%s*'v'%s*}")
  end)

  it('neotest with python adapter and tr/ts/to keys', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'neotest')
    assert.is_truthy(c:match 'neotest%-python')
    assert.is_truthy(c:match '<leader>tr')
    assert.is_truthy(c:match '<leader>ts')
    assert.is_truthy(c:match '<leader>to')
  end)

  it('rest.nvim on ft=http with buffer-local hr mapping', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'rest%.nvim')
    assert.is_truthy(c:match "ft%s*=%s*'http'")
    -- hr must NOT be a lazy `keys` shim (registers globally); it lives in
    -- the http FileType autocmd in lua/config/autocmds.lua instead
    assert.is_falsy(c:match '<leader>hr', 'hr must not be a lazy keys entry')
    local autocmds = read(vim.fn.stdpath 'config' .. '/lua/config/autocmds.lua')
    assert.is_truthy(autocmds:match "pattern%s*=%s*'http'")
    assert.is_truthy(autocmds:match '<leader>hr')
  end)

  it('aerial.nvim on <leader>o', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'aerial%.nvim')
    assert.is_truthy(c:match '<leader>o')
  end)

  it('dressing.nvim removed (snacks.input + ui-select cover it)', function()
    local c = read(qol_path)
    assert.is_nil(c:match 'dressing%.nvim', 'dressing spec should be deleted')
  end)

  it('nvim-bqf on ft=qf', function()
    local c = read(qol_path)
    assert.is_truthy(c:match 'nvim%-bqf')
    assert.is_truthy(c:match "ft%s*=%s*'qf'")
  end)

  it('grug-far replaces spectre', function()
    local qol = read(qol_path)
    assert.is_truthy(qol:match 'grug%-far%.nvim')
    assert.is_truthy(qol:match '<leader>fr')
    assert.is_truthy(qol:match 'ripgrep')
    local init = H.all()
    assert.is_nil(init:match 'nvim%-spectre', 'spectre spec should be deleted (grug-far owns <leader>fr)')
  end)

  it('which-key documents groups without shadowing actions', function()
    local init = H.all()
    for _, g in ipairs { 'g', 'h', 'r', 's', 't', 'f', 'd', 'm' } do
      assert.is_truthy(init:match('<leader>' .. g), 'Missing which-key group: ' .. g)
    end
    -- empty groups that shadowed real actions must stay gone:
    -- neotest tr/ts/to, refactoring rr, aerial o
    for _, g in ipairs { 'tr', 'ts', 'to', 'rr' } do
      assert.is_falsy(init:match('<leader>' .. g .. "'%s*,%s*group"), 'Group <leader>' .. g .. ' shadows a real action')
    end
  end)
end)
