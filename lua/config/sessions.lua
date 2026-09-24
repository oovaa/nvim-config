---@module 'config.sessions'
-- BUILTIN SESSIONS (replaces rmagatti/auto-session, zero loss via :mksession)
-- Split from init.lua. Required after lazy.nvim setup (see init.lua).
-- ponytail: native mksession + VimEnter/VimLeave autocmds; no plugin needed
-- `nvim` with no args in a cwd restores that cwd's session if present (buffers + last file)

vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'
local suppressed = { ['~/'] = true, ['~/Downloads'] = true, ['/etc'] = true, ['/tmp'] = true }
local function suppressed_dir(cwd)
  cwd = (cwd or vim.uv.cwd() or vim.fn.getcwd()):gsub('/+$', '')
  if cwd == '' then cwd = '/' end
  for d in pairs(suppressed) do
    local e = vim.fn.expand(d):gsub('/+$', '')
    if e == '' then e = '/' end
    if cwd == e then return true end -- exact only; not subdirs (fixes ~/ blocking ~/projects/*)
  end
  return false
end
local function session_file_for(cwd)
  cwd = cwd and vim.fn.fnamemodify(vim.fn.resolve(cwd), ':p') or vim.fn.fnamemodify(vim.fn.resolve(vim.fn.getcwd()), ':p')
  return vim.fn.stdpath 'data' .. '/sessions/' .. cwd:gsub('[^%w]+', '%%') .. '.vim'
end
local function session_file() return session_file_for(nil) end
-- one sessions-dir listing shared by find_session_for + dashboard picker.
-- (glob returns {} on a missing dir; fs.dir errors, so guard with fs_stat.)
local function session_files(dir)
  local out = {}
  if vim.uv.fs_stat(dir) == nil then return out end
  for name, t in vim.fs.dir(dir) do
    if t == 'file' and name:match('%.vim$') then
      local st = vim.uv.fs_stat(dir .. '/' .. name)
      out[#out + 1] = { path = dir .. '/' .. name, mtime = st and st.mtime.sec or 0 }
    end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  return out
end
-- find existing session for cwd by scanning cd line (supports legacy %2F names)
local function find_session_for(cwd)
  cwd = cwd and vim.fn.fnamemodify(vim.fn.resolve(cwd), ':p') or vim.fn.fnamemodify(vim.fn.resolve(vim.fn.getcwd()), ':p')
  local f = session_file_for(cwd)
  local function has_badd(p)
    if vim.fn.filereadable(p) ~= 1 then return false end
    for _, l in ipairs(vim.fn.readfile(p)) do if l:match('^badd') then return true end end
    return false
  end
  if has_badd(f) then return f end
  local norm = cwd:gsub('/+$', '')
  if norm == '' then norm = '/' end
  local dir = vim.fn.stdpath('data') .. '/sessions'
  local best, best_time = nil, -1
  for _, e in ipairs(session_files(dir)) do
    local path = e.path
    if has_badd(path) then
      for _, l in ipairs(vim.fn.readfile(path)) do
        local cd = l:match('^cd%s+(.+)$')
        if cd then
          cd = vim.fn.fnamemodify(vim.fn.expand(cd), ':p'):gsub('/+$', '')
          if cd == '' then cd = '/' end
          if cd == norm then
            if e.mtime > best_time then best, best_time = path, e.mtime end
          end
          break
        end
      end
    end
  end
  if best then return best end
  return f
end
-- expose for dashboard s picker
_G._builtin_find_session = find_session_for
_G._builtin_session_files = session_files
-- ponytail: no auto-restore on VimEnter; dashboard is default, `s` restores (see spec.lua)
-- helpers kept for `s` (find_session_for / session_file)
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    if suppressed_dir() then return end
    -- don't overwrite good session with empty dashboard/no-file state
    local has_file = false
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == '' and vim.api.nvim_buf_get_name(b) ~= '' and vim.bo[b].filetype ~= 'dashboard' then has_file = true; break end
    end
    if not has_file then return end
    pcall(vim.cmd, 'silent! Neotree close')
    vim.fn.mkdir(vim.fn.stdpath 'data' .. '/sessions', 'p')
    vim.cmd('silent! mksession! ' .. vim.fn.fnameescape(session_file()))
  end,
})
