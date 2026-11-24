-- Keymap/autocmd behavioral tests (live state, not string matching).
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_keymaps_autocmds.lua")' -c 'qa!'

describe('keymaps/autocmds', function()
  it('hr mapping is buffer-local to http', function()
    vim.cmd 'enew'
    assert.are.equal('', vim.fn.maparg('<leader>hr', 'n'))
  end)
  it('hr mapping appears in http buffers', function()
    vim.cmd 'enew'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = 'http'
    local map = vim.fn.maparg('<leader>hr', 'n', false, true)
    assert.are.equal(1, map.buffer)
    vim.cmd 'bdelete!'
  end)
  it('CursorHold float helper tolerates lines without diagnostics', function()
    vim.cmd 'enew'
    local buf = vim.api.nvim_get_current_buf()
    assert.is_true(vim.tbl_isempty(vim.diagnostic.get(buf, { lnum = 0 })))
    -- Drive the diag_float state machine on a clean line: open_diag_float must
    -- bail out via its no-diagnostics guard rather than raising.
    local ok, err = pcall(vim.api.nvim_exec_autocmds, 'CursorMoved', { buffer = buf })
    assert.is_true(ok, tostring(err))
  end)
  it('closes a tracked diagnostic float when diagnostics disappear', function()
    vim.cmd 'enew'
    local buf = vim.api.nvim_get_current_buf()
    local ns = vim.api.nvim_create_namespace 'diag-float-regression'
    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'stale float' },
    })
    vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })
    local opened = vim.wait(500, function()
      local win = _G._diag_float_state and _G._diag_float_state.win
      return win ~= nil and vim.api.nvim_win_is_valid(win)
    end, 10)
    assert.is_true(opened, 'diagnostic float must open before diagnostics are reset')
    local win = _G._diag_float_state.win

    vim.diagnostic.reset(ns, buf)
    vim.wait(100, function() return false end)
    assert.is_false(vim.api.nvim_win_is_valid(win), 'diagnostic float must close without cursor movement')

    vim.diagnostic.reset(ns, buf)
    vim.cmd 'bwipeout!'
  end)
  it('no duplicate lhs in normal mode keymaps', function()
    local seen, dupes = {}, {}
    for _, m in ipairs(vim.api.nvim_get_keymap 'n') do
      if seen[m.lhs] then table.insert(dupes, m.lhs) end
      seen[m.lhs] = true
    end
    assert.are.same({}, dupes)
  end)
  it('<leader>ty opens the theme picker', function()
    local map = vim.fn.maparg('<leader>ty', 'n', false, true)
    assert.is_truthy(map.desc and map.desc:match 'heme', 'must map to the theme picker')
    assert.is_falsy(map.desc and map.desc:match 'Themery', 'must not map to Themery')
  end)
  it('z= spell fix mapping is registered', function() assert.is_truthy(vim.fn.maparg('z=', 'n') ~= '', 'z= must be overridden by spell_fix') end)
  it('mode-line restore does not error before ColorScheme re-snapshot', function()
    -- setup() must snapshot immediately; ModeChanged before the next ColorScheme
    -- used to call nvim_set_hl(0, 'LineNr', nil) and raise "Expected Lua table".
    require('custom.ui.theme').setup_mode_line_colors()
    local ok, err = pcall(vim.api.nvim_exec_autocmds, 'ModeChanged', { pattern = '*:*' })
    assert.is_true(ok, tostring(err))
  end)
end)
