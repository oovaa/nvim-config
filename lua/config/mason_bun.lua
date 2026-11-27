-- Mason v2 has no bun compiler: npm-source packages go through the npm manager.
-- Swap that manager so bun is primary and real npm is the fallback.
-- The `node` shim in ~/.local/bin is still needed for the installed bins.
local M = {}

local Result = require 'mason-core.result'
local npm = require 'mason-core.installer.managers.npm'

local function have_bun() return vim.fn.executable 'bun' == 1 end

local function context() return require('mason-core.installer').context() end

function M.init()
  if not have_bun() then return npm.init() end
  -- bun add writes package.json itself; nothing to initialise.
  return Result.success()
end

function M.install(pkg, version, opts)
  if not have_bun() then return npm.install(pkg, version, opts) end
  local ctx = context()
  local spec = ('%s@%s'):format(pkg, version)
  ctx.stdio_sink:stdout(('Installing %s with bun…\n'):format(spec))
  local packages = { spec }
  vim.list_extend(packages, opts.extra_packages or {})
  return ctx.spawn.bun { 'add', unpack(packages) }
end

function M.uninstall(pkg)
  if not have_bun() then return npm.uninstall(pkg) end
  return context().spawn.bun { 'remove', pkg }
end

M.bin_path = npm.bin_path

function M.setup() package.loaded['mason-core.installer.managers.npm'] = M end

return M
