-- lua/plugins/editing.lua — SECTION 6.7: EDITING UTILITIES
-- Plugins that enhance text editing and manipulation.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- TODO-COMMENTS
  -- WHAT: Highlights TODO, FIXME, NOTE, WARN, etc. in comments with colors
  -- TO CHANGE: Remove this plugin if you don't want comment highlighting
  -- EFFECT: Words like TODO, FIXME, HACK get colored backgrounds in comments
  --         Helps you find important notes in your code
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
    keys = { { '<leader>st', function() require('snacks').picker.todo_comments() end, desc = '[S]earch [T]odo comments' } },
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  -- MINI.NVIM
  -- WHAT: Collection of small, independent modules for text editing
  -- TO CHANGE: Add/remove mini.* modules in the config function
  -- EFFECT: Provides surround (gs prefix), ai textobjects, statusline
  -- LOADING: VeryLazy = loads after UI is ready
  {
    'nvim-mini/mini.nvim',
    event = 'VeryLazy',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
        mappings = {
          around_next = 'aa',
          inside_next = 'ii',
        },
        n_lines = 250,
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- Use `gs` prefix instead of `s` to avoid conflict with flash.nvim
      -- - gsaiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - gsd'   - [S]urround [D]elete [']quotes
      -- - gsr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          replace = 'gsr',
          update_n_lines = 'gsn',
          suffix_last = 'l',
          suffix_next = 'n',
        },
      }
      -- gss<surrounding> to surround current line (e.g. gss" -> "line")
      vim.keymap.set('n', 'gss', 'gsa_', { remap = true })

      -- Auto-pair brackets, parens, quotes: when you type ( it adds ), etc.
      -- LazyVim-style: skip next char, skip inside treesitter strings.
      require('mini.pairs').setup {
        modes = { insert = true, command = true, terminal = false },
        skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
        skip_ts = { 'string' },
        skip_unbalanced = true,
        markdown = true,
      }

      -- Bracketed navigation: [b/]b buffers, [q/]q quickfix, [t/]t
      -- treesitter, [u/]u undo states... (zero new dep — ships inside
      -- mini.nvim). Diagnostic suffix disabled: [d/]d already jump with
      -- a float in lua/config/keymaps.lua. See :help mini.bracketed.
      require('mini.bracketed').setup { diagnostic = { suffix = '' } }

      -- Extra mini modules (Phase 1.5). Collision audit: <M-hjkl> unused;
      -- mini.align uses `ga`/`gA` (overrides builtin char-info `ga`);
      -- mini.operators remapped off `gr` (LSP namespace), `gx` (URL open),
      -- `gs` (surround prefix), `gm` (middle-screen).
      require('mini.move').setup {}
      require('mini.splitjoin').setup {}
      require('mini.align').setup {}
      require('mini.operators').setup {
        evaluate = { prefix = 'g=' },
        exchange = { prefix = 'gX' },
        multiply = { prefix = 'gM' },
        replace = { prefix = 'cr' },
        sort = { prefix = 'gS' },
      }

      -- Statusline is builtin (see lua/custom/ui/spec.lua).

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  -- TS-COMMENTS (#6 LazyVim gap): treesitter-aware commenting.
  -- Without it `gc` uses one commentstring per filetype; with it embedded
  -- languages get the right string (e.g. JS inside vue/svelte, lua docs).
  { 'folke/ts-comments.nvim', event = 'VeryLazy', opts = {} },

  -- AUTO-SAVE
  -- WHAT: Automatically saves your file when you leave insert mode or stop typing
  -- TO CHANGE: Remove this plugin if you prefer manual saving
  -- EFFECT: Your work is saved automatically - no need to press :w constantly
  -- LOADING: InsertLeave/TextChanged = loads when you type or leave insert mode
  {
    'okuuva/auto-save.nvim',
    cmd = 'ASToggle',
    event = { 'InsertLeave', 'TextChanged' },
    opts = {
      -- Never auto-save large files (>1MB) — they're read-only by design.
      condition = function(buf) return not vim.b[buf].large_file_mode end,
      -- defer_save is debounced (one timer per buffer, restarted on every
      -- event), so TextChanged costs one write 1s after the last change — per
      -- burst, not per keystroke. TextChanged exists for normal-mode edits
      -- (dd/x/r/J): InsertLeave alone never fires when insert is never
      -- entered. A >=1s typing pause also saves mid-insert; those writes are
      -- unformatted (guard in formatting.lua) and format at the next save
      -- outside insert.
      --
      -- immediate_save restores the stock safety net (esp. QuitPre): without
      -- it, edits made <1s before quitting hit the debounce timer and are
      -- silently lost.
      trigger_events = {
        immediate_save = { 'QuitPre', 'FocusLost', 'BufLeave', 'VimSuspend' },
        defer_save = { 'InsertLeave', 'TextChanged' },
        cancel_deferred_save = { 'InsertEnter' },
      },
    },
  },

  -- RUSTACEANVIM (Rust): successor to archived rust-tools.nvim.
  -- DO NOT also enable an nvim-lspconfig/vim.lsp rust_analyzer for rust —
  -- rustaceanvim registers rust-analyzer itself. Install rust-analyzer via
  -- rustup (`rustup component add rust-analyzer clippy rustfmt`), not Mason:
  -- a Mason RA build mismatches the project's toolchain and breaks clippy.
  {
    'mrcjkb/rustaceanvim',
    version = '^9', -- v9 needs neovim >= 0.12
    ft = { 'rust' },
    init = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = {
            ['rust-analyzer'] = {
              -- clippy-on-save is the community standard; allFeatures stays
              -- off by default (enable per-project via rust-analyzer.toml).
              checkOnSave = true,
              check = { command = 'clippy' },
              cargo = { allFeatures = false },
            },
          },
        },
      }
    end,
  },

  -- NVIM-JDTLS (Java): Eclipse JDT Language Server with project-aware workspace
  -- (per-root data dir) and bundled debug/test adapters when mason has them.
  -- Needs JDK 21+ on PATH for jdtls itself; project can target older releases.
  {
    'mfussenegger/nvim-jdtls',
    ft = { 'java' },
    config = function()
      local jdtls = require 'jdtls'
      local cwd = vim.fn.getcwd()
      local root_markers = { 'gradlew', 'mvnw', 'pom.xml', 'build.gradle', 'build.gradle.kts', '.git' }
      local root = vim.fs.root(0, root_markers) or cwd
      local mason_pkg = vim.fn.stdpath 'data' .. '/mason/packages'
      local jdtls_pkg = mason_pkg .. '/jdtls'
      if vim.fn.executable 'java' ~= 1 then
        vim.notify(
          'jdtls requires JDK 21+ on PATH (java not found). Install a JDK (e.g. brew install openjdk@21) then :MasonInstall jdtls.',
          vim.log.levels.WARN
        )
        return
      end
      -- jdtls is launched via the Equinox launcher jar, not by -jar-ing the
      -- core jar (which has no Main-Class). Deps live in plugins/ next to it.
      local launcher = vim.fn.glob(jdtls_pkg .. '/plugins/org.eclipse.equinox.launcher_*.jar')
      if launcher == '' then
        vim.notify(
          'jdtls not installed — run :Mason and install jdtls (needs network to download.eclipse.org; may be blocked in this env)',
          vim.log.levels.WARN
        )
        return
      end
      local config_dir = jdtls_pkg .. (vim.fn.isdirectory(jdtls_pkg .. '/config_mac') == 1 and '/config_mac' or '/config_linux')
      local data_dir = vim.fn.stdpath 'cache' .. '/jdtls/' .. vim.fn.fnamemodify(root, ':p:h:t') .. '-' .. vim.fn.sha256(root)
      -- Debug + test adapters: bundle jars if mason installed them (optional).
      local bundles = {}
      local jdtls_bundles_glob = mason_pkg .. '/java-test/extension/server/com.microsoft.java.test.plugin-*.jar'
      local debug_glob = mason_pkg .. '/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar'
      for _, pattern in ipairs { jdtls_bundles_glob, debug_glob } do
        local matches = vim.fn.glob(pattern, true, true)
        if matches and #matches > 0 then vim.list_extend(bundles, matches) end
      end
      local blink_ok, blink = pcall(require, 'blink.cmp')
      local function on_attach(_, bufnr)
        -- Java debug/test: setup_dap is called by jdtls internally when
        -- opts.dap is passed; here we only discover main-class configs.
        if #bundles > 0 then pcall(require('jdtls.dap').setup_dap_main_class_configs) end
        -- standard LSP keymaps are applied globally by lsp.lua's LspAttach autocmd
      end
      jdtls.start_or_attach({
        cmd = {
          'java',
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.level=INFO',
          '-Xmx1g',
          '--add-modules=ALL-SYSTEM',
          '--add-opens',
          'java.base/java.util=ALL-UNNAMED',
          '--add-opens',
          'java.base/java.lang=ALL-UNNAMED',
          '-jar',
          launcher,
          '-configuration',
          config_dir,
          '-data',
          data_dir,
        },
        root_dir = root,
        capabilities = blink_ok and blink.get_lsp_capabilities() or {},
        bundles = bundles,
        on_attach = on_attach,
        init_options = { bundles = bundles },
        settings = {
          java = {
            eclipse = { downloadSources = true },
            maven = { downloadSources = true },
            format = { enabled = true },
            signatureHelp = { enabled = true },
            -- Google style via settings; google-java-format (conform) is the
            -- actual writer. Comment out the conform java row to let jdtls format.
            checkstyle = { enabled = false },
          },
        },
      }, { dap = { hotcodereplace = 'auto' } })

      -- Discover main-class debug configs after jdtls is ready (on_attach is
      -- not reliably fired by vim.lsp.start for jdtls in all contexts).
      vim.schedule(function()
        vim.defer_fn(function()
          if #bundles > 0 then
            pcall(require('jdtls.dap').setup_dap, { hotcodereplace = 'auto' })
            pcall(require('jdtls.dap').setup_dap_main_class_configs)
          end
        end, 10000)
      end)
    end,
  },

  -- VTSLS (fast TypeScript LSP via @vtsls/language-server)
  -- WHAT: Replaces ts_ls/typescript-tools with direct IPC, optimized memory
  -- TO CHANGE: Remove if you prefer built-in ts_ls
  -- EFFECT: Faster completions, better Drizzle/NestJS inference, lower CPU
  -- LOADING: ft = only loads for JavaScript/TypeScript files
  {
    'yioneko/nvim-vtsls',
    dependencies = { 'nvim-lua/plenary.nvim', 'saghen/blink.cmp' },
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' },
    config = function()
      require('lazy').load { plugins = { 'blink.cmp' } }
      local blink_ok, blink = pcall(require, 'blink.cmp')
      local capabilities = blink_ok and blink.get_lsp_capabilities() or {}
      -- Registers VtsExec/VtsRename + the move-to-file handler via the
      -- plugin's LspAttach autocmd; without this enableMoveToFileCodeAction is dead.
      require('vtsls').config {}
      -- Native equivalent of the old require('vtsls').lspconfig bridge:
      -- same cmd/filetypes/root priority, same settings (user's plus the
      -- updateImportsOnFileMove/enableMoveToFileCodeAction defaults lspconfig merged in).
      vim.lsp.config('vtsls', {
        cmd = { 'vtsls', '--stdio' },
        -- vue: vtsls picks up typescript-vue-plugin when present; prettier
        -- formats vue (formatting.lua); oxlint skips .vue SFC (prettier-only).
        filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' },
        root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
        capabilities = capabilities,
        settings = {
          typescript = {
            updateImportsOnFileMove = 'always',
            suggest = { completeFunctionCalls = true },
            -- 'on' forces a package.json dependency scan on every completion;
            -- 'auto' only when an import statement needs it (much cheaper).
            preferences = { includePackageJsonAutoImports = 'auto' },
            tsserver = {
              -- 1536 balances monorepo inference vs RSS (was 2048; lower
              -- to 1024 if RSS spikes, raise if completions lag).
              maxTsServerMemory = 1536,
              -- inotify-based watching instead of polling node_modules:
              -- keeps tsserver CPU flat in large repos.
              watchOptions = {
                watchFile = 'useFsEvents',
                watchDirectory = 'useFsEvents',
                fallbackPolling = 'dynamicPriority',
              },
            },
          },
          javascript = {
            updateImportsOnFileMove = 'always',
          },
          vtsls = {
            autoUseWorkspaceTsdk = true,
            enableMoveToFileCodeAction = true,
            experimental = {
              completion = { enableServerSideFuzzyMatch = true },
            },
          },
        },
      })
      vim.lsp.enable 'vtsls'
    end,
  },

  -- CODE RUNNER (builtin — replaces code_runner.nvim, zero loss via :terminal)
}
