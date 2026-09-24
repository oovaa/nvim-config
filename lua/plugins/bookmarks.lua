-- lua/plugins/bookmarks.lua — SECTION 6.14: BOOKMARKS
-- Plugins for marking and navigating to important lines.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- TELESCOPE-VIM-BOOKMARKS
  -- WHAT: Toggle bookmarks and list them with Telescope
  -- TO CHANGE: Remove if you don't use bookmarks
  -- EFFECT: <leader>mt to toggle bookmark; <leader>mj/mk to jump between bookmarks
  --         <leader>mc to annotate; <leader>mb to list all bookmarks in Telescope
  -- LOADING: keys = only loads when you press the keybindings
  --          vim_bookmarks telescope extension loads lazily on <leader>mb
  {
    'tom-anders/telescope-vim-bookmarks.nvim',
    dependencies = { 'MattesGroeger/vim-bookmarks' },
    keys = {
      { '<leader>mt', '<cmd>BookmarkToggle<cr>', desc = '[B]ookmark [T]oggle' },
      { '<leader>mc', '<cmd>BookmarkAnnotate<cr>', desc = '[B]ookmark [A]nnotate' },
      { '<leader>mj', '<cmd>BookmarkNext<cr>', desc = '[B]ookmark [N]ext' },
      { '<leader>mk', '<cmd>BookmarkPrev<cr>', desc = '[B]ookmark [P]revious' },
      { '<leader>mb', function()
          require('telescope').load_extension('vim_bookmarks')
          vim.cmd('Telescope vim_bookmarks')
        end, desc = '[B]ookmark [L]ist' },
    },
  },
}
