-- LSP server smoke test: lua_ls must attach to a lua buffer.
-- Run with: nvim --headless -c 'lua require("plenary.busted").run("tests/test_lsp_servers.lua")' -c 'qa!'

describe('lsp servers', function()
  it('lua_ls attaches to lua buffers', function()
    -- Unsaved buffer inside the config dir so root-marker detection hits.
    vim.cmd('e ' .. vim.fn.stdpath('config') .. '/lsp_probe_tmp.lua')
    vim.wait(8000, function()
      return #vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' }) > 0
    end, 200)
    assert.is_true(#vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' }) > 0)
    vim.cmd('bdelete!')
  end)
end)
