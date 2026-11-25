-- Markdown list behavior: auto-continue, renumber on o/O/Enter, shift-back on
-- empty-item delete. Each case drives REAL keys through feedkeys, because the
-- whole implementation is expr mappings whose return values decide the result.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_markdown_lists.lua")' -c 'qa!'

local helpers = require 'tests.helpers'

describe('markdown lists', function()
  -- ponytail: renumbering runs in vim.schedule (synchronous buffer edits plus
  -- :startinsert from a mapping silently fail to enter insert mode), so every
  -- case waits for the queue to drain before asserting.
  local function keys(buf, lines, cur, seq)
    vim.cmd 'enew!'
    vim.bo[buf].filetype = 'markdown'
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, cur)
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(seq, true, false, true), 'x')
    vim.wait(150)
  end

  local cases = {
    { 'dash: enter continues', { '- foo' }, { 1, 5 }, 'A<CR>', { '- foo', '-' } },
    { 'dash: o repeats marker', { '- foo' }, { 1, 1 }, 'o', { '- foo', '-' } },
    { 'dash: empty item wipes in place', { '- ' }, { 1, 2 }, 'A<CR>', { '' }, 1 },
    { 'checkbox: empty item wipes in place', { '- [ ] ' }, { 1, 6 }, 'A<CR>', { '' }, 1 },
    { 'num: empty first shifts back', { '1. ', '2. b', '3. c' }, { 1, 3 }, 'A<CR>', { '', '1. b', '2. c' }, 1 },
    { 'num: empty middle shifts back', { '1. a', '2. ', '3. c' }, { 2, 3 }, 'A<CR>', { '1. a', '', '2. c' }, 2 },
    { 'num: empty skips sublists above', { '1. a', '  1. x', '2. ', '3. c' }, { 3, 3 }, 'A<CR>', { '1. a', '  1. x', '', '2. c' } },
    { 'num: enter continues and renumbers', { '1. a', '2. b', '3. c' }, { 2, 4 }, 'A<CR>', { '1. a', '2. b', '3. ', '4. c' } },
    { 'num: 9 rolls over to 10', { '9. foo' }, { 1, 6 }, 'A<CR>', { '9. foo', '10. ' } },
    { 'num: indent preserved', { '  3. foo' }, { 1, 9 }, 'A<CR>', { '  3. foo', '  4. ' } },
    { 'num: o on last appends', { '1. a', '2. b' }, { 2, 1 }, 'o', { '1. a', '2. b', '3. ' } },
    { 'num: o in middle renumbers below', { '1. a', '2. b', '3. c' }, { 2, 1 }, 'o', { '1. a', '2. b', '3. ', '4. c' } },
    { 'num: O on first renumbers below', { '1. a', '2. b' }, { 1, 1 }, 'O', { '1. ', '2. a', '3. b' } },
    { 'num: O in middle renumbers below', { '1. a', '2. b', '3. c' }, { 2, 1 }, 'O', { '1. a', '2. ', '3. b', '4. c' } },
    { 'num: ) delimiter kept', { '1) a', '2) b' }, { 1, 4 }, 'A<CR>', { '1) a', '2) ', '3) b' } },
    { 'nest: O on outer skips sublist', { '1. a', '  1. x', '  2. y', '2. b' }, { 1, 1 }, 'O', { '1. ', '2. a', '  1. x', '  2. y', '3. b' } },
    { 'nest: O on inner stops at outer', { '1. a', '  1. x', '  2. y', '2. b' }, { 2, 1 }, 'O', { '1. a', '  1. ', '  2. x', '  3. y', '2. b' } },
    { 'plain: O falls back to native', { 'hello' }, { 1, 1 }, 'O', { '', 'hello' } },
    { 'plain: enter untouched', { 'hello' }, { 1, 5 }, 'A<CR>', { 'hello', '' } },
    -- continuation spacing: a new item is always `indent + n + delim + ' '`,
    -- while renumbering rewrites only the number and copies each item's own
    -- tail verbatim, so wide/tab spacing survives an insert.
    { 'num: extra spacing kept, new item gets one space', { '1.   a', '2.   b' }, { 1, 6 }, 'A<CR>', { '1.   a', '2. ', '3.   b' } },
    { 'num: tab after marker kept', { '1.\ta', '2.\tb' }, { 1, 4 }, 'A<CR>', { '1.\ta', '2. ', '3.\tb' } },
    { 'nest: sublist enter keeps indent, one space', { '1. a', '  1.   x', '  2.   y' }, { 2, 9 }, 'A<CR>', { '1. a', '  1.   x', '  2. ', '  3.   y' } },
    { 'num: O above keeps each tail spacing', { '1.   a', '2.   b' }, { 1, 7 }, 'O', { '1. ', '2.   a', '3.   b' } },
  }

  it('markdown ftplugin overwrites comments with the b: leader flag', function()
    -- the leader spacing only repeats at all because of 'b:': the runtime
    -- markdown ftplugin's 'fb:-'/'fb:*'/'fb:+' carry the f flag ("leader only
    -- on the very first line"), so appending b:- entries would be shadowed and
    -- none of the cases above would continue the list.
    vim.cmd 'enew!'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = 'markdown'
    -- vim.bo returns the comma list as one string
    assert.same({ 'b:-', 'b:*', 'b:+', 'n:>' }, vim.split(vim.bo[buf].comments, ','))
    -- r = repeat leader on <CR>, o = open line with indent, n = keep the
    -- continuation line unindented
    local fo = vim.bo[buf].formatoptions
    for _, flag in ipairs { 'r', 'o', 'n' } do
      assert.is_truthy(fo:match(flag), ('formatoptions must carry %q (got %q)'):format(flag, fo))
    end
    vim.cmd 'bwipeout!'
  end)

  it('sets list options on the FileType buffer, not the current buffer', function()
    vim.cmd 'enew!'
    local current = vim.api.nvim_get_current_buf()
    local current_fo, current_comments = vim.bo[current].formatoptions, vim.bo[current].comments
    -- create a second buffer but leave `current` as the window's buffer; setting
    -- its filetype fires FileType for that buffer while it is not current.
    local target = vim.api.nvim_create_buf(true, true)
    vim.bo[target].filetype = 'markdown'
    assert.is_not.equals(target, vim.api.nvim_get_current_buf(), 'premise: target is not the current buffer')

    assert.same({ 'b:-', 'b:*', 'b:+', 'n:>' }, vim.split(vim.bo[target].comments, ','), 'comments land on the FileType buffer')
    local fo = vim.bo[target].formatoptions
    for _, flag in ipairs { 'r', 'o', 'n' } do
      assert.is_truthy(fo:match(flag), ('target formatoptions must carry %q (got %q)'):format(flag, fo))
    end
    assert.equals(current_fo, vim.bo[current].formatoptions, 'current buffer formatoptions untouched')
    assert.equals(current_comments, vim.bo[current].comments, 'current buffer comments untouched')
    vim.api.nvim_buf_delete(target, { force = true })
  end)

  for _, c in ipairs(cases) do
    local name, lines, cur, seq, want, want_row = c[1], c[2], c[3], c[4], c[5], c[6]
    it(name, function()
      vim.cmd 'enew!'
      local buf = vim.api.nvim_get_current_buf()
      keys(buf, lines, cur, seq)
      assert.same(want, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      if want_row then assert.same(want_row, vim.api.nvim_win_get_cursor(0)[1], 'cursor row') end
      vim.cmd 'bwipeout!'
    end)
  end
end)

describe('render-markdown size guard', function()
  local spec
  for _, s in ipairs(require 'plugins.appearance') do
    if s[1] == 'MeanderingProgrammer/render-markdown.nvim' then spec = s end
  end

  it('disables oversized markdown buffers by filetype, not by .md filename', function()
    assert.is_table(spec, 'render-markdown spec must be present')
    -- the plugin's own config owns the guard augroup; load it once so it cannot
    -- clear our instrumented copy when the first markdown buffer opens.
    pcall(function() require('lazy').load { plugins = { 'render-markdown.nvim' } } end)

    local dir = helpers.fixture_path 'render-guard'
    vim.fn.mkdir(dir, 'p')
    local big = string.rep('x', 200 * 1024 + 1)
    local files = { dir .. '/big.markdown', dir .. '/big.mdx', dir .. '/small.md', dir .. '/big.txt' }
    vim.fn.writefile({ big }, files[1])
    vim.fn.writefile({ big }, files[2])
    vim.fn.writefile({ '# small' }, files[3])
    vim.fn.writefile({ big }, files[4])

    local disabled = {}
    local saved = { package.loaded['render-markdown'], package.loaded['render-markdown.api'] }
    package.loaded['render-markdown'] = { setup = function() end }
    package.loaded['render-markdown.api'] = {
      buf_disable = function() disabled[vim.api.nvim_get_current_buf()] = true end,
    }
    local bufs = {}
    local ok, err = pcall(function()
      spec.config(nil, {})
      for i, path in ipairs(files) do
        vim.cmd('edit! ' .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        -- .mdx gets a compound filetype (markdown.mdx); the guard must match
        -- it without being forced to plain markdown.
        local want_ft = i == 2 and 'markdown.mdx' or (i == 4 and 'text' or 'markdown')
        if vim.bo[b].filetype ~= want_ft then vim.bo[b].filetype = want_ft end
        bufs[i] = b
      end
      assert.is_true(disabled[bufs[1]], 'oversized .markdown must be disabled')
      assert.is_true(disabled[bufs[2]], 'oversized .mdx must be disabled')
      assert.is_nil(disabled[bufs[3]], 'small .md must stay enabled')
      assert.is_nil(disabled[bufs[4]], 'oversized non-markdown buffer must stay enabled')
    end)
    package.loaded['render-markdown'] = saved[1]
    package.loaded['render-markdown.api'] = saved[2]
    for _, b in ipairs(bufs) do
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
    helpers.remove_fixture(dir)
    assert.is_true(ok, tostring(err))
  end)
end)
