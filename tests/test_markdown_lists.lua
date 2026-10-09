-- Markdown list behavior: auto-continue, renumber on o/O/Enter, shift-back on
-- empty-item delete. Each case drives REAL keys through feedkeys, because the
-- whole implementation is expr mappings whose return values decide the result.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_markdown_lists.lua")' -c 'qa!'

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
  }

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
