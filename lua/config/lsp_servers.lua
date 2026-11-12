---@module 'config.lsp_servers'
-- Static LSP server definitions + mason name mapping. Extracted from
-- lua/plugins/lsp.lua so the table is reusable/testable; lsp.lua still adds
-- the Python ladder winner and registers everything via vim.lsp.config.

-- Language servers managed by Mason (automatically installed via `:Mason`)
--  See `:help lsp-config` for information about keys and how to configure
---@type table<string, vim.lsp.Config>
local servers = {
  -- clangd = {},
  -- Go: gopls (fast, staticcheck + gofumpt). Mason installs it; Rust's
  -- rust-analyzer comes from rustup instead (see editing.lua).
  gopls = {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.mod', 'go.work', '.git' },
    settings = {
      gopls = {
        gofumpt = true,
        staticcheck = true,
        semanticTokens = true,
        codelenses = {
          generate = true,
          tidy = true,
          upgrade_dependency = true,
          test = true,
        },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          constantValues = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        analyses = {
          unusedparams = true,
          shadow = true,
        },
        directoryFilters = { '-.git', '-.vscode', '-.idea', '-node_modules' },
      },
    },
  },
  -- clangd: needs compile_commands.json (cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON,
  -- or `bear -- make`). --background-index keeps completions fast; clang-tidy
  -- runs via nvim-lint, not twice.
  clangd = {
    cmd = { 'clangd', '--background-index', '--completion-style=detailed' },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    root_markers = { 'compile_commands.json', '.clangd', 'compile_flags.txt', '.git' },
  },
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
  yamlls = {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml' },
  },
  -- html/css: markup and stylesheet intelligence via the vscode servers
  -- (tag/attribute + selector/property completion, validation, colors)
  html = {
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
  },
  cssls = {
    cmd = { 'vscode-css-language-server', '--stdio' },
    filetypes = { 'css', 'scss', 'less' },
  },
  -- emmet: expand abbreviations (div.card>p*3) via blink completions
  emmet_language_server = {
    cmd = { 'emmet-language-server', '--stdio' },
    filetypes = { 'html', 'css', 'scss', 'less', 'javascriptreact', 'typescriptreact' },
  },
  -- nginx: config files get diagnostics/completion; format via nginxfmt
  nginx_language_server = {
    -- stdio is the default transport; 0.9.0 rejects --stdio
    cmd = { 'nginx-language-server' },
    filetypes = { 'nginx' },
    root_markers = { 'nginx.conf', '.git' },
  },
  -- bashls: shell diagnostics/completion; binary already common on this host.
  bashls = {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'bash', 'zsh' },
    root_markers = { '.git' },
  },
  -- marksman: markdown navigation/links/diagnostics.
  marksman = {
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown', 'markdown.mdx' },
    root_markers = { '.marksman.toml', '.git' },
  },
  -- taplo: TOML schema/validation/formatting support.
  taplo = {
    cmd = { 'taplo', 'lsp', 'stdio' },
    filetypes = { 'toml' },
    root_markers = { 'taplo.toml', '.taplo.toml', 'Cargo.toml', 'pyproject.toml', '.git' },
  },
  -- tailwindcss: root-gated to avoid attaching outside Tailwind projects.
  tailwindcss = {
    cmd = { 'tailwindcss-language-server', '--stdio' },
    filetypes = { 'html', 'css', 'scss', 'less', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue', 'svelte', 'astro' },
    root_markers = {
      'tailwind.config.js',
      'tailwind.config.cjs',
      'tailwind.config.mjs',
      'tailwind.config.ts',
      'postcss.config.js',
      'postcss.config.cjs',
      'postcss.config.mjs',
      'postcss.config.ts',
    },
  },
  -- C/C++ LSP: clangd. Rust: rust-analyzer (rustup, not here).
  -- SQL: sqls — DB-aware completion/hover via `.sqls.yml`; without it,
  -- still provides syntax/diagnostics for .sql files.
  sqls = {
    cmd = { 'sqls' },
    filetypes = { 'sql', 'mysql', 'plsql' },
    root_markers = { '.sqls.yml', '.sqruff', '.git' },
  },
  -- Deferred (Phase 1.3, uncertain 0.12 config/Mason names in this env): svelte,
  -- astro, prisma (prismals/prisma-language-server), graphql — add when verified.
  -- Python LSP is selected below according to installed host tools:
  -- ty (fastest, Astral) -> pyrefly -> pyright/pyright-langserver.
  -- None of them are installed by Mason here because pyenv 3.15+ is not supported.
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

      if client.workspace_folders and client.workspace_folders[1] then
        local path = client.workspace_folders[1].name
        -- Only add the full runtime library inside this config dir or
        -- when a .luarc is present; outside, keep it minimal to avoid
        -- a full workspace scan on every lua file.
        local in_config = path == vim.fn.stdpath 'config'
        local has_luarc = vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')
        if not in_config and not has_luarc then
          client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            workspace = { checkThirdParty = false, library = {} },
          })
          return
        end
        if has_luarc then return end
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
  html = 'html-lsp',
  cssls = 'css-lsp',
  emmet_language_server = 'emmet-language-server',
  lua_ls = 'lua-language-server',
  yamlls = 'yaml-language-server',
  bashls = 'bash-language-server',
  tailwindcss = 'tailwindcss-language-server',
}

return {
  servers = servers,
  lsp_to_mason = lsp_to_mason,
}
