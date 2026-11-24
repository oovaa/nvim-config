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
    event = { 'FileType', 'VimEnter' },
    ---@module 'mason.settings'
    ---@type MasonSettings
    ---@diagnostic disable-next-line: missing-fields
    opts = {},
    dependencies = {
      -- Auto-installs tools listed in ensure_installed
      'WhoIsSethDaniel/mason-tool-installer.nvim',
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
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = true })
      local detach_augroup = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true })
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

          -- Rename the variable under your cursor (live preview via inc-rename when available).
          --  Most Language Servers support renaming across files, etc.
          map('grn', function()
            pcall(require('lazy').load, { plugins = { 'inc-rename.nvim' } })
            if vim.fn.exists ':IncRename' == 2 then
              vim.api.nvim_feedkeys(':IncRename ' .. vim.fn.expand '<cword>', 'n', false)
            else
              vim.lsp.buf.rename()
            end
          end, '[R]e[n]ame')

          -- Hover: show function signature, args, return type, docs
          map('K', vim.lsp.buf.hover, '[H]over')
          -- Signature help fallback (blink signature is primary).
          vim.keymap.set({ 'n', 'i' }, '<C-s>', vim.lsp.buf.signature_help, { buffer = event.buf, desc = 'LSP: Signature help' })

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          -- ponytail: both code-action keys go through actions-preview (diff preview, snacks UI)
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
            -- Clear any stale highlight autocmds for this buffer before re-adding,
            -- so a re-attach (no intervening detach) cannot stack duplicates.
            vim.api.nvim_clear_autocmds { group = highlight_augroup, buffer = event.buf }
            -- Opt-in at rest (vim.g.lsp_document_highlight, default off) to avoid
            -- a documentHighlight request to the server on every CursorHold.
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = function()
                if not vim.g.lsp_document_highlight then return end
                vim.lsp.buf.document_highlight()
              end,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
          end

          -- Inlay hints: auto-enable when supported (skip large files), keep toggle.
          if client and client:supports_method('textDocument/inlayHint', event.buf) and vim.lsp.inlay_hint and not vim.b[event.buf].large_file_mode then
            vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
            map(
              '<leader>th',
              function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf }) end,
              '[T]oggle Inlay [H]ints'
            )
          elseif client and client:supports_method('textDocument/inlayHint', event.buf) and vim.lsp.inlay_hint then
            -- Large file: don't auto-enable, but keep a buffer-local toggle so
            -- the key never flips hints globally (enable() with no filter does).
            map(
              '<leader>th',
              function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf }) end,
              '[T]oggle Inlay [H]ints'
            )
          end

          -- Codelens: auto-enable when supported (skip large files). Built-in
          -- nvim_buf_attach on_lines handler refreshes on edits, so no explicit
          -- refresh autocmd is needed (enable(true,...) is a no-op once enabled).
          -- CodeLens needs a real textDocument URI. Unnamed scratch buffers have
          -- none, and enabling it there lets a late refresh hit a wiped buffer.
          if
            client
            and client:supports_method('textDocument/codeLens', event.buf)
            and vim.lsp.codelens
            and not vim.b[event.buf].large_file_mode
            and vim.api.nvim_buf_get_name(event.buf) ~= ''
          then
            pcall(vim.lsp.codelens.enable, true, { bufnr = event.buf })
          end

          -- Snacks picker owns LSP nav now. snacks is VeryLazy so loaded by
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

      vim.api.nvim_create_autocmd('LspDetach', {
        group = detach_augroup,
        callback = function(event)
          for _, attached in ipairs(vim.lsp.get_clients { bufnr = event.buf }) do
            if attached.id ~= event.data.client_id and attached:supports_method('textDocument/documentHighlight', event.buf) then return end
          end
          vim.api.nvim_buf_call(event.buf, vim.lsp.buf.clear_references)
          vim.api.nvim_clear_autocmds { group = highlight_augroup, buffer = event.buf }
        end,
      })

      vim.api.nvim_create_autocmd('BufWipeout', {
        desc = 'Disable CodeLens before buffer invalidation',
        group = vim.api.nvim_create_augroup('kickstart-lsp-codelens-cleanup', { clear = true }),
        callback = function(ev) pcall(vim.lsp.codelens.enable, false, { bufnr = ev.buf }) end,
      })

      -- Language servers managed by Mason (automatically installed via `:Mason`)
      -- Static definitions live in config.lsp_servers; mutated below for Python.
      local lsp_servers = require 'config.lsp_servers'
      local servers = lsp_servers.servers
      local lsp_to_mason = lsp_servers.lsp_to_mason

      local ensure_installed = {}
      -- Go-based tools (gopls, sqls, gofumpt, goimports, delve) are installed by
      -- Mason via `go install`/`go build`, so they can never succeed without a
      -- Go toolchain on PATH. Skip them instead of retrying every session
      -- (mason-tool-installer has no failure memory and re-runs run_on_start).
      local go_available = vim.fn.executable 'go' == 1
      for name in pairs(servers) do
        if name ~= 'pyrefly' and name ~= 'nginx_language_server' then
          if (name == 'gopls' or name == 'sqls') and not go_available then
            -- skip: needs `go` on PATH (see AGENTS.md trap 14)
          else
            table.insert(ensure_installed, lsp_to_mason[name] or name)
          end
        end
      end
      vim.list_extend(ensure_installed, {
        'prettier', -- unified JS/TS/JSON/HTML/CSS formatter used by conform
        'stylua', -- lua formatter (conform needs it; health checks it)
        'ruff', -- python lint+format backend for conform + nvim-lint
        'oxlint', -- fast Rust JS/TS linter used by nvim-lint
        -- vtsls: Mason-managed TS LSP; clean machines get it without a manual
        -- bun/npm install. Needs node on PATH at runtime.
        'vtsls',
        -- biome: leads the JS/TS format + lint chain inside a repo that has its
        -- own biome.json (config.health.biome_root — ~/biome.json does not count).
        -- Also in mason so a GUI-launched nvim finds it — mason/bin is what
        -- setup prepends to PATH, and a bun/npm global is only on PATH via
        -- .zshrc. Standalone Rust binary, so no python/ensurepip wall.
        'biome',
        -- Go: LSP + formatters + linter + debugger
        -- golangci-lint is a prebuilt binary (no Go needed); gofumpt/goimports/
        -- delve are added conditionally below only when `go` is on PATH.
        'golangci-lint',
        -- C/C++: LSP + formatter + linter + debugger (codelldb shared with Rust)
        'clangd',
        'clang-format',
        'clang-tidy',
        'codelldb',
        -- SQL: LSP + fast Rust linter/fixer
        -- sqls is added by the Go-gated loop above (needs `go` on PATH).
        'sqruff',
        -- Shell/Markdown/TOML: LSPs (+ shfmt formatter). marksman/taplo may need
        -- mason install on clean machines; bash-language-server often already present.
        'marksman',
        'taplo',
        'shfmt',
        -- Java: debug adapter + test runner + formatter (auto-installed).
        -- jdtls itself is NOT auto-installed: it needs JDK 21+ on PATH AND
        -- network access to download.eclipse.org, which returns 403 in some
        -- environments. Added conditionally below when `java` is on PATH.
        'java-debug-adapter',
        'java-test',
        'google-java-format',
        -- React/TS: debugger (test runner lives in plugins/qol.lua)
        'js-debug-adapter',
        -- ponytail: nginxfmt (nginx) is NOT here. It is a python package and
        -- this box's python3 has no ensurepip, so mason fails to build its venv
        -- on every FileType — same wall as debugpy below. `pip install
        -- nginx-config-formatter` puts it on PATH instead, which conform picks
        -- up. Re-add 'nginx-config-formatter' here after `sudo apt install
        -- python3.12-venv`.
        -- ponytail: debugpy NOT here — system python3 lacks ensurepip
        -- (needs `sudo apt install python3.12-venv`), so mason can't build
        -- its venv and would retry+fail on every FileType. Installed manually
        -- into mason/packages/debugpy/venv (pip install debugpy); dap-python
        -- uses the resulting mason/bin/debugpy-adapter. Re-add after apt fix.
      })
      -- Go toolchain-gated installs: mason builds these with `go install`, so
      -- they only succeed when `go` is on PATH. Adding them unconditionally
      -- made mason-tool-installer retry (and fail) them on every startup.
      if go_available then vim.list_extend(ensure_installed, { 'gofumpt', 'goimports', 'delve' }) end

      -- jdtls: NOT auto-installed. Needs JDK 21+ on PATH AND network to
      -- download.eclipse.org, which returns 403 in some environments (incl.
      -- this sandbox). Auto-installing there spams mason errors. Run
      -- `:MasonInstall jdtls` manually when network allows; editing.lua
      -- notifies and skips gracefully if it isn't installed.

      -- Defer Mason's ensure_installed so opening a file never blocks on
      -- network/package installs. Runs once, shortly after startup.
      vim.defer_fn(function()
        if vim.g.nvim_disable_mason then return end
        if #vim.api.nvim_list_uis() == 0 then return end -- headless
        if vim.fn.has 'gui_running' == 0 and not (vim.env.TERM and #vim.env.TERM > 0) then return end
        -- debounce_hours stops failed Go builds (delve/sqls) from retrying on
        -- every startup: a timestamp is written before install, so once tried
        -- it won't spam again for 24h. Install manually with :MasonInstall if
        -- the first attempt was aborted by closing nvim or a transient DNS error.
        require('mason-tool-installer').setup { ensure_installed = ensure_installed, debounce_hours = 24 }
      end, 250)

      -- Choose the fastest Python LSP host tools can provide; if none are
      -- available, Python simply has no LSP attach until one is installed.
      -- Only start LSP servers when their filetype is opened
      local lsp_filetypes = {
        lua_ls = { 'lua' },
        gopls = { 'go', 'gomod', 'gowork', 'gotmpl' },
        clangd = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
        sqls = { 'sql', 'mysql', 'plsql' },
        jsonls = { 'json', 'jsonc' },
        yamlls = { 'yaml' },
        html = { 'html' },
        cssls = { 'css', 'scss', 'less' },
        emmet_language_server = { 'html', 'css', 'scss', 'less', 'javascriptreact', 'typescriptreact' },
        docker_compose_language_service = { 'yaml.docker-compose' },
        dockerls = { 'dockerfile' },
        nginx_language_server = { 'nginx' },
        bashls = { 'sh', 'bash', 'zsh' },
        marksman = { 'markdown', 'markdown.mdx' },
        taplo = { 'toml' },
        tailwindcss = { 'html', 'css', 'scss', 'less', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue', 'svelte', 'astro' },
      }

      if not go_available then
        servers.gopls = nil
        servers.sqls = nil
        lsp_filetypes.gopls = nil
        lsp_filetypes.sqls = nil
      end

      -- Add the selected Python LSP without making it a required Mason install.
      -- The ladder itself (which binary wins) lives in config/python_lsp.lua so
      -- tests/test_python_tools.lua can drive it without this whole spec.
      local python_server = require('config.python_lsp').resolve()
      if python_server then
        servers[python_server.name] = {
          cmd = python_server.cmd,
          filetypes = { 'python' },
          root_markers = { 'pyproject.toml', 'setup.cfg', 'requirements.txt', 'setup.py', '.git' },
          settings = python_server.settings,
        }
        lsp_filetypes[python_server.name] = { 'python' }
      end

      -- Keep pyrefly registered for stress/tool visibility even when the
      -- host selects another Python LSP or no binary is installed, but only
      -- auto-enable it when it is the ladder winner (prevents double-attach
      -- when ty+pyrefly coexist). Reuse the resolver result above.
      local py_winner_name = python_server and python_server.name or nil
      servers.pyrefly = servers.pyrefly
        or {
          cmd = { 'pyrefly', 'lsp' },
          filetypes = { 'python' },
          root_markers = { 'pyproject.toml', 'setup.cfg', 'requirements.txt', 'setup.py', '.git' },
          settings = { python = { pyrefly = { typeCheckingMode = 'default' } } },
        }
      if py_winner_name == 'pyrefly' then lsp_filetypes.pyrefly = lsp_filetypes.pyrefly or { 'python' } end

      -- Register every server AFTER the resolver above has added the python
      -- winner: looking up a name with no config is a silent no-op, so
      -- registering first meant a ty-only host got no python LSP at all.
      -- Neovim's built-in client capabilities already include snippet support;
      -- requiring Blink here would defeat its InsertEnter lazy loading.
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      -- Start per buffer rather than enabling globally: vim.lsp.enable installs
      -- its own FileType handler, which would still start on later large buffers.
      local function start_server(server, bufnr)
        local config = vim.deepcopy(vim.lsp.config[server])
        local opts = { bufnr = bufnr, reuse_client = config.reuse_client }
        if type(config.root_dir) == 'function' then
          config.root_dir(bufnr, function(root_dir)
            config.root_dir = root_dir
            vim.lsp.start(config, opts)
          end)
        else
          opts._root_markers = config.root_markers
          vim.lsp.start(config, opts)
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('lsp-buffer-applicability', { clear = true }),
        callback = function(args)
          if not vim.b[args.buf].large_file_mode then lsp_servers.sync_buffer(args.buf) end
        end,
      })

      for server, filetypes in pairs(lsp_filetypes) do
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('lsp-on-demand-' .. server, { clear = true }),
          pattern = filetypes,
          callback = function(args)
            if vim.b[args.buf].large_file_mode or not lsp_servers.sync_buffer(args.buf) then return end
            start_server(server, args.buf)
          end,
        })
      end

      -- Autocmds registered during FileType don't fire for that same event, so
      -- `nvim foo.lua` would otherwise start no server for the startup file.
      -- Cover every buffer already open when this config() ran.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and not vim.b[buf].large_file_mode and lsp_servers.sync_buffer(buf) then
          local ft = vim.bo[buf].filetype
          if ft ~= '' then
            for server, filetypes in pairs(lsp_filetypes) do
              if vim.tbl_contains(filetypes, ft) then start_server(server, buf) end
            end
          end
        end
      end

      vim.api.nvim_create_user_command('NvimCheckPythonLsp', function()
        local found = require('config.python_lsp').installed()
        if #found > 0 then
          vim.notify('Python LSP available: ' .. table.concat(found, ', '))
        else
          vim.notify('No Python LSP selected; install ty or pyrefly (optional)', vim.log.levels.WARN)
        end
      end, { desc = 'Report the selected Python LSP tooling' })
    end,
  },
  -- Live rename preview; LspAttach maps grn with fallback when unavailable.
  {
    'smjonas/inc-rename.nvim',
    cmd = 'IncRename',
    event = 'LspAttach',
    opts = {},
  },
}
