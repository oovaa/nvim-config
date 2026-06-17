-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec
return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
  },

  {
    "benlubas/molten-nvim",
    version = "^1",
    build = ":UpdateRemotePlugins",
    dependencies = { "3rd/image.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_use_virtual_text = true
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_image_provider = "image.nvim"
    end,
    keys = {
      { "<leader>mi", "<cmd>MoltenInit<cr>", desc = "[M]olten [I]nit" },
      { "<leader>ml", "<cmd>MoltenEvaluateLine<cr>", desc = "[M]olten [L]ine" },
      { "<leader>mv", "<cmd>MoltenEvaluateVisual<cr>", mode = "v", desc = "[M]olten [V]isual" },
      { "<leader>mr", "<cmd>MoltenReevaluateCell<cr>", desc = "[M]olten [R]e-evaluate" },
      { "<leader>mh", "<cmd>MoltenHide<cr>", desc = "[M]olten [H]ide output" },
      { "<leader>md", "<cmd>MoltenDelete<cr>", desc = "[M]olten [D]elete cell" },
      { "<leader>mn", "<cmd>MoltenNext<cr>", desc = "[M]olten [N]ext cell" },
      { "<leader>mp", "<cmd>MoltenPrev<cr>", desc = "[M]olten [P]rev cell" },
      { "<leader>mo", "<cmd>MoltenOpenInBrowser<cr>", desc = "[M]olten [O]pen in browser" },
    },
  },

  {
    "3rd/image.nvim",
    build = false,
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
        html = { enabled = false },
        css = { enabled = false },
      },
      max_width = nil,
      max_height = nil,
      max_width_window_width = nil,
      max_height_window_height = nil,
      window_overlap_clear_enabled = false,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_history" },
      editor_only_render_when_focused = true,
      tmux_show_only_in_active_window = false,
      hijack_filetype_patterns = { "rendermarkdown.*" },
    },
  },
}
