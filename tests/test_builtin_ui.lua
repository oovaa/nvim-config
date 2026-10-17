-- Builtin UI behavior (lua/custom/ui/): which buffer the tabline marks current,
-- and that the saved colorscheme comes back. Both are silent when they break.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_builtin_ui.lua")" -c 'qa!'

describe('builtin tabline', function()
  local tabline = require 'custom.ui.tabline'

  --- Payload of one buffer's entry in a rendered tabline. An entry is
  --- `%<bufnr>@_builtin_tabclick@<hl> <idx> <name>...%X%*`; slicing one buffer
  --- out beats matching the whole escape soup, which is not a contract.
  local function entry(s, buf) return s:match('%%' .. buf .. '@_builtin_tabclick@(.-)%%X') end

  it('marks the current buffer selected and follows a switch or a click', function()
    assert.is_function(_G._builtin_tabline, 'premise: tabline must be wired by custom.ui.init')
    assert.is_function(_G._builtin_tabclick)
    tabline.setup_bufferline()

    -- real files in /tmp, not scratch buffers: a scratch buffer is unlisted and
    -- the tabline only walks buflisted ones.
    local dir = ('/tmp/nvim-tabline-test-%d'):format(vim.uv.hrtime())
    vim.fn.mkdir(dir, 'p')
    vim.fn.writefile({ '# alpha' }, dir .. '/alpha.md')
    vim.fn.writefile({ '# beta' }, dir .. '/beta.md')
    vim.cmd.edit(vim.fn.fnameescape(dir .. '/alpha.md'))
    local alpha = vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fn.fnameescape(dir .. '/beta.md'))
    local beta = vim.api.nvim_get_current_buf()

    local s = _G._builtin_tabline()
    assert.is_truthy(entry(s, beta), 'beta must have an entry')
    assert.is_truthy(entry(s, beta):match '%#TabLineSel#', 'the current buffer is the selected one')
    assert.is_truthy(entry(s, alpha):match '%#TabLine#', 'other buffers use the plain group')
    assert.is_nil(entry(s, alpha):match '%#TabLineSel#', 'only one entry may be selected')

    -- a modified buffer gets its own dot, in the Sel variant while current
    vim.api.nvim_buf_set_lines(alpha, 0, -1, false, { '# alpha edited' })
    s = _G._builtin_tabline()
    assert.is_truthy(entry(s, alpha):match '●', 'a modified buffer is dotted')
    assert.is_truthy(entry(s, alpha):match '%#TabLineMod#', 'unselected dot uses TabLineMod')

    vim.api.nvim_set_current_buf(alpha)
    s = _G._builtin_tabline()
    assert.is_truthy(entry(s, alpha):match '%#TabLineSel#', 'the mark follows the current buffer')
    assert.is_truthy(entry(s, alpha):match '%#TabLineModSel#', 'the current dot uses TabLineModSel')
    assert.is_truthy(entry(s, beta):match '%#TabLine#', 'the old current buffer loses the mark')

    _G._builtin_tabclick(beta, 1, 'l')
    assert.equals(beta, vim.api.nvim_get_current_buf(), 'left click switches to that buffer')
    assert.is_truthy(entry(_G._builtin_tabline(), beta):match '%#TabLineSel#', 'the mark follows the click')
    _G._builtin_tabclick(alpha, 1, 'r')
    assert.equals(beta, vim.api.nvim_get_current_buf(), 'a right click must not switch')

    pcall(vim.api.nvim_buf_delete, alpha, { force = true })
    pcall(vim.api.nvim_buf_delete, beta, { force = true })
    vim.fn.delete(dir, 'rf')
  end)
end)

describe('theme restore', function()
  local theme = require 'custom.ui.theme'

  it('puts the saved colorscheme back over whatever is active', function()
    -- both schemes are core runtime ones whose colors_name is their own name
    -- (tokyonight would report 'tokyonight-moon' and make the assert read the
    -- plugin instead of the restore).
    for _, name in ipairs { 'default', 'habamax' } do
      assert.is_true(pcall(vim.cmd.colorscheme, name), name .. ' must be loadable')
    end
    local original_scheme, original_saved = vim.g.colors_name, theme.get_saved()

    local ok, err = pcall(function()
      vim.cmd.colorscheme 'habamax'
      -- what a fresh session finds: theme.txt written by the previous one
      theme.save 'default'
      theme.restore()
      assert.equals('default', vim.g.colors_name, 'restore() must put the saved scheme back')
    end)

    -- ThemePersistence writes on every switch, so undo the scheme first and the
    -- file second, or the cleanup leaves this host's theme changed.
    if original_scheme then pcall(vim.cmd.colorscheme, original_scheme) end
    if original_saved then
      theme.save(original_saved)
    else
      vim.fn.delete(theme.theme_file())
    end
    assert.is_truthy(ok, tostring(err))
  end)
end)

