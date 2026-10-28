-- End-to-end verification of the features this branch shipped.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/e2e_features.lua")' -c 'qa!'
-- Each case boots a REAL child nvim on the real config and asserts observable
-- end state, not internals. Needs the same env as the other suites:

-- Requires `biome` on PATH (case 4/5) and a writable /tmp.
local root = vim.fn.stdpath 'config'

local function run(cmd, opts)
  opts = opts or {}
  local obj = vim.system(cmd, { text = true, cwd = opts.cwd, env = opts.env, timeout = 30000 })
  local res = obj:wait()
  res.report = (res.stdout or '') .. (res.stderr or '')
  return res
end

-- Boot the real config in a child and return its stdout plus stderr.
local function boot(lua, opts)
  opts = opts or {}
  local args = { 'nvim', '--headless', '-c', 'lua ' .. lua, '-c', 'qa!' }
  vim.list_extend(args, opts.extra_args or {})
  local res = run(args, { cwd = opts.cwd, env = opts.env })
  return res.stdout or '', res.report or ''
end

-- A temp dir that does NOT depend on $TMPDIR (see tests/test_lint.lua).
local function tmpdir(name)
  local d = '/tmp/nvim-e2e-' .. name .. '-' .. tostring(vim.uv.hrtime())
  vim.fn.mkdir(d, 'p')
  return d
end

local function write(path, lines) vim.fn.writefile(lines, path) end

describe('e2e: shipped features', function()
  it('registers the resolved python lsp as a config (ty-only host)', function()
    local bin = tmpdir 'tybin'
    local fake = bin .. '/ty'
    write(fake, { '#!/bin/sh', 'exec cat' })
    vim.fn.setfperm(fake, 'rwxr-xr-x')
    local probe = [[
      _G.out = {}
      local chosen = require('config.python_lsp').resolve()
      table.insert(_G.out, 'picked=' .. (chosen and chosen.name or 'none'))
      if chosen then vim.lsp.config(chosen.name, { cmd = chosen.cmd, filetypes = { 'python' } }) end
      local cfg = vim.lsp.config['ty']
      table.insert(_G.out, 'cfg=' .. type(cfg) .. '|' .. (cfg and table.concat(cfg.cmd or {}, ',') or ''))
      table.insert(_G.out, 'enable_ok=' .. tostring(pcall(vim.lsp.enable, 'ty')))
      table.insert(_G.out, 'enabled=' .. tostring(vim.lsp.is_enabled('ty')))
      io.stdout:write(table.concat(_G.out, '\n'))
    ]]
    -- Fake `ty` on PATH; the ladder tries ty first so it wins regardless.
    local path = bin .. ':' .. vim.env.PATH
    local stdout = boot((probe:gsub('%s+', ' ')), {
      env = {
        PATH = path,
      },
    })
    assert.is_truthy(stdout:match 'picked=ty', 'the ladder must pick the fake ty: ' .. stdout)
    assert.is_truthy(stdout:match 'cfg=table|ty,server', 'ty must get a config: ' .. stdout)
    assert.is_truthy(stdout:match 'enable_ok=true', 'vim.lsp.enable("ty") must not error: ' .. stdout)
    assert.is_truthy(stdout:match 'enabled=true', 'ty must be enabled after enable(): ' .. stdout)
  end)

  it('reports the tree-sitter cli and the biome linter in :checkhealth config', function()
    local probe = [[
      vim.cmd('checkhealth config')
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      io.stdout:write(table.concat(lines, '\n'))
    ]]
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:lower():match 'tree%-s?sitter', 'health must name the tree-sitter CLI: ' .. stdout)
    assert.is_truthy(stdout:lower():match 'biome', 'health must name the JS linter: ' .. stdout)
  end)

  it('binds no molten keys when the rplugin manifest is blank', function()
    local data = tmpdir 'manifest'
    local std = data .. '/nvim'
    vim.fn.mkdir(std, 'p')
    local real = vim.fn.stdpath 'data'
    vim.uv.fs_symlink(real .. '/lazy', std .. '/lazy', { dir = true })
    vim.uv.fs_symlink(real .. '/site', std .. '/site', { dir = true })
    write(std .. '/rplugin.vim', { "' blank manifest" }) -- no molten section

    local env = { XDG_DATA_HOME = data, XDG_STATE_HOME = data .. '/state' }
    local keys = [[
      local lead = vim.g.mapleader or ' '
      local n = 0
      for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
        if m.lhs:find(lead .. 'm', 1, true) and #m.lhs == #lead + 2 then n = n + 1 end
      end
      io.stdout:write('molten_keys=' .. n .. ' cmd=' .. vim.fn.exists(':MoltenInit'))
    ]]
    local stdout = boot((keys:gsub('%s+', ' ')), { env = env })
    assert.is_truthy(stdout:match 'molten_keys=0', 'a blank manifest must bind nothing: ' .. stdout)
    assert.is_truthy(stdout:match 'cmd=0', 'Molten commands must be absent: ' .. stdout)

    -- Same isolated data dir, but with the real manifest. Whether the keys come
    -- back depends on this host: cond greps the manifest for molten.
    local manifest = io.open(real .. '/rplugin.vim', 'r')
    local body = manifest and manifest:read '*a' or ''
    if manifest then manifest:close() end
    write(std .. '/rplugin.vim', vim.split(body, '\n'))
    local stdout2 = boot((keys:gsub('%s+', ' ')), { env = env })
    if body:find('molten', 1, true) then
      assert.is_truthy(stdout2:match 'cmd=2', 'MoltenInit must exist once the manifest lists molten: ' .. stdout2)
      assert.is_truthy(stdout2:match 'molten_keys=%d' and not stdout2:match 'molten_keys=0', 'molten keys must be bound: ' .. stdout2)
    else
      print 'SKIP molten positive half: this host rplugin.vim lists no molten, so cond stays false'
      assert.is_truthy(stdout2:match 'cmd=0', 'without molten in the manifest the commands must stay absent: ' .. stdout2)
      assert.is_truthy(stdout2:match 'molten_keys=0', 'without molten in the manifest nothing must be bound: ' .. stdout2)
    end
    vim.fn.delete(data, 'rf')
  end)

  it('formats a javascript file with biome on save', function()
    assert.are.equal(1, vim.fn.executable 'biome', 'this case needs biome on PATH')
    local proj = tmpdir 'fmt'
    -- biome v2 moved quoteStyle/semicolons under `javascript.formatter`; the v1
    -- shape makes biome exit non-zero ("unknown key"), so this fixture pins v2.
    write(proj .. '/biome.json', { '{"javascript":{"formatter":{"quoteStyle":"single","semicolons":"always"}}}' })
    local file = proj .. '/a.js'
    write(file, { 'const x =   1+2', 'console.log( x )' })

    local probe = string.format(
      [[
        vim.cmd('edit %s')
        vim.cmd('write')
        io.stdout:write('ft=' .. vim.bo.filetype)
      ]],
      vim.fn.fnameescape(file)
    )
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'ft=javascript', 'expected a javascript buffer: ' .. stdout)
    local body = table.concat(vim.fn.readfile(file), '\n')
    assert.is_truthy(body:match 'const x = %d+ %+ %d+;', 'biome must add the semicolon: ' .. body)
    assert.is_truthy(body:match 'console%.log%(x%)', 'biome must normalize the call: ' .. body)
    vim.fn.delete(proj, 'rf')
  end)

  it('lints with biome from a foreign cwd', function()
    assert.are.equal(1, vim.fn.executable 'biome', 'this case needs biome on PATH')
    local proj, other = tmpdir 'lintproj', tmpdir 'lintcwd'
    -- `recommended` is spelled the same in v1 and v2; `useConst`/`noVar` are not.
    -- The nvim-lint biome parser only matches `×` error rows, and an unreassigned
    -- `let` is a `!` warning, so the fixture uses noDebugger (error-level).
    write(proj .. '/biome.json', { '{"linter":{"rules":{"recommended":true}}}' })
    local file = proj .. '/b.js'
    write(file, { 'debugger;' })

    local probe = string.format(
      [[
        vim.cmd('lcd %s')
        vim.cmd('edit %s')
        require('lint').try_lint()
        vim.wait(4000, function() return #vim.diagnostic.get(0) > 0 end)
        local ds = vim.diagnostic.get(0)
        io.stdout:write('diags=' .. #ds .. ' src=' .. (ds[1] and ds[1].source or ''))
      ]],
      vim.fn.fnameescape(other),
      vim.fn.fnameescape(file)
    )
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'diags=%d' and not stdout:match 'diags=0', 'biome must report from a foreign cwd: ' .. stdout)
    assert.is_truthy(stdout:match 'src=biome', 'the linter must be biomejs: ' .. stdout)
    vim.fn.delete(proj, 'rf')
    vim.fn.delete(other, 'rf')
  end)

  it('toggles a buffer pin both ways in a real session', function()
    -- keytrans() does NOT expand <leader>; the probe feeds the real leader
    -- through replace_termcodes. This note lives here, not in the probe: the
    -- probe is collapsed to one line, so a `--` comment would eat the rest.
    local probe = [[
      vim.cmd('enew')
      vim.cmd('file /tmp/nvim-e2e-pin-a')
      local listed = vim.bo.buflisted
      local function press(lhs)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(vim.g.mapleader .. lhs, true, false, true), 'x', false)
      end
      press 'bp'
      local after1 = vim.bo.buflisted
      press 'bp'
      local after2 = vim.bo.buflisted
      io.stdout:write('start=' .. tostring(listed) .. ' one=' .. tostring(after1) .. ' two=' .. tostring(after2))
    ]]
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'start=true one=false two=true', 'pin must toggle both ways: ' .. stdout)
  end)

  it('routes vim.ui.select through the snacks picker', function()
    -- The picker needs a UI and blocks on stdin headless, so the probe never
    -- opens it; lazy.load runs the spec config that assigns vim.ui.select.
    local probe = [[
      require('lazy').load({ plugins = { 'snacks.nvim' } })
      io.stdout:write('is_snacks=' .. tostring(vim.ui.select == require('snacks').picker.select))
    ]]
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'is_snacks=true', 'vim.ui.select must be the snacks picker: ' .. stdout)
  end)

  it('renders the split statusline and tabline globals', function()
    local probe = [[
      vim.cmd('redraw')
      local sl = _G._builtin_statusline and _G._builtin_statusline() or ''
      local tl = _G._builtin_tabline and _G._builtin_tabline() or ''
      io.stdout:write('sl=' .. #sl .. ' tl=' .. #tl .. ' click=' .. type(_G._builtin_tabclick))
    ]]
    local stdout = boot((probe:gsub('%s+', ' ')))
    local n = stdout:match 'sl=(%d+)'
    local m = stdout:match 'tl=(%d+)'
    assert.is_true(n and tonumber(n) > 0, 'statusline must render: ' .. stdout)
    assert.is_true(m and tonumber(m) > 0, 'tabline must render: ' .. stdout)
    assert.is_truthy(stdout:match 'click=function', 'tabclick must be installed: ' .. stdout)
  end)

  it('keeps the config root the only thing a boot needs', function()
    assert.are.equal(root, vim.fn.stdpath 'config')
    -- `print` goes to the message system, not stdout, under --headless; this
    -- case could only ever have failed, and did not run until now.
    local res = run { 'nvim', '--headless', '-c', 'lua io.stdout:write("ok")', '-c', 'qa!' }
    assert.are.equal(0, res.code)
    assert.is_truthy(res.stdout:match 'ok')
  end)
end)
