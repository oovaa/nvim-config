-- lua/plugins/appearance.lua — SECTION 6.15: VISUAL ENHANCEMENTS
-- Plugins that enhance the visual appearance of code.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- RENDER-MARKDOWN
  -- WHAT: Better markdown rendering with icons, boxes, and formatting
  -- TO CHANGE: Remove if you prefer plain markdown
  -- EFFECT: Markdown headings get icons, code blocks get boxes,
  --         checkboxes get rendered as [ ] and [x]
  -- LOADING: ft = only loads for markdown files
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  -- COLORIZER
  -- WHAT: Highlights hex (#ff00aa) and named colors inline
  -- TO CHANGE: <leader>uc to toggle
  -- EFFECT: Color swatches appear behind color codes in any buffer
  -- LOADING: ft = only loads for color-relevant filetypes; <leader>uc /
  --         :ColorizerToggle loads it on demand elsewhere. (ft uses FileType
  --         so the startup file is covered, unlike BufRead.)
  {
    -- Maintained drop-in fork of norcalli/nvim-colorizer.lua (the original is
    -- unmaintained and uses vim.tbl_flatten, removed in Nvim 0.13).
    'catgoose/nvim-colorizer.lua',
    ft = { 'css', 'html', 'javascript', 'typescript', 'lua', 'vim', 'toml' },
    cmd = 'ColorizerToggle',
    config = function()
      require('colorizer').setup({ '*' }, {
        RGB = true,
        RRGGBB = true,
        names = true,
        css = true,
      })
      -- ponytail: 200KB guard mirrors treesitter; detach only, toggle still works per buffer.
      vim.api.nvim_create_autocmd('BufWinEnter', {
        group = vim.api.nvim_create_augroup('colorizer-size-guard', { clear = true }),
        callback = function(ev)
          local name = vim.api.nvim_buf_get_name(ev.buf)
          -- getfsize returns -1/-2 on error; fs_stat nil-check is exact.
          local ok, st = pcall(vim.uv.fs_stat, name)
          if name ~= '' and ok and st and st.size > 200 * 1024 then
            pcall(vim.cmd, 'ColorizerDetachFromBuffer')
          end
        end,
      })
    end,
  },

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}
