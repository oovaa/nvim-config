-- Phase 4: Polish Tests
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_polish.lua")' -c 'qa!'

describe('Phase 4: Polish', function()
  local init_path = vim.fn.stdpath 'config' .. '/init.lua'
  local autocmds_path = vim.fn.stdpath 'config' .. '/lua/config/autocmds.lua'
  local health_path = vim.fn.stdpath 'config' .. '/lua/config/health.lua'

  local function read(path) return table.concat(vim.fn.readfile(path), '\n') end

  it('single CursorHold handler in autocmds.lua (no duplicates)', function()
    local c = read(autocmds_path)
    local _, n = c:gsub("'CursorHold'", '')
    assert.equals(1, n, 'Expected exactly 1 CursorHold handler, got ' .. n)
    assert.is_truthy(c:match 'checktime', 'Merged handler should run checktime')
    assert.is_truthy(c:match 'open_float', 'Merged handler should show diagnostic float')
  end)

  it('conform skips large files', function()
    local c = read(init_path)
    local section = c:match 'format_after_save.-\n      end'
    assert.is_truthy(section, 'format_after_save should exist')
    assert.is_truthy(section:match 'large_file_mode', 'Should guard on large_file_mode')
  end)

  it('health module exists with check()', function()
    assert.equals(1, vim.fn.filereadable(health_path))
    local c = read(health_path)
    assert.is_truthy(c:match 'function M%.check')
    assert.is_truthy(c:match 'vim%.health%.start')
    -- Must load without errors
    assert.has_no.errors(function() require 'config.health' end)
    assert.is_function(require('config.health').check)
  end)

  it('StartupTime shows lazy profile', function()
    local c = read(init_path)
    assert.is_truthy(c:match "nvim_create_user_command%('StartupTime'", ':StartupTime should exist')
    assert.is_truthy(c:match 'lazy%.stats%(%)', ':StartupTime should print lazy.nvim stats()')
  end)

  it('treesitter skips scratch buffers (no TSInstall warning)', function()
    local c = read(init_path)
    assert.is_truthy(c:match 'treesitter%-start.-buftype', 'treesitter FileType handler should skip non-file buffers')
  end)
end)
