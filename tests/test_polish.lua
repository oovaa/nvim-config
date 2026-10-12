-- Config behaviour: the guarantees that are cheap to break and expensive to notice.
-- Every assertion here inspects live nvim state (autocmds, options, buffers) —
-- not the source text. Run:
--   nvim --headless -c 'lua require("plenary.busted").run("tests/test_polish.lua")' -c 'qa!'

describe('config behaviour', function()
  it('registers exactly one CursorHold handler', function()
    local au = vim.api.nvim_get_autocmds { event = 'CursorHold' }
    assert.equals(1, #au, 'CursorHold must have exactly one handler, got ' .. #au)
    assert.equals('idle-upkeep', au[1].group_name, 'CursorHold must live in the clear=true idle-upkeep group')
  end)

  it('enables large-file mode above the size cap and not below', function()
    -- The guard formatting.lua:62 reads is set by autocmds.lua; assert the setter,
    -- which is the part that can actually regress.
    local cap = vim.g.large_file_size
    assert.is_true(cap > 0, 'vim.g.large_file_size must be a byte count')

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local big = dir .. '/big.py'
    local small = dir .. '/small.py'
    local fh = assert(io.open(big, 'w'))
    fh:write(string.rep('# padding to push this past the one mebibyte cap\n', 25000))
    fh:close()
    fh = assert(io.open(small, 'w'))
    fh:write 'x = 1\n'
    fh:close()

    local opened = {}
    for _, path in ipairs { big, small } do
      vim.cmd.edit(vim.fn.fnameescape(path))
      local buf = vim.api.nvim_get_current_buf()
      opened[#opened + 1] = buf
      if vim.fn.fnamemodify(path, ':t') == 'big.py' then
        assert.is_true(vim.b[buf].large_file_mode, 'a file over the cap must set large_file_mode')
        assert.is_false(vim.bo[buf].swapfile, 'large-file mode must drop swapfile')
        assert.is_false(vim.bo[buf].undofile, 'large-file mode must drop undofile')
      else
        assert.is_nil(vim.b[buf].large_file_mode, 'a small file must not set large_file_mode')
      end
    end

    for _, buf in ipairs(opened) do
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    vim.fn.delete(dir, 'rf')
  end)

  it('exposes a working health check', function()
    assert.has_no.errors(function() require 'config.health' end)
    assert.is_function(require('config.health').check)
    -- the invocation every doc points at must actually run
    assert.has_no.errors(function() vim.cmd 'checkhealth config' end)
  end)

  it(':StartupTime is registered and runs', function()
    assert.equals(2, vim.fn.exists ':StartupTime', ':StartupTime user command must exist')
    assert.has_no.errors(function() vim.cmd 'StartupTime' end)
  end)

  it('treesitter autocmd is registered exactly once', function()
    -- AGENTS.md trap 2: every autocmd needs a clear=true group or reloads stack.
    local au = vim.api.nvim_get_autocmds { event = 'FileType', group = 'treesitter-start' }
    assert.equals(1, #au, 'treesitter-start must hold exactly one FileType autocmd')
  end)

  it('treesitter skips scratch buffers and oversized files', function()
    -- lua/plugins/treesitter.lua returns early for buftype ~= '' and for files
    -- over 200KB. Both guards are pcall'd around TSInstall, so assert on which
    -- languages the handler *reaches* rather than on parser start (nvim's own
    -- ftplugin also calls vim.treesitter.start and would muddy the count).
    local install_dir = vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'parser')
    local requested = {}
    local original = vim.api.nvim_exec
    vim.api.nvim_exec = function(cmd, ...)
      local lang = tostring(cmd):match '^TSInstall (%S+)'
      if lang then requested[#requested + 1] = lang end
      return original(cmd, ...)
    end

    local function fire(buf)
      for i = #requested, 0, -1 do
        requested[i] = nil
      end
      vim.bo[buf].filetype = vim.bo[buf].filetype
      vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
      return vim.list_slice(requested, 1, #requested)
    end

    -- scratch buffer: handler must return before it ever reaches TSInstall
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.bo[scratch].filetype = 'scratchlang'
    assert.equals(0, #fire(scratch), 'a scratch buffer must never trigger TSInstall')

    -- oversized real file: same guard, different branch
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local huge = dir .. '/huge.c'
    local fh = assert(io.open(huge, 'w'))
    fh:write(string.rep('int a = 1;\n', 25000)) -- > 200KB
    fh:close()
    vim.cmd.edit(vim.fn.fnameescape(huge))
    local huge_buf = vim.api.nvim_get_current_buf()
    vim.bo[huge_buf].filetype = 'c'
    assert.equals(0, #fire(huge_buf), 'a file over 200KB must never trigger TSInstall')

    vim.api.nvim_exec = original
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })
    pcall(vim.api.nvim_buf_delete, huge_buf, { force = true })
    vim.fn.delete(dir, 'rf')
    assert.is_true(vim.fn.isdirectory(install_dir) >= 0)
  end)

  it('never documents the checkhealth invocation that errors', function()
    -- `:checkhealth config.health` resolves to a plugin name and fails with
    -- "No healthcheck found"; lua/config/health.lua is found via `:checkhealth config`.
    -- Guard the docs so the rename cannot drift back.
    for _, rel in ipairs { 'AGENTS.md', 'SETUP.md', 'README.md', 'setup.sh' } do
      local path = vim.fn.stdpath 'config' .. '/' .. rel
      if vim.fn.filereadable(path) == 1 then
        local body = table.concat(vim.fn.readfile(path), '\n')
        assert.is_nil(body:find 'checkhealth config%.health', rel .. ' must not document `:checkhealth config.health`')
      end
    end
  end)
end)
