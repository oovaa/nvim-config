-- Live preview for frontend work: :KiteHost start serves the project on
-- 127.0.0.1 and refreshes the browser on save (CSS hot-swaps). Servers stop
-- with nvim.
return {
  'selimacerbas/kitehost.nvim',
  cmd = { 'KiteHost' },
  keys = {
    { '<leader>hs', '<cmd>KiteHost start<cr>', desc = 'Start live preview' },
    { '<leader>hx', '<cmd>KiteHost stop<cr>', desc = 'Stop live preview' },
    { '<leader>ho', '<cmd>KiteHost open<cr>', desc = 'Open in browser' },
    { '<leader>ht', '<cmd>KiteHost toggle-live<cr>', desc = 'Toggle live reload' },
  },
  config = function() require('kitehost').setup() end,
}
