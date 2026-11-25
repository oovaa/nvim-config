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
      'git-conflict.nvim',
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

  it('routes actions-preview and the todo picker through snacks', function()
    -- both used to hang off plugins this config dropped; a stale backend or a
    -- dead require only shows up when the key is pressed, so drive them.
    local ap = assert_spec 'actions-preview.nvim'
    assert.same({ 'snacks' }, ap.opts and ap.opts.backend, 'actions-preview backend must be snacks')

    -- lazy.nvim swaps the key's callback for the real handler only once the
    -- owning plugin is loaded; before that it is a trigger stub that re-feeds
    -- the key, so calling it directly would prove nothing.
    require('lazy').load { plugins = { 'todo-comments.nvim' } }
    local m = mapped '<leader>st'
    assert.is_not_nil(m and next(m) ~= nil, '<leader>st must be mapped')
    assert.is_function(m.callback, '<leader>st must resolve to a real handler')

    local snacks = require 'snacks'
    local orig, called = snacks.picker.todo_comments, 0
    snacks.picker.todo_comments = function() called = called + 1 end
    local ok, err = pcall(m.callback)
    snacks.picker.todo_comments = orig
    assert.is_truthy(ok, tostring(err))
    assert.equals(1, called, '<leader>st must open the snacks todo picker')
  end)

  it('sp opens the projects picker, not a files picker in the cwd', function()
    local m = mapped '<leader>sp'
    assert.is_function(m and m.callback, '<leader>sp must resolve to a real handler')
    assert.is_truthy((m.desc or ''):find('[P]rojects', 1, true) ~= nil, '<leader>sp desc should mention Projects: ' .. tostring(m.desc))
    assert.is_falsy((m.desc or ''):find('builtin root', 1, true), 'a projects picker must not claim a builtin-root files search')

    local snacks = require 'snacks'
    local real_projects, real_files = snacks.picker.projects, snacks.picker.files
    local projects_calls, files_calls = 0, 0
    snacks.picker.projects = function() projects_calls = projects_calls + 1 end
    snacks.picker.files = function() files_calls = files_calls + 1 end
    local ok, err = pcall(m.callback)
    snacks.picker.projects, snacks.picker.files = real_projects, real_files
    assert.is_truthy(ok, tostring(err))
    assert.equals(1, projects_calls, '<leader>sp must invoke the projects picker')
    assert.equals(0, files_calls, '<leader>sp must not invoke the files picker')
  end)

  it('<leader>sp confirm sources the canonical session for the chosen project', function()
    local m = mapped '<leader>sp'
    local snacks = require 'snacks'
    local real_projects, real_files = snacks.picker.projects, snacks.picker.files
    local confirm, files_opts = nil, nil
    local dir = vim.fn.tempname() .. '-project'
    vim.fn.mkdir(dir, 'p')
    local session = require('config.sessions').session_file_for(dir)
    vim.fn.mkdir(vim.fn.fnamemodify(session, ':h'), 'p')
    vim.fn.writefile({ 'let g:deep_fix_sp_sourced = 1' }, session)
    local before_cwd = vim.fn.getcwd()
    local ok, err = pcall(function()
      snacks.picker.projects = function(opts) confirm = opts and opts.confirm end
      m.callback()
      assert.is_function(confirm, 'projects picker must supply a confirm handler')
      confirm({ close = function() end }, { file = dir, text = dir })
      assert.equals(1, vim.g.deep_fix_sp_sourced or 0, 'the canonical session must be sourced, not a snacks dashboard session')
      assert.equals(vim.fn.fnamemodify(dir, ':p'), vim.fn.fnamemodify(vim.fn.getcwd(), ':p'), 'confirm must chdir to the chosen project')

      vim.g.deep_fix_sp_sourced, files_opts = nil, nil
      vim.fn.delete(session)
      snacks.picker.files = function(opts) files_opts = opts end
      confirm({ close = function() end }, { file = dir, text = dir })
      assert.is_nil(vim.g.deep_fix_sp_sourced, 'a project with no session must not source anything')
      assert.same({ cwd = dir }, files_opts, 'a project with no session must open a files picker at that dir')
    end)
    snacks.picker.projects, snacks.picker.files = real_projects, real_files
    vim.cmd('cd ' .. vim.fn.fnameescape(before_cwd))
    vim.g.deep_fix_sp_sourced = nil
    vim.fn.delete(session)
    vim.fn.delete(dir, 'rf')
    assert.is_truthy(ok, tostring(err))
  end)

  it('keeps notification history mapped', function()
    local m = mapped '<leader>nn'
    assert.is_function(m and m.callback, '<leader>nn must resolve to a real handler')
    assert.is_truthy((m.desc or ''):find('Notification', 1, true), '<leader>nn desc should mention Notification')
  end)

  it('gy yanks the nearest diagnostic message, not the line total', function()
    local ns = vim.api.nvim_create_namespace 'gy-test'
    local prev = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'xy' })
    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, end_col = 1, message = 'far diagnostic', severity = 1 },
      { lnum = 0, col = 1, end_col = 2, message = 'near diagnostic', severity = 1 },
    })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    local notices = {}
    local real_notify, real_clipboard = vim.notify, vim.o.clipboard
    vim.notify = function(msg) notices[#notices + 1] = tostring(msg) end
    vim.o.clipboard = '' -- force the default register: headless has no '+' provider
    local ok, err = pcall(function()
      local m = mapped 'gy'
      assert.is_function(m and m.callback, 'gy must resolve to a real handler')
      m.callback()
    end)
    local yanked = vim.fn.getreg '"'
    vim.notify, vim.o.clipboard = real_notify, real_clipboard
    vim.api.nvim_set_current_buf(prev)
    vim.diagnostic.reset(ns, buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    assert.is_true(ok, tostring(err))
    assert.equals('near diagnostic', yanked, 'gy must yank the nearest diagnostic message')
    assert.is_false(notices[1] and notices[1]:find('Yanked 2 diagnostics', 1, true) ~= nil, 'gy must not report the line total')
  end)

  it('<leader>yd yanks all diagnostics on the line and reports the plural count', function()
    local ns = vim.api.nvim_create_namespace 'yd-test'
    local prev = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'xy' })
    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, end_col = 1, message = 'first problem', severity = 1 },
      { lnum = 0, col = 1, end_col = 2, message = 'second problem', severity = 1 },
    })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local notices = {}
    local real_notify, real_clipboard = vim.notify, vim.o.clipboard
    vim.notify = function(msg) notices[#notices + 1] = tostring(msg) end
    vim.o.clipboard = '' -- headless has no '+' provider
    local ok, err = pcall(function()
      local m = mapped '<leader>yd'
      assert.is_function(m and m.callback, '<leader>yd must resolve to a real handler')
      m.callback()
    end)
    local yanked = vim.fn.getreg '"'
    vim.notify, vim.o.clipboard = real_notify, real_clipboard
    vim.api.nvim_set_current_buf(prev)
    vim.diagnostic.reset(ns, buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    assert.is_true(ok, tostring(err))
    assert.equals('first problem\nsecond problem', yanked, '<leader>yd must join every message')
    assert.is_truthy(notices[1] and notices[1]:find('Yanked 2 diagnostics', 1, true), 'must report the plural count: ' .. tostring(notices[1]))
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
    -- Task 10 owns these labels; <leader>n is a group only, so <leader>nt*
    -- actions stay reachable while the prefixes are discoverable. Which-key's
    -- [H] style splits words with brackets, so strip them before comparing.
    local function label(key) return (registered[key] or ''):gsub('[%[%]]', '') end
    assert.equals('Host preview / HTTP', label '<leader>h', '<leader>h must describe KiteHost/HTTP, not hot reload')
    assert.equals('Notifications / Neovim tips', label '<leader>n', '<leader>n must group Notifications/Neovim tips')
    assert.equals('Neovim Tips', label '<leader>nt', '<leader>nt must group Neovim Tips')
  end)
end)
