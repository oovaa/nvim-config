-- QoL plugin wiring: assert the resolved lazy spec and the live keymap, not the
-- text of lua/custom/plugins/qol.lua. A spec can say lazy=true and still never
-- fire; a keymap can be registered and still point at a deleted plugin.
--   nvim --headless -c 'lua require("plenary.busted").run("tests/test_qol.lua")' -c 'qa!'

describe('qol plugins', function()
  local P = require('lazy.core.config').plugins

  local function mapped(lhs, mode) return vim.fn.maparg(lhs, mode or 'n', false, true) end

  local function assert_spec(name)
    assert.is_not_nil(P[name], name .. ' must be registered with lazy.nvim')
    return P[name]
  end

  it('registers every qol plugin as a lazy spec', function()
    for _, name in ipairs {
      'blame.nvim',
      'refactoring.nvim',
      'neotest',
      'neotest-python',
      'aerial.nvim',
      'grug-far.nvim',
      'async.nvim',
    } do
      assert.is_true(assert_spec(name).lazy ~= false, name .. ' must not be eagerly loaded')
    end
  end)

  it('drops the plugins that were replaced', function()
    -- markdown-preview -> image.nvim, dressing -> snacks.input, spectre -> grug-far
    for _, name in ipairs { 'markdown-preview.nvim', 'dressing.nvim', 'spectre' } do
      assert.is_nil(P[name], name .. ' must no longer be registered')
    end
  end)

  it('binds each qol plugin to its leader key', function()
    local expected = {
      ['<leader>gb'] = 'Blame',
      ['<leader>rr'] = 'Refactor',
      ['<leader>tr'] = 'Test Run',
      ['<leader>ts'] = 'Test Summary',
      ['<leader>to'] = 'Test Output',
      ['<leader>o'] = 'Outline',
      ['<leader>fr'] = 'Find & Replace',
    }
    for lhs, fragment in pairs(expected) do
      local m = mapped(lhs)
      assert.is_not_nil(m and next(m) ~= nil, lhs .. ' must be mapped')
      assert.is_truthy((m.desc or ''):find(fragment, 1, true), lhs .. ' desc should mention ' .. fragment)
      assert.is_function(m.callback, lhs .. ' must resolve to a real handler')
    end
  end)

  it('<leader>rr also works from visual mode', function()
    local m = mapped('<leader>rr', 'v')
    assert.is_not_nil(m and next(m) ~= nil, '<leader>rr must be mapped in visual mode')
    assert.is_function(m.callback)
  end)

  it('scopes rest.nvim to http buffers only', function()
    local rest = assert_spec 'rest.nvim'
    assert.equals('http', rest.ft, 'rest.nvim must be gated on ft=http')
    -- <leader>hr is buffer-local (autocmds.lua), so it must be absent in a
    -- normal buffer and present once an http buffer opens. maparg returns a
    -- string with two args, so compare against '' rather than nil.
    assert.equals('', vim.fn.maparg('<leader>hr', 'n'), '<leader>hr must not exist outside http buffers')
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.http')
    vim.bo[buf].filetype = 'http'
    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
    local m = vim.fn.maparg('<leader>hr', 'n', false, true)
    assert.is_not_nil(m and next(m) ~= nil, '<leader>hr must exist in an http buffer')
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end)

  it('scopes nvim-bqf to quickfix buffers', function() assert.equals('qf', assert_spec('nvim-bqf').ft, 'nvim-bqf must be gated on ft=qf') end)

  it('scopes the markdown-only plugins', function()
    local img = assert_spec 'img-clip.nvim'
    assert.equals('markdown', img.ft, 'img-clip must be gated on ft=markdown')
  end)

  it('does not shadow real actions with empty which-key groups', function()
    -- which-key registers its groups at VeryLazy; load it so the resolved spec
    -- exists. Groups are a positional array with the key at [1], not a map.
    require('lazy').load { plugins = { 'which-key.nvim' } }
    local registered = {}
    for _, entry in ipairs(require('which-key.config').spec or {}) do
      registered[entry[1]] = entry.group
    end
    -- real actions must stay reachable, i.e. never become a group
    for _, g in ipairs { 'tr', 'ts', 'to', 'rr', 'gb', 'o' } do
      assert.is_nil(registered['<leader>' .. g], '<leader>' .. g .. ' must stay a real action, not a group')
    end
    -- documented groups must be registered
    for _, g in ipairs { 's', 't', 'm', 'd', 'f', 'r', 'g', 'u', 'y' } do
      assert.is_not_nil(registered['<leader>' .. g], 'missing which-key group: <leader>' .. g)
    end
    assert.is_not_nil(registered.gr, 'missing which-key group: gr')
  end)
end)
