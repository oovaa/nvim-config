---@module 'config.markdown'
-- Markdown lists: auto-continue + Enter on empty exits (Google Docs).
-- ponytail: native dash continuation + explicit numbered increment/renumber; no plugin.

local M = {}

function M.setup()
  -- Markdown lists: auto-continue + Enter on empty exits (Google Docs).
  -- ponytail: native dash continuation + explicit numbered increment/renumber; no plugin.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    desc = 'Markdown list continue + empty list exits',
    group = vim.api.nvim_create_augroup('markdown-lists', { clear = true }),
    callback = function(args)
      vim.opt_local.formatoptions:append 'ron'
      -- Overwrite, not append: the runtime markdown ftplugin sets fb:-/fb:*/fb:+
      -- whose f flag means "leader on first line only, never repeat it". First
      -- match wins, so appended b:- entries would be shadowed and Enter/o would
      -- never continue the list.
      vim.opt_local.comments = { 'b:-', 'b:*', 'b:+', 'n:>' }
      -- ponytail: native r/n/o/O repeats dash markers but can't increment numbers
      -- (verified in clean nvim). Numbered items go through native keys (so
      -- insert mode/indent behave exactly like stock), then a scheduled renumber
      -- fixes same-indent followers (Google Docs style).
      local function item(l)
        local ind, n, d, tail = l:match '^(%s*)(%d+)([.)])(%s.*)$'
        if ind then return ind, tonumber(n), d, tail end
        ind, n, d = l:match '^(%s*)(%d+)([.)])$' -- bare `2.` at EOL
        if ind then return ind, tonumber(n), d, '' end
      end
      local function renumber_below(buf, start0, base, indent)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        local lines = vim.api.nvim_buf_get_lines(buf, start0, -1, false)
        local n, dirty = base, false
        for i, l in ipairs(lines) do
          local ind, _, d, tail = item(l)
          -- ponytail: deeper levels belong to a sublist (skip); a shallower
          -- item or non-item ends this level (stop). Length compare only.
          if not ind or #ind < #indent then break end
          if #ind == #indent then
            local want = ind .. n .. d .. tail
            if want ~= l then
              lines[i] = want
              dirty = true
            end
            n = n + 1
          end
        end
        if dirty then vim.api.nvim_buf_set_lines(buf, start0, -1, false, lines) end
      end
      vim.keymap.set('i', '<CR>', function()
        local buf = vim.api.nvim_get_current_buf()
        local row1 = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_get_current_line()
        local empty = line:match '^%s*[-*+]%s*$' or line:match '^%s*%d+[.)]%s*$' or line:match '^%s*[-*+]%s+%[.%]%s*$'
        if empty then
          local nind = item(line)
          if nind then
            -- Deleted a numbered item: followers shift back, continuing the
            -- same-indent number above (skipping deeper sublists) or
            -- restarting at 1.
            local base, ls = 1, vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            for i = row1 - 1, 1, -1 do
              local aind, anum = item(ls[i])
              if not aind or #aind < #nind then break end
              if #aind == #nind then
                base = anum + 1
                break
              end
            end
            vim.schedule(function() renumber_below(buf, row1, base, nind) end)
          end
          return '<C-U>'
        end
        local _, num, delim = item(line)
        if num then
          vim.schedule(function() renumber_below(buf, row1 + 1, num + 2, line:match '^(%s*)') end)
          return '<CR>' .. (num + 1) .. delim .. ' '
        end
        return '<CR>'
      end, { buffer = args.buf, expr = true, desc = 'Empty list item exits list' })
      vim.keymap.set('n', 'o', function()
        local _, num, delim = item(vim.api.nvim_get_current_line())
        if not num then return 'o' end
        local buf = vim.api.nvim_get_current_buf()
        local row1 = vim.api.nvim_win_get_cursor(0)[1]
        local indent = vim.api.nvim_get_current_line():match '^(%s*)'
        vim.schedule(function() renumber_below(buf, row1 + 1, num + 2, indent) end)
        return 'o' .. (num + 1) .. delim .. ' '
      end, { buffer = args.buf, expr = true, desc = 'Open numbered item below (followers bumped)' })
      vim.keymap.set('n', 'O', function()
        local _, num, delim = item(vim.api.nvim_get_current_line())
        if not num then return 'O' end
        local buf = vim.api.nvim_get_current_buf()
        local row1 = vim.api.nvim_win_get_cursor(0)[1]
        local indent = vim.api.nvim_get_current_line():match '^(%s*)'
        vim.schedule(function() renumber_below(buf, row1, num + 1, indent) end)
        return 'O' .. num .. delim .. ' '
      end, { buffer = args.buf, expr = true, desc = 'Open numbered item above (followers bumped)' })
    end,
  })
end

return M
