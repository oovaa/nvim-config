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
  assert(res.code == 0, string.format('child command failed (exit %s):\n%s', tostring(res.code), res.report))
  for _, marker in ipairs { 'Invalid buffer id', 'stack traceback:', 'Error in command line:', 'vim.schedule callback:' } do
    assert(not res.report:find(marker, 1, true), string.format('child output contained %q:\n%s', marker, res.report))
  end
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
      env = vim.tbl_extend('force', vim.fn.environ(), { PATH = path }),
    })
    assert.is_truthy(stdout:match 'picked=ty', 'the ladder must pick the fake ty: ' .. stdout)
    assert.is_truthy(stdout:match 'cfg=table|ty,server', 'ty must get a config: ' .. stdout)
    assert.is_truthy(stdout:match 'enable_ok=true', 'vim.lsp.enable("ty") must not error: ' .. stdout)
    assert.is_truthy(stdout:match 'enabled=true', 'ty must be enabled after enable(): ' .. stdout)
  end)

  it('keeps Blink and LuaSnip unloaded until InsertEnter', function()
    local enter = [[
      vim.api.nvim_create_autocmd('VimEnter', {
        once = true,
        callback = function()
          local at_enter = tostring(package.loaded['blink.cmp'])
          vim.lsp.start = function() end
          vim.cmd('enew')
          vim.api.nvim_buf_set_name(0, '/tmp/nvim-e2e-lazy-completion.ts')
          vim.bo.filetype = 'typescript'
          vim.wait(300, function() return false end)
          io.stdout:write('enter_blink=' .. at_enter .. ' ft_blink=' .. tostring(package.loaded['blink.cmp']) .. ' luasnip=' .. tostring(package.loaded['luasnip']))
          vim.cmd('qa!')
        end,
      })
    ]]
    local res = run { 'nvim', '--headless', '--cmd', 'lua ' .. (enter:gsub('%s+', ' ')) }
    assert.is_truthy(res.stdout:match 'enter_blink=nil', 'Blink must stay unloaded at VimEnter: ' .. res.report)
    assert.is_truthy(res.stdout:match 'ft_blink=nil', 'Opening TypeScript must not force Blink before InsertEnter: ' .. res.report)
    assert.is_truthy(res.stdout:match 'luasnip=nil', 'LuaSnip must stay unloaded before InsertEnter: ' .. res.report)
  end)

  it('retains built-in snippet support without eager completion', function()
    local probe = [[
      local caps = vim.lsp.protocol.make_client_capabilities()
      io.stdout:write('snippet=' .. tostring(caps.textDocument.completion.completionItem.snippetSupport))
    ]]
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'snippet=true', 'built-in client capabilities must support snippets: ' .. stdout)
  end)

  it('does not start LSP clients for fresh 2 MiB TypeScript, Java, or Lua buffers', function()
    local dir = tmpdir 'large-lsp'
    local files = {}
    for _, fixture in ipairs {
      { 'typescript', 'ts', '//' },
      { 'java', 'java', '//' },
      { 'lua', 'lua', '--' },
    } do
      local file = string.format('%s/large.%s', dir, fixture[2])
      local line = fixture[3] .. string.rep('x', 100)
      local lines = {}
      for i = 1, math.ceil(2 * 1024 * 1024 / #line) do
        lines[i] = line
      end
      write(file, lines)
      files[#files + 1] = file
    end
    local small_ts, small_lua = dir .. '/small.ts', dir .. '/small.lua'
    write(small_ts, { 'const x = 1' })
    write(small_lua, { 'local x = 1' })
    local probe_args = { files[1], files[2], files[3], small_ts, files[1], small_lua, files[3] }

    local probe = string.format(
      [[
        _G.starts, _G.large_starts = 0, 0
        vim.lsp.start = function(_, opts)
          _G.starts = _G.starts + 1
          if opts and opts.bufnr and vim.b[opts.bufnr].large_file_mode then _G.large_starts = _G.large_starts + 1 end
        end
        local files = {%q, %q, %q}
        local large, attached = {}, {}
        for _, file in ipairs(files) do
          vim.cmd('edit ' .. vim.fn.fnameescape(file))
          local buf = vim.api.nvim_get_current_buf()
          vim.wait(500, function() return false end)
          large[#large + 1] = tostring(vim.b[buf].large_file_mode)
          attached[#attached + 1] = #vim.lsp.get_clients { bufnr = buf }
        end
        local fresh_starts = _G.starts
        for _, pair in ipairs { {%q, %q}, {%q, %q} } do
          vim.cmd('edit ' .. vim.fn.fnameescape(pair[1]))
          vim.wait(300, function() return false end)
          vim.cmd('edit ' .. vim.fn.fnameescape(pair[2]))
          vim.wait(300, function() return false end)
        end
        io.stdout:write('large=' .. table.concat(large, ',') .. ' fresh_starts=' .. fresh_starts .. ' small_starts=' .. _G.starts .. ' large_starts=' .. _G.large_starts .. ' attached=' .. table.concat(attached, ','))
      ]],
      unpack(probe_args)
    )
    local stdout = boot((probe:gsub('%s+', ' ')))
    vim.fn.delete(dir, 'rf')
    assert.is_truthy(stdout:match 'large=true,true,true', 'each fixture must enter large-file mode: ' .. stdout)
    assert.is_truthy(stdout:match 'fresh_starts=0', 'large buffers must not request an LSP start: ' .. stdout)
    local small_starts = tonumber(stdout:match 'small_starts=(%d+)')
    assert.is_true(small_starts and small_starts > 0, 'small buffers must still request LSP startup: ' .. stdout)
    assert.is_truthy(stdout:match 'large_starts=0', 'a previously enabled server must not start on a later large buffer: ' .. stdout)
    assert.is_truthy(stdout:match 'attached=0,0,0', 'large buffers must have no attached clients: ' .. stdout)
  end)

  it('[optional] disables CodeLens before wiping an edited Markdown buffer', function()
    if vim.fn.executable 'marksman' ~= 1 then pending 'marksman not installed (headless Mason skips installs; CI does not install it)' end
    local dir = tmpdir 'codelens-wipe'
    local file = dir .. '/lens.md'
    write(file, { '# Title' })
    local probe = string.format(
      [[
        vim.cmd('edit %s')
        local buf = vim.api.nvim_get_current_buf()
        assert(vim.wait(8000, function()
          return #vim.lsp.get_clients { bufnr = buf, name = 'marksman' } > 0
        end, 50), 'marksman must attach')
        local client = vim.lsp.get_clients { bufnr = buf, name = 'marksman' }[1]
        assert(client:supports_method('textDocument/codeLens', buf), 'marksman must support CodeLens')
        local enabled = vim.lsp.codelens.is_enabled { bufnr = buf, client_id = client.id }
        local cleaned = false
        local enable = vim.lsp.codelens.enable
        vim.lsp.codelens.enable = function(value, filter)
          if value == false and filter and filter.bufnr == buf and vim.api.nvim_buf_is_valid(buf) then cleaned = true end
          return enable(value, filter)
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '# Changed' })
        vim.wait(250, function() return false end)
        vim.api.nvim_buf_delete(buf, { force = true })
        vim.wait(250, function() return false end)
        io.stdout:write('enabled=' .. tostring(enabled) .. ' cleaned=' .. tostring(cleaned))
        vim.fn.delete(%q, 'rf')
      ]],
      vim.fn.fnameescape(file),
      dir
    )
    local stdout = boot((probe:gsub('%s+', ' ')))
    assert.is_truthy(stdout:match 'enabled=true', 'CodeLens must be enabled before the wipe: ' .. stdout)
    assert.is_truthy(stdout:match 'cleaned=true', 'CodeLens must be disabled while the buffer is still valid: ' .. stdout)
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

    local env = vim.tbl_extend('force', vim.fn.environ(), { XDG_DATA_HOME = data, XDG_STATE_HOME = data .. '/state' })
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

  it('rejects failed children and hidden runtime output', function()
    local ok = pcall(run, { 'nvim', '--headless', '-c', 'cquit 7', '-c', 'qa!' })
    assert.is_false(ok, 'a non-zero child exit must fail the E2E helper')

    for _, marker in ipairs { 'Invalid buffer id', 'stack traceback:', 'Error in command line:', 'vim.schedule callback:' } do
      local lua = string.format('io.stderr:write(%q)', marker)
      ok = pcall(run, { 'nvim', '--headless', '-c', 'lua ' .. lua, '-c', 'qa!' })
      assert.is_false(ok, marker .. ' in child output must fail the E2E helper')
    end
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
