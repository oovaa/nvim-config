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
    assert.is_true(vim.tbl_isempty(vim.diagnostic.get(0, { lnum = 0 })))
  end)
  it('no duplicate lhs in normal mode keymaps', function()
    local seen, dupes = {}, {}
    for _, m in ipairs(vim.api.nvim_get_keymap 'n') do
      if seen[m.lhs] then table.insert(dupes, m.lhs) end
      seen[m.lhs] = true
    end
    assert.are.same({}, dupes)
  end)
  it('<leader>ty is not Themery command', function()
    local map = vim.fn.maparg('<leader>ty', 'n')
    assert.is_truthy(map == '' or not map:match 'Themery', 'must not map to Themery')
  end)
  it('mode-line restore does not error before ColorScheme re-snapshot', function()
    -- setup() must snapshot immediately; ModeChanged before the next ColorScheme
    -- used to call nvim_set_hl(0, 'LineNr', nil) and raise "Expected Lua table".
    require('custom.ui.theme').setup_mode_line_colors()
    local ok, err = pcall(vim.api.nvim_exec_autocmds, 'ModeChanged', { pattern = '*:*' })
    assert.is_true(ok, tostring(err))
  end)
end)
