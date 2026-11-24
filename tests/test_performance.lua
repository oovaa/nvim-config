-- Performance intent: the config's startup budget and its lazy-loading
-- discipline. Assert the resolved plugin registry and a real LSP attach, not
-- the text of the spec files — a spec can say lazy=true and still be loaded
-- eagerly, and grep cannot see either.
--   nvim --headless -c 'lua require("plenary.busted").run("tests/test_performance.lua")' -c 'qa!'

-- Same child-process contract as tests/test_e2e_features.lua: exit 0 and no
-- runtime traceback markers.
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

describe('performance', function()
  local P = require('lazy.core.config').plugins

  it('registers a bounded number of plugins', function()
    -- A regression guard, not a target: this grew past 80 when telescope and
    -- its extensions were still in the tree.
    local n = vim.tbl_count(P)
    assert.is_true(n > 0, 'lazy registry must be populated')
    -- Bumped for planned additions (inc-rename, neotest-golang, nvim-treesitter-textobjects,
    -- neovim-tips, git-blame.nvim, dropbar.nvim).
    assert.is_true(n <= 75, 'plugin count ' .. n .. ' should stay <= 75')
  end)

  it('loads tokyonight eagerly so the theme never flashes', function()
    local tn = P['tokyonight.nvim']
    assert.is_not_nil(tn, 'tokyonight must be registered')
    assert.is_false(tn.lazy, 'tokyonight must not be lazy (startup colorscheme)')
    assert.equals(1000, tn.priority, 'tokyonight priority must be 1000')
  end)

  it('keeps every secondary theme lazy', function()
    for _, name in ipairs {
      'catppuccin',
      'rose-pine',
      'gruvbox.nvim',
      'kanagawa.nvim',
      'onedark.nvim',
      'nightfox.nvim',
      'everforest',
      'dracula.nvim',
      'github-theme',
      'melange-nvim',
      'poimandres.nvim',
      'cyberdream.nvim',
      'flexoki',
    } do
      local spec = P[name]
      assert.is_not_nil(spec, name .. ' must still be registered')
      assert.is_true(spec.lazy == true, name .. ' must be lazy=true')
    end
  end)

  it('activates a colorscheme and honours the saved theme', function()
    assert.is_truthy(vim.g.colors_name, 'a colorscheme must be active at startup')
    assert.is_not_nil(P['tokyonight.nvim'], 'the saved-theme fallback lives on the tokyonight spec')
  end)

  it('does not depend on nvim-lspconfig', function()
    assert.is_false((pcall(require, 'lspconfig')), 'nvim-lspconfig must not be installed')
    assert.is_false((pcall(require, 'mason-lspconfig')), 'mason-lspconfig must not be installed')
  end)

  it('[optional] attaches the native LSP and defines servers via vim.lsp.config', function()
    if vim.fn.executable 'lua-language-server' == 0 then
      pending 'lua-language-server not installed on this machine'
      return
    end
    local file = vim.fn.tempname() .. '.lua'
    local fh = assert(io.open(file, 'w'))
    fh:write 'local x = 1\nreturn x\n'
    fh:close()
    vim.cmd.edit(vim.fn.fnameescape(file))
    local buf = vim.api.nvim_get_current_buf()

    assert.is_true(vim.wait(20000, function() return #vim.lsp.get_clients { bufnr = buf } > 0 end, 200), 'lua_ls should attach to a .lua buffer')

    local names = {}
    for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
      names[client.name] = true
    end
    assert.is_true(names.lua_ls, 'expected lua_ls, got: ' .. vim.inspect(vim.tbl_keys(names)):gsub('%s+', ' '))

    -- servers are defined natively, not bridged from lspconfig
    local cfg = vim.lsp.config.lua_ls
    assert.is_not_nil(cfg, 'lua_ls must be defined through vim.lsp.config')
    assert.same({ 'lua-language-server' }, cfg.cmd)

    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    vim.fn.delete(file)
  end)

  it('enables only the snacks modules this config uses', function()
    local sc = require('snacks').config
    for _, mod in ipairs { 'input', 'notifier', 'picker', 'explorer', 'scope', 'words', 'indent' } do
      assert.is_true(sc[mod] and sc[mod].enabled, 'snacks.' .. mod .. ' must be enabled')
    end
    -- opt-in and deliberately off: scroll fought vim.o.smoothscroll,
    -- statuscolumn would fight the custom statusline, toggle is unused.
    for _, mod in ipairs { 'scroll', 'statuscolumn', 'toggle' } do
      assert.is_falsy(sc[mod] and sc[mod].enabled, 'snacks.' .. mod .. ' must stay off')
    end
  end)

  it('gives the snacks picker a real glyph for every git state', function()
    -- regression: added/deleted/renamed shipped as empty strings, so files
    -- rendered with no icon at all in the most-used UI surface.
    local git = require('snacks').config.picker.icons.git
    for _, state in ipairs { 'commit', 'staged', 'added', 'deleted', 'ignored', 'modified', 'renamed', 'unmerged', 'untracked' } do
      local glyph = git[state]
      assert.is_string(glyph, state .. ' icon must be a string')
      assert.is_true(#glyph > 0, state .. ' icon must not be empty')
    end
  end)

  it('scopes the filetype-gated plugins instead of loading them on every file', function()
    -- colorizer/image used to load on BufReadPost, which paid their cost on
    -- every open. They must be ft-gated with no event trigger.
    local cz = P['nvim-colorizer.lua']
    assert.is_not_nil(cz, 'nvim-colorizer must be registered')
    assert.is_nil(cz.event, 'colorizer must not load on an every-file event')
    assert.is_not_nil(cz.ft, 'colorizer must be gated on filetype')
    assert.is_true(vim.tbl_contains(cz.ft, 'css'), 'colorizer must cover css')

    local bqf = P['nvim-bqf']
    assert.equals('qf', bqf.ft, 'nvim-bqf must be gated on ft=qf')

    local rest = P['rest.nvim']
    assert.equals('http', rest.ft, 'rest.nvim must be gated on ft=http')
  end)

  it('bootstraps treesitter parsers without paying for them at startup', function()
    -- The scheduled bootstrap only exists to pre-build parsers; it must never
    -- make nvim-treesitter load eagerly (that would cost every startup) and
    -- the FileType path that actually highlights must stay registered.
    local ts = P['nvim-treesitter']
    assert.is_not_nil(ts, 'nvim-treesitter must be registered')
    assert.is_true(ts.lazy, 'nvim-treesitter must stay lazy')
    assert.same({ 'BufReadPost', 'BufNewFile' }, ts.event, 'treesitter must keep its lazy-open events')

    -- Load it directly: once loaded, the highlight path is a cleared augroup so
    -- <leader>ur cannot stack a second FileType handler. :edit on a temp file
    -- would fire that handler, and on a runner with no parser it installs one
    -- over the network inside a unit test.
    require('lazy').load { plugins = { 'nvim-treesitter' } }
    assert.is_true(
      #vim.api.nvim_get_autocmds { group = 'treesitter-start', event = 'FileType' } > 0,
      'treesitter-start FileType augroup must be registered after load'
    )
  end)

  it('highlights a small Python file passed as a startup argument', function()
    local file = vim.fn.tempname() .. '.py'
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.fn.writefile({ 'class Example:', '    pass' }, file)
    -- This buffer exists before lazy setup and never receives FileType, so only
    -- the already-loaded-buffer bootstrap can start it.
    local preload = [[
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.py')
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'class Preloaded:', '    pass' })
      vim.api.nvim_buf_call(buf, function() vim.cmd 'noautocmd setlocal filetype=python' end)
      _G.treesitter_bootstrap_buf = buf
    ]]
    local probe = [[
      local buf = vim.api.nvim_get_current_buf()
      vim.wait(2000, function() return vim.treesitter.highlighter.active[buf] ~= nil end, 50)
      local folds = vim.wo.foldmethod == 'expr' and vim.wo.foldexpr == 'v:lua.vim.treesitter.foldexpr()'
      local bootstrap = vim.treesitter.highlighter.active[_G.treesitter_bootstrap_buf] ~= nil
      io.stdout:write('ft=' .. vim.bo[buf].filetype .. ' active=' .. tostring(vim.treesitter.highlighter.active[buf] ~= nil) .. ' folds=' .. tostring(folds) .. ' bootstrap=' .. tostring(bootstrap))
    ]]
    local res = run {
      vim.v.progpath,
      '--headless',
      '--cmd',
      'lua ' .. (preload:gsub('%s+', ' ')),
      file,
      '-c',
      'lua ' .. (probe:gsub('%s+', ' ')),
      '-c',
      'qa!',
    }
    vim.fn.delete(file)

    assert.is_truthy(
      (res.stdout or ''):match 'ft=python active=true folds=true bootstrap=true',
      'startup Python must highlight, receive Treesitter folding, and prove the loaded-buffer bootstrap ran: ' .. (res.report or '')
    )
  end)

  it('does not highlight a 256KB Lua file passed as a startup argument', function()
    local file = vim.fn.tempname() .. '.lua'
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.fn.writefile({ string.rep('x', 256 * 1024) }, file)
    local probe = [[
      local buf = vim.api.nvim_get_current_buf()
      vim.wait(500)
      io.stdout:write('ft=' .. vim.bo[buf].filetype .. ' active=' .. tostring(vim.treesitter.highlighter.active[buf] ~= nil))
    ]]
    local res = run { vim.v.progpath, '--headless', file, '-c', 'lua ' .. (probe:gsub('%s+', ' ')), '-c', 'qa!' }
    vim.fn.delete(file)

    assert.is_truthy((res.stdout or ''):match 'ft=lua active=false', 'oversized startup Lua buffer must stay unhighlighted: ' .. (res.report or ''))
  end)

  -- A real buffer with a real filetype: `noautocmd setlocal` keeps the rest of
  -- the FileType chain (LSP, ftplugins) out of the unit test. Never call this
  -- with vim.cmd stubbed — the stub would swallow the `:setlocal`.
  local function ft_buffer(kb, ft)
    local name = vim.fn.tempname() .. '.' .. ft
    vim.fn.writefile({ string.rep('x', kb * 1024) }, name) -- size is the point
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, name)
    vim.api.nvim_buf_call(buf, function() vim.cmd('noautocmd setlocal filetype=' .. ft) end)
    return buf, name
  end

  -- Fire the real FileType handler with parser installation, start, and stop
  -- stubbed out: :TSInstall builds a parser over the network on a parser-less
  -- runner, while the real start/stop calls would need that parser. Restored
  -- even if the handler throws.
  local function fire_treesitter(buf)
    local rec = { started = {}, installed = {}, stopped = {} }
    local real_start, real_stop, real_cmd = vim.treesitter.start, vim.treesitter.stop, vim.cmd
    local ok, err = pcall(function()
      vim.treesitter.start = function(b) rec.started[#rec.started + 1] = b end
      vim.treesitter.stop = function(b) rec.stopped[#rec.stopped + 1] = b end
      vim.cmd = function(c)
        if tostring(c):match '^TSInstall' then rec.installed[#rec.installed + 1] = tostring(c) end
      end
      vim.api.nvim_exec_autocmds('FileType', { group = 'treesitter-start', buffer = buf })
    end)
    vim.treesitter.start, vim.treesitter.stop, vim.cmd = real_start, real_stop, real_cmd
    if not ok then error(err) end
    return rec
  end

  it('starts treesitter on a small buffer and stops it over the 200KB cap', function()
    require('lazy').load { plugins = { 'nvim-treesitter' } }
    -- the treesitter cap (200KB) is stricter than large_file_size (1 MiB)
    local big, big_name = ft_buffer(256, 'lua')
    local small, small_name = ft_buffer(8, 'lua')
    local on_big, on_small = fire_treesitter(big), fire_treesitter(small)
    pcall(vim.api.nvim_buf_delete, big, { force = true })
    pcall(vim.api.nvim_buf_delete, small, { force = true })
    vim.fn.delete(big_name)
    vim.fn.delete(small_name)

    assert.same({ small }, on_small.started, 'the small buffer must start highlighting')
    assert.same({}, on_big.started, 'the oversized buffer must not start highlighting')
    assert.same({ big }, on_big.stopped, 'the oversized buffer must stop any existing highlighter')
    assert.same({}, on_small.stopped, 'the small buffer must keep highlighting')
  end)

  it('attempts a parser install at most once per language per session', function()
    assert.are.equal(1, vim.fn.executable 'tree-sitter', 'CI must install the tree-sitter CLI')
    require('lazy').load { plugins = { 'nvim-treesitter' } }
    -- :TSInstall only runs for a language with no parser built, so drive one
    -- this box has not built (none of these are in the 16-language bootstrap)
    local site = vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'parser')
    local lang
    for _, l in ipairs { 'elixir', 'scala', 'haskell' } do
      if vim.uv.fs_stat(vim.fs.joinpath(site, l .. '.so')) == nil then
        lang = l
        break
      end
    end
    assert.is_not_nil(lang, 'test premise: one of these languages must have no parser built')

    local marked, marked_name = ft_buffer(1, lang)
    -- seed the attempt state the way the config writes it: vim.g hands out a
    -- copy of a dict global, so the whole table goes back, not just one key
    local marks = vim.g.treesitter_bootstrap or {}
    marks[lang] = true -- already attempted this session
    vim.g.treesitter_bootstrap = marks
    local after_mark = fire_treesitter(marked)
    local fresh, fresh_name = ft_buffer(1, lang)
    marks[lang] = nil
    vim.g.treesitter_bootstrap = marks
    local after_clear = fire_treesitter(fresh)
    marks[lang] = nil -- leave no state for the rest of the run
    vim.g.treesitter_bootstrap = marks
    pcall(vim.api.nvim_buf_delete, marked, { force = true })
    pcall(vim.api.nvim_buf_delete, fresh, { force = true })
    vim.fn.delete(marked_name)
    vim.fn.delete(fresh_name)

    assert.same({}, after_mark.installed, 'a language already attempted must not be installed again')
    assert.same({ 'TSInstall ' .. lang }, after_clear.installed, 'an unattempted language installs once, by base name')
  end)

  it('leaves class navigation and textobject wrappers inert without a parser', function()
    require('lazy').load { plugins = { 'nvim-treesitter-textobjects' } }
    local previous = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    local calls = {}
    local function called(name)
      return function() calls[#calls + 1] = name end
    end
    local stubs = {
      ['nvim-treesitter-textobjects.select'] = { select_textobject = called 'select' },
      ['nvim-treesitter-textobjects.move'] = {
        goto_next_start = called 'move-next',
        goto_previous_start = called 'move-previous',
      },
      ['nvim-treesitter-textobjects.swap'] = {
        swap_next = called 'swap-next',
        swap_previous = called 'swap-previous',
      },
    }
    local saved = {}
    for name, stub in pairs(stubs) do
      saved[name] = package.loaded[name]
      package.loaded[name] = stub
    end

    local ok, err = pcall(function()
      assert.is_nil(vim.treesitter.get_parser(buf, nil, { error = false }), 'test premise: scratch buffer must have no parser')
      for _, mapping in ipairs {
        { 'n', '[C' },
        { 'n', ']C' },
        { 'o', 'ac' },
        { 'o', 'ic' },
        { 'n', ']m' },
        { 'n', ']a' },
      } do
        local map = vim.fn.maparg(mapping[2], mapping[1], false, true)
        assert.is_function(map.callback, mapping[1] .. ' ' .. mapping[2] .. ' must keep its Lua callback')
        map.callback()
      end
    end)

    for name in pairs(stubs) do
      package.loaded[name] = saved[name]
    end
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(buf, { force = true })
    if not ok then error(err) end
    assert.same({}, calls, 'parserless wrappers must not call textobjects')
  end)

  it('keeps nvim-ts-autotag scoped to markup filetypes', function()
    local at = P['nvim-ts-autotag']
    assert.is_not_nil(at, 'nvim-ts-autotag must be registered')
    for _, ft in ipairs { 'html', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'xml' } do
      assert.is_true(vim.tbl_contains(at.ft, ft), 'nvim-ts-autotag must cover ' .. ft)
    end
  end)

  it('keeps the deprecated heavy plugins out of the tree', function()
    for _, name in ipairs {
      'nvim-telescope/telescope.nvim',
      'folke/noice.nvim',
      'nvim-neo-tree/neo-tree.nvim',
      'folke/hlchunk.nvim',
      'folke/fzf-lua',
      'ThePrimeagen/fidget.nvim',
    } do
      local key = name:match '[^/]+$'
      assert.is_nil(P[key], key .. ' must no longer be registered')
    end
  end)
end)
