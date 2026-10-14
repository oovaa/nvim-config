---@module 'config.snacks_excludes'
-- Shared exclude list for snacks picker sources (explorer/files/grep).
-- Single source of truth so build/dependency dirs stay consistent everywhere
-- (fd/rg/tree all take the same glob; `i` toggling ignored can't bring them back).

return {
  'node_modules',
  'dist',
  'build',
  'out',
  'target',
  'vendor',
  'coverage',
  '__pycache__',
  '.venv',
  '.next',
  '.nuxt',
  '.git',
  '.turbo',
  '.pytest_cache',
}
