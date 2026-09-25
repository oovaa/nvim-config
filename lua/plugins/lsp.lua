-- lua/plugins/lsp.lua — SECTION 6.3: LANGUAGE SERVER PROTOCOL (LSP)
-- LSP provides code intelligence: go-to-definition, find references,
-- autocompletion, diagnostics, and more.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- LSP + MASON (native vim.lsp — lspconfig plugin removed)
  -- WHAT: Mason auto-installs servers; vim.lsp.config defines them
  -- TO CHANGE: Add/remove servers in the `servers` table below
  -- EFFECT: Each server provides language-specific features (e.g., pyrefly for Python)
  --         Servers are loaded on-demand via FileType autocmds for performance
  -- PERFORMANCE: FileType autocmds save ~50-150ms startup time
  {
    'mason-org/mason.nvim',
    -- Load on FileType (not at startup) to keep the LSP stack out of
    -- the startup path; FileType autocmds below enable servers on demand.
    event = 'FileType',
    ---@module 'mason.settings'
    ---@type MasonSettings
    ---@diagnostic disable-next-line: missing-fields
    opts = {},
    dependencies = {
      -- Auto-installs tools listed in ensure_installed
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Shows LSP loading progress in the bottom-right corner
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      -- NOTE: opts = {} above is passed here, NOT auto-setup (a spec with
      -- an explicit config never gets lazy's automatic require('mason').setup).
      -- Call it ourselves: setup prepends Mason's bin/ to PATH so servers resolve.
      require('mason').setup {}
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Hover: show function signature, args, return type, docs
          map('K', vim.lsp.buf.hover, '[H]over')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          -- ponytail: both code-action keys go through actions-preview (diff preview, telescope UI)
          local preview_action = function() require('actions-preview').code_actions() end
          map('gra', preview_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('<leader>ca', preview_action, '[C]ode [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end

          -- Snacks picker owns LSP nav now (telescope kept cmd-only for
          -- vim_bookmarks + ui-select). snacks is VeryLazy so loaded by
          -- attach time in practice; lazy.load covers cold paths.
          local function spick(fn)
            return function()
              require('lazy').load { plugins = { 'snacks.nvim' } }
              fn(require('snacks').picker)
            end
          end
          vim.keymap.set('n', 'grr', spick(function(p) p.lsp_references() end), { buffer = event.buf, desc = '[G]oto [R]eferences' })
          vim.keymap.set('n', 'gri', spick(function(p) p.lsp_implementations() end), { buffer = event.buf, desc = '[G]oto [I]mplementation' })
          vim.keymap.set('n', 'grd', spick(function(p) p.lsp_definitions() end), { buffer = event.buf, desc = '[G]oto [D]efinition' })
          vim.keymap.set('n', 'gO', spick(function(p) p.lsp_symbols() end), { buffer = event.buf, desc = 'Open Document Symbols' })
          vim.keymap.set('n', 'gW', spick(function(p) p.lsp_workspace_symbols() end), { buffer = event.buf, desc = 'Open Workspace Symbols' })
          vim.keymap.set('n', 'grt', spick(function(p) p.lsp_type_definitions() end), { buffer = event.buf, desc = '[G]oto [T]ype Definition' })
        end,
      })

      -- Language servers managed by Mason (automatically installed via `:Mason`)
      --  See `:help lsp-config` for information about keys and how to configure
      ---@type table<string, vim.lsp.Config>
      local servers = {
        -- clangd = {},
        docker_compose_language_service = {
          cmd = { 'docker-compose-langserver', '--stdio' },
          filetypes = { 'yaml.docker-compose' },
          root_markers = { 'docker-compose.yaml', 'docker-compose.yml', 'compose.yaml', 'compose.yml' },
        },
        dockerls = {
          cmd = { 'docker-langserver', '--stdio' },
          filetypes = { 'dockerfile' },
          root_markers = { 'Dockerfile' },
        },
        -- oxlint handles JS/TS lint via nvim-lint (no eslint LSP daemon)
        -- jsonls: syntax errors + schema validation for json/jsonc
        -- (answers "is my json broken?" with red squiggles)
        jsonls = {
          cmd = { 'vscode-json-language-server', '--stdio' },
          filetypes = { 'json', 'jsonc' },
        },
        -- nginx: config files get diagnostics/completion; format via nginxfmt
        nginx_language_server = {
          -- stdio is the default transport; 0.9.0 rejects --stdio
          cmd = { 'nginx-language-server' },
          filetypes = { 'nginx' },
          root_markers = { 'nginx.conf', '.git' },
        },
        -- gopls = {},
        pyrefly = {
          cmd = { 'pyrefly', 'lsp' },
          settings = { python = { pyrefly = { typeCheckingMode = 'default' } } },
        }, -- LSP: fast type-checking for Python (installed via brew)
        -- rust_analyzer = {},
        --
        -- Some languages (like typescript) have enhanced LSP plugins:
        --    https://github.com/yioneko/nvim-vtsls (faster TS LSP)
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},

        -- Special Lua Config, as recommended by neovim help docs
        lua_ls = {
          cmd = { 'lua-language-server' },
          filetypes = { 'lua' },
          root_markers = {
            '.emmyrc.json',
            '.luarc.json',
            '.luarc.jsonc',
            '.luacheckrc',
            '.stylua.toml',
            'stylua.toml',
            'selene.toml',
            'selene.yml',
            '.git',
          },
          on_init = function(client)
            client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
                --  See https://github.com/neovim/nvim-lspconfig/issues/3189
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          ---@type vim.lsp.Config
          settings = {
            Lua = {
              format = { enable = false }, -- Disable formatting (formatting is done by stylua)
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      -- NOTE: pyrefly is installed globally via brew (not managed by Mason); skip it.
      -- nginx_language_server via `uv tool install` (pypi pkg requires python <3.14,
      -- host only has 3.14 → Mason install fails; binary lives in ~/.local/bin); skip it.
      -- ponytail: mason package names use dashes; lspconfig uses underscores — map them
      local lsp_to_mason = {
        docker_compose_language_service = 'docker-compose-language-service',
        dockerls = 'dockerfile-language-server',
        jsonls = 'json-lsp',
        lua_ls = 'lua-language-server',
      }
      local ensure_installed = {}
      for name in pairs(servers) do
        if name ~= 'pyrefly' and name ~= 'nginx_language_server' then table.insert(ensure_installed, lsp_to_mason[name] or name) end
      end
      vim.list_extend(ensure_installed, {
        'prettier', -- unified JS/TS/JSON/HTML/CSS formatter used by conform
        'prettierd', -- daemon prettier: first in conform chain, ms per save
        'stylua', -- lua formatter (conform needs it; health checks it)
        'ruff', -- python lint+format backend for conform + nvim-lint
        'oxlint', -- fast Rust JS/TS linter used by nvim-lint
        -- ponytail: debugpy NOT here — system python3 lacks ensurepip
        -- (needs `sudo apt install python3.12-venv`), so mason can't build
        -- its venv and would retry+fail on every FileType. Installed manually
        -- into mason/packages/debugpy/venv (pip install debugpy); dap-python
        -- picks it up via debugpy_path below. Re-add after apt fix.
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Configure servers but don't enable them globally
      -- Instead, enable on-demand via FileType autocmds for better startup performance
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      -- Only enable LSP servers when their filetype is opened
      local lsp_filetypes = {
        pyrefly = { 'python' },
        lua_ls = { 'lua' },
        jsonls = { 'json', 'jsonc' },
        docker_compose_language_service = { 'yaml.docker-compose' },
        dockerls = { 'dockerfile' },
        nginx_language_server = { 'nginx' },
      }
      for server, filetypes in pairs(lsp_filetypes) do
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('lsp-on-demand-' .. server, { clear = true }),
          pattern = filetypes,
          once = true,
          callback = function() vim.lsp.enable(server) end,
        })
      end
    end,
  },
}
