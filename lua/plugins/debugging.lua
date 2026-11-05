-- lua/plugins/debugging.lua — SECTION 6.13: PYTHON DEVELOPMENT
-- Plugins for Python debugging and development.
-- Split from init.lua (see SECTION INDEX there). Comments kept verbatim.

---@module 'lazy'
---@type LazySpec
return {
  -- NVIM-DAP
  -- WHAT: Debug Adapter Protocol (DAP) implementation for step-through debugging
  -- TO CHANGE: Modify debug keybindings or add more language adapters
  -- EFFECT: Set breakpoints (<leader>db), step through code (<leader>dc/di/do),
  --         inspect variables, and debug Python tests
  -- LOADING: keys = only loads when you press debug keybindings
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui', -- Visual UI for the debugger
      'nvim-neotest/nvim-nio', -- Required by dap-ui
      'mfussenegger/nvim-dap-python', -- Python-specific debugging
    },
    keys = {
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = '[D]ebug [B]reakpoint' },
      { '<leader>dc', function() require('dap').continue() end, desc = '[D]ebug [C]ontinue' },
      { '<leader>di', function() require('dap').step_into() end, desc = '[D]ebug Step [I]nto' },
      { '<leader>do', function() require('dap').step_over() end, desc = '[D]ebug Step [O]ver' },
      { '<leader>dO', function() require('dap').step_out() end, desc = '[D]ebug Step [O]ut' },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = '[D]ebug [R]epl' },
      { '<leader>dl', function() require('dap').run_last() end, desc = '[D]ebug Run [L]ast' },
      { '<leader>dt', function() require('dap').terminate() end, desc = '[D]ebug [T]erminate' },
      { '<leader>dn', function() require('dap-python').test_method() end, desc = '[D]ebug [N]earest Test' },
      { '<leader>df', function() require('dap-python').test_class() end, desc = '[D]ebug Test [F]ile' },
      { '<leader>ds', function() require('dap-python').debug_selection() end, mode = 'v', desc = '[D]ebug [S]election' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      dapui.setup()
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      -- dap-python takes setup(python_path) — with no argument it defaults to
      -- 'python3' (must be on PATH and have debugpy importable; see :checkhealth).
      require('dap-python').setup()

      -- codelldb (C/C++; Rust uses rustaceanvim's own auto-detection): launch
      -- adapter over a port. Program path is asked at launch time.
      if vim.fn.executable 'codelldb' == 1 then
        dap.adapters.codelldb = {
          type = 'server',
          port = '${port}',
          executable = { command = 'codelldb', args = { '--port', '${port}' } },
        }
        for _, ft in ipairs { 'c', 'cpp' } do
          dap.configurations[ft] = {
            {
              name = 'Launch binary (codelldb)',
              type = 'codelldb',
              request = 'launch',
              program = function() return vim.fn.input('Binary path: ', vim.fn.getcwd() .. '/a.out', 'file') end,
              cwd = '${workspaceFolder}',
              stopOnEntry = false,
            },
          }
        end
      end

      -- js-debug-adapter (React/Node): register pwa-node + pwa-chrome once.
      -- Mason's js-debug-adapter serves DAP over a port it picks itself.
      if vim.fn.executable 'js-debug-adapter' == 1 then
        local adapter = {
          type = 'server',
          host = '127.0.0.1',
          port = '${port}',
          executable = { command = 'js-debug-adapter', args = { '${port}' } },
        }
        dap.adapters['pwa-node'] = adapter
        dap.adapters['pwa-chrome'] = adapter
        for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
          dap.configurations[ft] = {
            {
              type = 'pwa-node',
              request = 'launch',
              name = 'Launch current file',
              program = '${file}',
              cwd = '${workspaceFolder}',
              sourceMaps = true,
              console = 'integratedTerminal',
              skipFiles = { '<node_internals>/**', 'node_modules/**' },
            },
            {
              type = 'pwa-chrome',
              request = 'launch',
              name = 'Launch Chrome (localhost:3000)',
              url = 'http://localhost:3000',
              webRoot = '${workspaceFolder}',
              sourceMaps = true,
            },
          }
        end
      end
    end,
  },

  -- NVIM-DAP-GO (Go): delve adapter for Go debugging. Mason installs delve.
  {
    'leoluz/nvim-dap-go',
    ft = { 'go' },
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function() require('dap-go').setup() end,
  },
}
