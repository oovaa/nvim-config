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

      local function parser_path(lang) return vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'parser', lang .. '.so') end

      -- Bootstrap the parsers for the filetypes this config is actually used
      -- with, so the FileType autocmd below usually finds them already built.
      -- Scheduled after startup so opening one of these 16 languages never
      -- blocks on a compile; a language OUTSIDE the list still compiles
      -- synchronously on first open via the FileType fallback below. pcall'd so
      -- a missing toolchain is a debug line and not an error, and attempted at
      -- most once per session (vim.g survives <leader>ur; the table only ever gains
      -- one key per language, so it cannot grow per reload).
      -- ponytail: no executable detection here — nvim-treesitter compiles every
      -- grammar with the tree-sitter CLI, and TSInstall's pcall covers its
      -- absence; :checkhealth config reports a missing CLI.
      -- shortcut: one flat install attempt per language per session, with no
      -- toolchain probe — check `tree-sitter` per language when you need
      -- preconditions. Headless is skipped: nothing to highlight to save time.
      vim.g.treesitter_bootstrap = vim.g.treesitter_bootstrap or {}
      vim.defer_fn(function()
        if #vim.api.nvim_list_uis() == 0 then return end
        -- Skip the whole bootstrap when the tree-sitter CLI is missing: every
        -- TSInstall would just spawn-fail and waste startup work.
        if vim.fn.executable 'tree-sitter' == 0 then return end
        local marks, todo = vim.g.treesitter_bootstrap or {}, {}
        for _, lang in ipairs {
          'lua',
          'vim',
          'javascript',
          'typescript',
          'tsx',
          'html',
          'css',
          'python',
          'json',
          'yaml',
          'markdown',
          'bash',
          'c',
          'cpp',
          'rust',
          'go',
        } do
          if not marks[lang] and vim.uv.fs_stat(parser_path(lang)) == nil then
            marks[lang] = true -- at most one attempt per session
            table.insert(todo, lang)
          end
        end
        -- vim.g hands out a copy of a dict global, so assign the marks back as
        -- a whole table: `vim.g.treesitter_bootstrap[lang] = true` is a no-op.
        vim.g.treesitter_bootstrap = marks
        if #todo > 0 then pcall(vim.cmd, 'TSInstall ' .. table.concat(todo, ' ')) end
      end, 250)

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
            -- same once-per-session state as the bootstrap above, so a language
            -- whose build failed is not retried on every buffer of that type
            local marks = vim.g.treesitter_bootstrap or {}
            if vim.fn.executable 'tree-sitter' == 1 and not marks[lang] and vim.uv.fs_stat(parser_path(lang)) == nil then
              marks[lang] = true
              vim.g.treesitter_bootstrap = marks -- whole table, see the note above
              pcall(vim.cmd, 'TSInstall ' .. lang)
            end
          end
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  {
    'windwp/nvim-ts-autotag',
    ft = { 'html', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'xml' },
    config = function() require('nvim-ts-autotag').setup {} end,
  },
}
