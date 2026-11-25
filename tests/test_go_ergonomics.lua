-- Go-backend ergonomics: assert the live mappings and the resolved linter, not
-- the text of the lua files. Run:
--   nvim --headless -c 'lua require("plenary.busted").run("tests/test_go_ergonomics.lua")' -c 'qa!'

describe('go backend ergonomics', function()
  local function mapped(lhs, mode) return vim.fn.maparg(lhs, mode or 'n', false, true) end

  local function lint_mod()
    local ok, lazy = pcall(require, 'lazy')
    if ok then pcall(lazy.load, { plugins = { 'nvim-lint' } }) end
    return require 'lint'
  end

  -- Anchored at /tmp, not tempname(): $TMPDIR may live under a go.mod.
  local function tmpdir()
    local dir = ('/tmp/nvim-go-ergonomics-%d'):format(vim.uv.hrtime())
    vim.fn.mkdir(dir, 'p')
    return dir
  end

  -- Resolve the configured Go linter the way nvim-lint's try_lint does, with
  -- the buffer under test current (the resolver reads the current buffer).
  local function go_linter_in(fname)
    local lint = lint_mod()
    local prev = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_name(buf, fname)
    local name = lint.linters_by_ft.go[1]
    local linter = lint.linters[name]
    if type(linter) == 'function' then linter = linter() end
    vim.api.nvim_set_current_buf(prev)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return linter
  end

  it('runs Go files with `go run .` via the existing runner key', function()
    local f = vim.fn.tempname() .. '.go'
    vim.fn.writefile({ 'package main', 'func main() {}' }, f)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, f)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = 'go'

    local cmds = {}
    local real_cmd = vim.cmd
    -- vim.cmd is callable; a callable table records the command and swallows
    -- the helper calls (wincmd, startinsert) the runner makes after it.
    vim.cmd = setmetatable({}, {
      __call = function(_, arg) cmds[#cmds + 1] = tostring(arg) end,
      __index = function()
        return function() end
      end,
    })
    local ok, err = pcall(function() mapped('<leader>R').callback() end)
    vim.cmd = real_cmd
    assert.is_true(ok, tostring(err))

    local joined = table.concat(cmds, ' ')
    assert.is_truthy(joined:find('go run %.', 1), 'runner must use `go run .`: ' .. joined)
    assert.is_truthy(joined:find(f, 1, true), 'runner must pass the Go file: ' .. joined)
    -- both built-in runner keys point at the same handler
    assert.equals(mapped('<leader>R').callback, mapped('<leader>rf').callback, '<leader>R and <leader>rf share the runner')
    vim.fn.delete(f)
  end)

  it('<leader>dT exists and calls dap-go.debug_test()', function()
    require('lazy').load { plugins = { 'nvim-dap-go' } }
    local m = mapped '<leader>dT'
    assert.is_function(m and m.callback, '<leader>dT must be mapped to a callable handler')

    local dapgo = require 'dap-go'
    assert.is_function(dapgo.debug_test, 'dap-go must expose debug_test()')
    local original = dapgo.debug_test
    local called = 0
    dapgo.debug_test = function() called = called + 1 end
    local ok, err = pcall(m.callback)
    dapgo.debug_test = original
    assert.is_true(ok, tostring(err))
    assert.equals(1, called, '<leader>dT must invoke dap-go.debug_test() exactly once')
  end)

  it('pins golangci-lint cwd to the buffer module root, not nvim cwd', function()
    local root = tmpdir()
    vim.fn.writefile({ 'module example.com/probe' }, root .. '/go.mod')
    local sub = root .. '/cmd/svc'
    vim.fn.mkdir(sub, 'p')

    local linter = go_linter_in(sub .. '/main.go')
    assert.equals(root, linter.cwd, 'golangci-lint must run from the go.mod root, even for a file in a subdir')
    -- copy, not mutation: nvim-lint stamps `name` on the table it is given
    assert.is_nil(lint_mod().linters.golangcilint.cwd, 'the shared builtin linter must stay pristine')
    vim.fn.delete(root, 'rf')
  end)

  it('accepts go.work as the module root marker', function()
    local root = tmpdir()
    vim.fn.writefile({ 'go 1.21' }, root .. '/go.work')
    local linter = go_linter_in(root .. '/main.go')
    assert.equals(root, linter.cwd, 'golangci-lint must run from the go.work root')
    vim.fn.delete(root, 'rf')
  end)

  it('does not use a foreign cwd or leak a previous buffer root', function()
    local root_a = tmpdir()
    vim.fn.writefile({ 'module a' }, root_a .. '/go.mod')
    local linter_a = go_linter_in(root_a .. '/main.go')
    assert.equals(root_a, linter_a.cwd)

    local plain = tmpdir()
    assert.is_nil(vim.fs.root(plain .. '/main.go', { 'go.mod', 'go.work' }), 'premise: plain dir has no module marker')
    local linter_b = go_linter_in(plain .. '/main.go')
    assert.is_nil(linter_b.cwd, 'a buffer with no module root must not carry a foreign cwd')
    assert.is_nil(lint_mod().linters.golangcilint.cwd, 'resolving one buffer must not mutate the shared builtin')

    vim.fn.delete(root_a, 'rf')
    vim.fn.delete(plain, 'rf')
  end)
end)
