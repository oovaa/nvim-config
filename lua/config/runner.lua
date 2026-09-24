---@module 'config.runner'
-- BUILTIN CODE RUNNER (replaces CRAG666/code_runner.nvim, zero loss via :terminal)
-- Split from init.lua. Required after lazy.nvim setup (see init.lua).

local runners = {
  javascript = 'bun',
  typescript = 'bun',
  javascriptreact = 'bun',
  typescriptreact = 'bun',
  python = 'python3 -u',
}
local function run_file()
  local ft = vim.bo.filetype
  local file = vim.fn.expand '%:p'
  if file == '' then vim.notify('No file to run', vim.log.levels.WARN) return end
  local cmd
  if runners[ft] then
    cmd = runners[ft] .. ' ' .. vim.fn.shellescape(file)
  elseif ft == 'cpp' then
    local out = '/tmp/' .. vim.fn.expand '%:t:r'
    cmd = string.format('g++ %s -o %s && %s', vim.fn.shellescape(file), vim.fn.shellescape(out), vim.fn.shellescape(out))
  elseif ft == 'c' then
    local out = '/tmp/' .. vim.fn.expand '%:t:r'
    cmd = string.format('gcc %s -o %s && %s', vim.fn.shellescape(file), vim.fn.shellescape(out), vim.fn.shellescape(out))
  else
    vim.notify('No runner for filetype: ' .. ft, vim.log.levels.WARN) return
  end
  vim.cmd('split | terminal ' .. cmd)
  vim.cmd 'wincmd J | resize 15'
  vim.cmd.startinsert()
end
vim.keymap.set('n', '<leader>R', run_file, { desc = '[R]un [C]ode' })
vim.keymap.set('n', '<leader>rf', run_file, { desc = '[R]un [F]ile' })
