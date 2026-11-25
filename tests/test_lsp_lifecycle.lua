-- LSP lifecycle: root callbacks must be buffer-local and asynchronous.
-- Run with: nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'

local editing = require 'plugins.editing'

local function jdtls_spec()
  for _, spec in ipairs(editing) do
    if spec[1] == 'mfussenegger/nvim-jdtls' then return spec end
  end
  error 'nvim-jdtls spec not found'
end

local function vtsls_spec()
  for _, spec in ipairs(editing) do
    if spec[1] == 'yioneko/nvim-vtsls' then return spec end
  end
  error 'nvim-vtsls spec not found'
end

local function mason_spec()
  for _, spec in ipairs(require 'plugins.lsp') do
    if spec[1] == 'mason-org/mason.nvim' then return spec end
  end
  error 'mason.nvim spec not found'
end

describe('lsp lifecycle', function()
  local root = '/tmp/nvim-lsp-lifecycle-' .. tostring(vim.uv.hrtime())
  local old_executable, old_isdirectory, old_notify
  local old_java, old_jdtls, old_blink, old_vtsls
  local old_get_client, old_get_clients, old_clear_references, old_start, old_detach, old_codelens

  before_each(function()
    vim.fn.mkdir(root, 'p')
    old_executable, old_isdirectory, old_notify = vim.fn.executable, vim.fn.isdirectory, vim.notify
    old_java = package.loaded.java
    old_jdtls = package.loaded.jdtls
    old_blink = package.loaded['blink.cmp']
    old_vtsls = package.loaded.vtsls
    old_get_client, old_get_clients, old_clear_references = vim.lsp.get_client_by_id, vim.lsp.get_clients, vim.lsp.buf.clear_references
    old_start, old_detach = vim.lsp.start, vim.lsp.buf_detach_client
    old_codelens = vim.lsp.codelens
    vim.fn.executable = function(name)
      if name == 'java' then return 1 end
      return old_executable(name)
    end
    vim.fn.isdirectory = function(path)
      if path:match '/jdtls/config_' then return 1 end
      return old_isdirectory(path)
    end
    vim.notify = function() end
    package.loaded.java = {}
    package.loaded.jdtls = {}
  end)

  after_each(function()
    vim.fn.executable, vim.fn.isdirectory, vim.notify = old_executable, old_isdirectory, old_notify
    vim.lsp.get_client_by_id, vim.lsp.get_clients, vim.lsp.buf.clear_references = old_get_client, old_get_clients, old_clear_references
    vim.lsp.start, vim.lsp.buf_detach_client = old_start, old_detach
    vim.lsp.codelens = old_codelens
    package.loaded.java, package.loaded.jdtls, package.loaded['blink.cmp'], package.loaded.vtsls = old_java, old_jdtls, old_blink, old_vtsls
    pcall(vim.api.nvim_del_augroup_by_name, 'jdtls-attach')
    vim.fn.delete(root, 'rf')
  end)

  it('calls Tailwind root_dir once with the root and never with nil', function()
    local config = require('config.lsp_servers').servers.tailwindcss
    local buf = vim.api.nvim_create_buf(true, false)
    local project = root .. '/tailwind'
    vim.fn.mkdir(project .. '/src', 'p')
    vim.fn.writefile({}, project .. '/tailwind.config.js')
    vim.api.nvim_buf_set_name(buf, project .. '/src/index.ts')
    vim.bo[buf].filetype = 'typescript'
    vim.api.nvim_exec_autocmds('FileType', { buffer = buf })

    local old_root, calls = vim.fs.root, {}
    vim.fs.root = function(source, markers)
      assert.equals(buf, source, 'root discovery must use the buffer number')
      assert.same(config.root_markers, markers)
      return project
    end
    local ok, err = pcall(function()
      config.root_dir(buf, function(found) calls[#calls + 1] = found end)
    end)
    vim.fs.root = old_root
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_true(ok, tostring(err))
    assert.same({ project }, calls, 'the discovered root must be delivered exactly once')
  end)

  it('does not call Tailwind on_dir without a discovered root', function()
    local config = require('config.lsp_servers').servers.tailwindcss
    local buf = vim.api.nvim_create_buf(true, false)
    local project = root .. '/tailwind-missing'
    vim.fn.mkdir(project .. '/src', 'p')
    vim.api.nvim_buf_set_name(buf, project .. '/src/index.ts')
    assert.is_nil(vim.fs.root(buf, config.root_markers), 'fixture must not inherit a Tailwind root')

    local count = 0
    local ok, err = pcall(function()
      config.root_dir(buf, function(found)
        count = count + 1
        assert.is_not_nil(found, 'on_dir must never receive nil')
      end)
    end)
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_true(ok, tostring(err))
    assert.equals(0, count, 'no root means no callback, including no nil callback')
  end)

  it('only enables CodeLens for named buffers', function()
    local enabled = {}
    vim.lsp.get_client_by_id = function()
      return {
        id = 61,
        supports_method = function(_, method) return method == 'textDocument/codeLens' end,
      }
    end
    vim.lsp.codelens = {
      enable = function(on, opts) enabled[#enabled + 1] = { on, opts.bufnr } end,
    }
    local unnamed = vim.api.nvim_create_buf(true, false)
    local named = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(named, root .. '/codelens.md')

    local ok, err = pcall(mason_spec().config)
    assert.is_true(ok, tostring(err))
    local attach = vim.api.nvim_get_autocmds({ event = 'LspAttach', group = 'kickstart-lsp-attach' })[1]
    assert.is_function(attach.callback)
    attach.callback { buf = unnamed, data = { client_id = 61 } }
    attach.callback { buf = named, data = { client_id = 61 } }

    assert.same({ { true, named } }, enabled, 'unnamed buffers have no textDocument URI for CodeLens')
    vim.api.nvim_buf_delete(unnamed, { force = true })
    vim.api.nvim_buf_delete(named, { force = true })
  end)

  it('keeps highlight autocmds until the final supporting client detaches', function()
    local buf = vim.api.nvim_create_buf(true, false)
    local other = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(other)
    local clients = {
      { id = 41, name = 'fake-highlight-a', bufnr = buf },
      { id = 42, name = 'fake-highlight-b', bufnr = buf },
    }
    for _, client in ipairs(clients) do
      client.supports_method = function(self, method, bufnr) return method == 'textDocument/documentHighlight' and bufnr == self.bufnr end
    end
    local active = { clients[1], clients[2] }
    local by_id = { [41] = clients[1], [42] = clients[2] }
    local cleared, cleared_buf = 0, nil
    vim.lsp.get_client_by_id = function(id) return by_id[id] end
    vim.lsp.get_clients = function(opts)
      local attached = {}
      for _, client in ipairs(active) do
        if client.bufnr == opts.bufnr then attached[#attached + 1] = client end
      end
      return attached
    end
    vim.lsp.buf.clear_references = function()
      cleared = cleared + 1
      cleared_buf = vim.api.nvim_get_current_buf()
    end

    local ok, err = pcall(mason_spec().config)
    assert.is_true(ok, tostring(err))
    local function callback(event, group)
      local autocmds = vim.api.nvim_get_autocmds { event = event, group = group }
      assert.is_true(#autocmds > 0, group .. ' must have a ' .. event .. ' autocmd')
      assert.is_function(autocmds[1].callback)
      return autocmds[1].callback
    end
    local function highlight_ids()
      local ids = {}
      for _, autocmd in ipairs(vim.api.nvim_get_autocmds { buffer = buf }) do
        if autocmd.group_name == 'kickstart-lsp-highlight' then ids[#ids + 1] = autocmd.id end
      end
      return ids
    end

    local attach = callback('LspAttach', 'kickstart-lsp-attach')
    attach { buf = buf, data = { client_id = 41 } }
    attach { buf = buf, data = { client_id = 42 } }
    local remaining = highlight_ids()
    assert.equals(4, #remaining, 'both highlight handlers must be registered once')

    local detach = callback('LspDetach', 'kickstart-lsp-detach')
    active = { clients[2] }
    detach { buf = buf, data = { client_id = 41 } }
    assert.same(remaining, highlight_ids(), "one detach must preserve the other client's handlers")
    assert.equals(0, cleared, 'references must remain while a supporting client is attached')

    active = {}
    detach { buf = buf, data = { client_id = 42 } }
    assert.same({}, highlight_ids(), 'the final supporting detach must remove the handlers')
    assert.equals(1, cleared, 'references must be cleared after the final supporting detach')
    assert.equals(buf, cleared_buf, 'references must be cleared in the detached buffer, not the current buffer')
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.api.nvim_buf_delete(other, { force = true })
  end)

  it('detaches inapplicable clients and refreshes language ids after filetype changes', function()
    package.loaded.vtsls = { config = function() end }
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, root .. '/changing.ts')
    local function set_filetype(ft)
      vim.api.nvim_buf_call(buf, function() vim.cmd('noautocmd set ft=' .. ft) end)
    end
    set_filetype 'typescript'
    local function fake_client(id, name, language_id)
      return {
        id = id,
        name = name,
        attached_buffers = { [buf] = language_id },
        closed = 0,
        opened = 0,
        get_language_id = function(bufnr, ft) return ft end,
        _text_document_did_close_handler = function(self) self.closed = self.closed + 1 end,
        _text_document_did_open_handler = function(self) self.opened = self.opened + 1 end,
      }
    end
    local ts = fake_client(51, 'vtsls', 'typescript')
    local json = fake_client(52, 'jsonls', 'json')
    local active = { ts }
    local detached, starts = {}, {}
    vim.lsp.get_clients = function(opts)
      local clients = {}
      for _, client in ipairs(active) do
        if client.attached_buffers[opts.bufnr] then clients[#clients + 1] = client end
      end
      return clients
    end
    vim.lsp.buf_detach_client = function(bufnr, id)
      detached[#detached + 1] = { bufnr, id }
      for i, client in ipairs(active) do
        if client.id == id then table.remove(active, i) end
      end
    end
    vim.lsp.start = function(config, opts) starts[#starts + 1] = { name = config.name, bufnr = opts.bufnr } end

    local ok, err = pcall(function()
      vtsls_spec().config()
      mason_spec().config()
    end)
    assert.is_true(ok, tostring(err))
    starts = {}
    local function callback(event, group)
      local autocmds = vim.api.nvim_get_autocmds { event = event, group = group }
      assert.is_true(#autocmds > 0, group .. ' must have a ' .. event .. ' autocmd')
      assert.is_function(autocmds[1].callback)
      return autocmds[1].callback
    end
    local apply = callback('FileType', 'lsp-buffer-applicability')
    local start_json = callback('FileType', 'lsp-on-demand-jsonls')
    local start_vtsls = callback('FileType', 'vtsls-enable')

    set_filetype 'json'
    apply { buf = buf }
    start_json { buf = buf }
    assert.same({ { buf, ts.id } }, detached, 'VTSLS must detach when the buffer is no longer TypeScript')
    assert.is_true(vim.tbl_contains(vim.tbl_map(function(item) return item.name end, starts), 'jsonls'), 'JSON LS must still start')

    active = { json }
    set_filetype 'jsonc'
    apply { buf = buf }
    start_json { buf = buf }
    assert.same({ { buf, ts.id } }, detached, 'a supported filetype change must not detach JSON LS')
    assert.equals(1, json.closed, 'JSON LS must close the old language document')
    assert.equals(1, json.opened, 'JSON LS must open the new language document')
    assert.equals('jsonc', json.attached_buffers[buf], 'JSON LS must track the new language id')

    vim.bo[buf].buftype = 'nofile'
    local before = #starts
    set_filetype 'json'
    apply { buf = buf }
    start_json { buf = buf }
    set_filetype 'typescript'
    start_vtsls { buf = buf }
    assert.equals(before, #starts, 'non-file buffers must not start native or direct LSP clients')
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it('attaches each Java buffer with its own root, data dir and launcher', function()
    package.loaded['blink.cmp'] = { get_lsp_capabilities = function() error 'JDTLS must not require Blink capabilities' end }
    local recorded, requested, start_args = {}, nil, nil
    require('jdtls').start_or_attach = function(opts, dap_opts, start_opts)
      recorded[#recorded + 1] = opts
      requested = dap_opts
      start_args = start_opts
    end

    local project_a = root .. '/java-a'
    local project_b = root .. '/java-b'
    for _, project in ipairs { project_a, project_b } do
      vim.fn.mkdir(project .. '/src', 'p')
      vim.fn.writefile({}, project .. '/pom.xml')
    end
    local old_glob = vim.fn.glob
    vim.fn.glob = function(pattern, ...)
      if pattern:match 'org%.eclipse%.equinox%.launcher_%*%.jar' then
        return vim.fn.stdpath 'data' .. '/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_1.jar'
      end
      if pattern:match 'java%-test/extension/server' or pattern:match 'java%-debug%-adapter/extension/server' then return '' end
      return old_glob(pattern, ...)
    end

    local ok, err = pcall(jdtls_spec().config)
    vim.fn.glob = old_glob
    assert.is_true(ok, tostring(err))

    local autocmds = vim.api.nvim_get_autocmds { event = 'FileType', pattern = 'java', group = 'jdtls-attach' }
    assert.equals(1, #autocmds, 'Java attachment must use one named FileType autocmd')
    assert.is_function(autocmds[1].callback)

    local buf_a = vim.api.nvim_create_buf(true, false)
    local buf_b = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf_a, project_a .. '/src/A.java')
    vim.api.nvim_buf_set_name(buf_b, project_b .. '/src/B.java')
    -- Assert the callback receives its own bufnr, not the current buffer.
    vim.api.nvim_set_current_buf(buf_b)
    local function fire(bufnr)
      autocmds[1].callback { buf = bufnr, bufnr = bufnr, id = autocmds[1].id, event = 'FileType', match = 'java', group = autocmds[1].group_name }
    end
    fire(buf_a)
    assert.same({ dap = { hotcodereplace = 'auto' } }, requested, 'DAP opts belong in the second argument slot')
    assert.same({ bufnr = buf_a }, start_args, 'bufnr belongs in the third argument slot')
    local opts_a = recorded[#recorded]
    fire(buf_b)
    assert.same({ dap = { hotcodereplace = 'auto' } }, requested)
    assert.same({ bufnr = buf_b }, start_args, 'each buffer gets its own bufnr in the third slot')
    local opts_b = recorded[#recorded]
    vim.b[buf_a].large_file_mode = true
    local before_large = #recorded
    fire(buf_a)
    assert.equals(before_large, #recorded, 'large Java buffers must be skipped')
    vim.api.nvim_buf_delete(buf_a, { force = true })
    vim.api.nvim_buf_delete(buf_b, { force = true })

    for i, opts in ipairs { opts_a, opts_b } do
      local project = i == 1 and project_a or project_b
      assert.equals(project, opts.root_dir)
      local data_arg = opts.cmd[#opts.cmd - 1]
      assert.equals('-data', data_arg)
      assert.equals(vim.fn.stdpath 'cache' .. '/jdtls/' .. vim.fn.fnamemodify(project, ':p:h:t') .. '-' .. vim.fn.sha256(project), opts.cmd[#opts.cmd])
      assert.equals('java', opts.cmd[1])
      -- The installed launcher is shared; the root-derived data dir isolates workspaces.
      assert.equals(vim.fn.stdpath 'data' .. '/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_1.jar', opts.cmd[13])
      assert.equals('-configuration', opts.cmd[14])
      assert.is_table(opts.capabilities, 'built-in capabilities must be available without Blink')
      assert.same({}, opts.bundles)
    end
  end)

  it('attaches an already-open Java buffer through the per-buffer handler and skips large files', function()
    local recorded, requested, start_args = {}, nil, nil
    require('jdtls').start_or_attach = function(opts, dap_opts, start_opts)
      recorded[#recorded + 1] = opts
      requested = dap_opts
      start_args = start_opts
    end

    local project = root .. '/java-open'
    local large_project = root .. '/java-open-large'
    for _, dir in ipairs { project, large_project } do
      vim.fn.mkdir(dir .. '/src', 'p')
      vim.fn.writefile({}, dir .. '/pom.xml')
    end
    local old_glob = vim.fn.glob
    vim.fn.glob = function(pattern, ...)
      if pattern:match 'org%.eclipse%.equinox%.launcher_%*%.jar' then
        return vim.fn.stdpath 'data' .. '/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_1.jar'
      end
      if pattern:match 'java%-test/extension/server' or pattern:match 'java%-debug%-adapter/extension/server' then return '' end
      return old_glob(pattern, ...)
    end

    local buf = vim.api.nvim_create_buf(true, false)
    local large_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, project .. '/src/Open.java')
    vim.api.nvim_buf_set_name(large_buf, large_project .. '/src/Large.java')
    -- Suppress FileType so lazy does not run the config before the sweep test.
    vim.api.nvim_buf_call(buf, function() vim.cmd 'noautocmd setfiletype java' end)
    vim.api.nvim_buf_call(large_buf, function() vim.cmd 'noautocmd setfiletype java' end)
    vim.b[large_buf].large_file_mode = true

    local ok, err = pcall(jdtls_spec().config)
    vim.fn.glob = old_glob
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.api.nvim_buf_delete(large_buf, { force = true })
    assert.is_true(ok, tostring(err))

    local autocmds = vim.api.nvim_get_autocmds { event = 'FileType', pattern = 'java', group = 'jdtls-attach' }
    assert.equals(1, #autocmds, 'the sweep and future FileType events must share one handler')
    assert.equals(1, #recorded, 'only the small already-open Java buffer should attach during the sweep')
    assert.same({ dap = { hotcodereplace = 'auto' } }, requested)
    assert.same({ bufnr = buf }, start_args, 'the sweep must pass its buffer via the third argument slot')
    assert.equals(project, recorded[1].root_dir)
    assert.equals(
      vim.fn.stdpath 'cache' .. '/jdtls/' .. vim.fn.fnamemodify(project, ':p:h:t') .. '-' .. vim.fn.sha256(project),
      recorded[1].cmd[#recorded[1].cmd]
    )
  end)
end)
