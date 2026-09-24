-- lua/plugins/treesitter.lua — SECTION 6.8: SYNTAX HIGHLIGHTING
-- Plugins that provide syntax highlighting and code parsing.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- TREESITTER
  -- WHAT: Provides accurate, incremental syntax highlighting and text objects
  -- TO CHANGE: Install more parsers with `:TSInstall <language>`
  -- EFFECT: Better syntax highlighting than traditional regex-based highlighting
  --         Enables features like incremental selection, text objects
  -- LOADING: BufReadPost = loads when you open a file
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      -- main branch setup only takes install_dir; highlighting/indent come from vim.treesitter.start below
      require('nvim-treesitter').setup {}
      -- Parsers install on-demand via FileType autocmd below

      -- Enable treesitter highlighting via Neovim built-in APIs (main branch doesn't support old config)
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(args)
          -- ponytail: plugin/scratch buffers (snacks_notif, qf, help...) have
          -- filetypes with no parser; skip them so TSInstall never warns.
          if vim.bo[args.buf].buftype ~= '' then return end
          -- ponytail: skip treesitter on minified bundles / huge files (>200KB);
          -- the parser chokes on them. Legacy regex highlighting covers it.
          -- Raise/lower the size cap here if you want treesitter everywhere.
          local name = vim.api.nvim_buf_get_name(args.buf)
          local ok_stat, stat = pcall(vim.uv.fs_stat, name)
          if name:match '%.min%.' or (ok_stat and stat and stat.size > 200 * 1024) then return end
          local ft = vim.bo[args.buf].filetype
          if ft and ft ~= '' then
            -- ponytail: compound fts (yaml.docker-compose) have no own parser;
            -- TSInstall would error, so install/check the base language.
            local lang = ft:match '^[^.]+'
            local parser = vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'parser', lang .. '.so')
            if vim.uv.fs_stat(parser) == nil then
              pcall(vim.cmd, 'TSInstall ' .. lang)
            end
          end
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

   { 'windwp/nvim-ts-autotag', ft = { 'html', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'xml' }, config = function() require('nvim-ts-autotag').setup {} end },
}
