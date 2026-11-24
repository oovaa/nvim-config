-- LSP lifecycle: root callbacks must be buffer-local and asynchronous.
-- Run with: nvim --headless -c "lua require('plenary.busted').run('tests/test_lsp_lifecycle.lua')" -c 'qa!'

local editing = require 'plugins.editing'

local function jdtls_spec()
  for _, spec in ipairs(editing) do
    if spec[1] == 'mfussenegger/nvim-jdtls' then return spec end
  end
  error 'nvim-jdtls spec not found'
end

describe('lsp lifecycle', function()
  local root = '/tmp/nvim-lsp-lifecycle-' .. tostring(vim.uv.hrtime())
  local old_executable, old_isdirectory, old_notify
  local old_java, old_jdtls, old_blink

  before_each(function()
    vim.fn.mkdir(root, 'p')
    old_executable, old_isdirectory, old_notify = vim.fn.executable, vim.fn.isdirectory, vim.notify
    old_java = package.loaded.java
    old_jdtls = package.loaded.jdtls
    old_blink = package.loaded['blink.cmp']
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
    package.loaded.java, package.loaded.jdtls, package.loaded['blink.cmp'] = old_java, old_jdtls, old_blink
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

  it('attaches each Java buffer with its own root, data dir and launcher', function()
    package.loaded['blink.cmp'] = { get_lsp_capabilities = function() error 'JDTLS must not require Blink capabilities' end }
    local recorded, requested = {}, nil
    require('jdtls').start_or_attach = function(opts, start_opts)
      recorded[#recorded + 1] = opts
      requested = start_opts
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
    assert.same({ bufnr = buf_a, dap = { hotcodereplace = 'auto' } }, requested)
    local opts_a = recorded[#recorded]
    fire(buf_b)
    assert.same({ bufnr = buf_b, dap = { hotcodereplace = 'auto' } }, requested)
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
end)
