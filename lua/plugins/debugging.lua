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

      -- Python debugging. dap-python's default adapter is already
      -- `python3 -m debugpy`, so this needs no path argument: the old gate
      -- looked for a mason venv that cannot exist on this host (python3 has no
      -- ensurepip, Trap 4), which left the adapter unconfigured *and* unusable
      -- because debugpy is not importable either. `:checkhealth config` reports
      -- the missing debugpy; install it with pip/uv, not mason.
      require('dap-python').setup {}
    end,
  },
}
