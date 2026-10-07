local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')
local UI = require('micropython_nvim.ui')

local M = {}

---@class MicroPython.DeviceEntry
---@field path string Path on the device, relative to its root
---@field dir boolean
---@field size integer Bytes; 0 for directories

---@class MicroPython.DeviceListing
---@field entries MicroPython.DeviceEntry[] Sorted so children follow their directory
---@field total? integer Filesystem size in bytes, when the device reports it
---@field free? integer Free bytes, when the device reports it

local BROWSER_NAME = 'micropython://files'
local PREFIX = 'mp://'
local HELP = '<CR> open  d delete  D download  a mkdir  u upload  R refresh  q close'
-- Gap between the longest name and the size column, and the width sizes are right-aligned to
local SIZE_GAP = 2
local SIZE_WIDTH = 10
-- How long quitting Neovim waits for mp:// writes still in flight
local WRITE_WAIT_MS = 10000

-- Walks the device filesystem from the current directory: one `D|F <tab> size <tab> path` line
-- per entry, then `S <tab> total <tab> free` when statvfs is available
local LIST_CODE = [[
import os
def w(p):
 for e in (os.ilistdir(p) if p else os.ilistdir()):
  f = p + '/' + e[0] if p else e[0]
  if e[1] & 0x4000:
   print('D\t0\t' + f)
   w(f)
  else:
   print('F\t%d\t%s' % (e[3] if len(e) > 3 else os.stat(f)[6], f))
w('')
try:
 s = os.statvfs('.')
 print('S\t%d\t%d' % (s[0] * s[2], s[0] * s[3]))
except Exception:
 pass]]

local state = {
  ---@type integer?
  buf = nil,
  ---The file buffer the browser was opened from, for uploads
  ---@type integer?
  source = nil,
  ---@type table<integer, MicroPython.DeviceEntry>
  entries_by_line = {},
  ---mp:// writes still running
  pending_writes = 0,
}

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---Ask a yes/no question; on_yes runs only for an explicit yes
---@param question string
---@param on_yes fun()
local function _confirm(question, on_yes)
  UI.select({ 'Yes', 'No' }, { prompt = question }, function(choice)
    if choice == 'Yes' then
      on_yes()
    end
  end)
end

---Parse the output of the device listing code
---@param output string
---@return MicroPython.DeviceListing
function M.parse_listing(output)
  local listing = { entries = {} }
  -- The device prints \r\n line endings
  for line in vim.gsplit(output:gsub('\r', ''), '\n') do
    local kind, size, path = line:match('^([DF])\t(%d+)\t(.+)$')
    if kind then
      table.insert(listing.entries, { path = path, dir = kind == 'D', size = tonumber(size) })
    else
      local total, free = line:match('^S\t(%d+)\t(%d+)$')
      if total then
        listing.total, listing.free = tonumber(total), tonumber(free)
      end
    end
  end
  -- A separator that sorts before every character keeps children directly under their directory
  table.sort(listing.entries, function(a, b)
    return a.path:gsub('/', '\1') < b.path:gsub('/', '\1')
  end)
  return listing
end

---@param bytes integer
---@return string
local function _format_size(bytes)
  if bytes < 1024 then
    return bytes .. ' B'
  elseif bytes < 1024 * 1024 then
    return string.format('%.1f KB', bytes / 1024)
  end
  return string.format('%.1f MB', bytes / (1024 * 1024))
end

---@param dir string
---@param name string
---@return string
local function _join(dir, name)
  return dir == '' and name or (dir .. '/' .. name)
end

---@param listing MicroPython.DeviceListing
---@return string[] lines, table<integer, MicroPython.DeviceEntry> entries_by_line
local function _render(listing)
  local device = 'Device ' .. Config.get_port()
  -- Some ports report zeros for filesystems they cannot measure
  if listing.total and listing.total > 0 then
    device = string.format(
      '%s  ·  %s free of %s',
      device,
      _format_size(listing.free),
      _format_size(listing.total)
    )
  end
  local lines, entries_by_line = { device, HELP, '' }, {}

  local labels, width = {}, 0
  for i, entry in ipairs(listing.entries) do
    local _, depth = entry.path:gsub('/', '')
    labels[i] = string.rep('  ', depth) .. vim.fs.basename(entry.path) .. (entry.dir and '/' or '')
    width = math.max(width, vim.fn.strdisplaywidth(labels[i]))
  end

  for i, entry in ipairs(listing.entries) do
    local line = labels[i]
    if not entry.dir then
      local size = _format_size(entry.size)
      local padding = width - vim.fn.strdisplaywidth(line) + SIZE_GAP + SIZE_WIDTH - #size
      line = line .. string.rep(' ', padding) .. size
    end
    table.insert(lines, line)
    entries_by_line[#lines] = entry
  end

  if #listing.entries == 0 then
    table.insert(lines, '(no files)')
  end
  return lines, entries_by_line
end

---@param lines string[]
local function _set_browser_lines(lines)
  local buf = state.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

---@return boolean
local function _browser_valid()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

---List the device files and redraw the browser
function M.refresh()
  if not _browser_valid() then
    return
  end
  Mpremote.run({ 'exec', LIST_CODE }, {
    on_exit = function(result)
      if not _browser_valid() then
        return
      end
      if result.code ~= 0 then
        _notify(
          'Failed to list device files:\n' .. Mpremote.error_output(result),
          vim.log.levels.ERROR
        )
        _set_browser_lines({ 'Could not list device files. Press R to retry.' })
        state.entries_by_line = {}
        return
      end
      local lines, entries_by_line = _render(M.parse_listing(result.stdout))
      _set_browser_lines(lines)
      state.entries_by_line = entries_by_line
    end,
  })
end

---@return MicroPython.DeviceEntry?
local function _entry_under_cursor()
  return state.entries_by_line[vim.api.nvim_win_get_cursor(0)[1]]
end

---The directory an action applies to: the directory under the cursor, the directory of the
---file under the cursor, or the device root
---@return string
local function _selected_dir()
  local entry = _entry_under_cursor()
  if not entry then
    return ''
  end
  if entry.dir then
    return entry.path
  end
  local parent = vim.fs.dirname(entry.path)
  return parent == '.' and '' or parent
end

---Run a device command and refresh the browser when it succeeds
---@param args string[]
---@param name string
local function _run_and_refresh(args, name)
  Mpremote.run(args, {
    name = name,
    on_exit = function(result)
      if result.code == 0 then
        M.refresh()
      end
    end,
  })
end

local function _open_entry()
  local entry = _entry_under_cursor()
  if not entry or entry.dir then
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(PREFIX .. entry.path))
end

local function _delete_entry()
  local entry = _entry_under_cursor()
  if not entry then
    return
  end
  local question, args = 'Delete ' .. entry.path .. '?', { 'fs', 'rm', ':' .. entry.path }
  if entry.dir then
    question = 'Delete ' .. entry.path .. '/ and everything in it?'
    args = { 'fs', 'rm', '-r', ':' .. entry.path }
  end
  _confirm(question, function()
    _run_and_refresh(args, 'Delete ' .. entry.path)
  end)
end

local function _download_entry()
  local entry = _entry_under_cursor()
  if not entry then
    return
  end
  if entry.dir then
    _notify('Only files can be downloaded', vim.log.levels.WARN)
    return
  end
  local destination = Utils.get_cwd() .. '/' .. entry.path
  local function download()
    vim.fn.mkdir(vim.fs.dirname(destination), 'p')
    Mpremote.run({ 'cp', ':' .. entry.path, destination }, { name = 'Download ' .. entry.path })
  end
  if vim.fn.filereadable(destination) == 1 then
    _confirm('Overwrite local ' .. entry.path .. '?', download)
  else
    download()
  end
end

local function _make_dir()
  local dir = _selected_dir()
  vim.ui.input({ prompt = 'New directory in /' .. dir .. ': ' }, function(name)
    name = name and vim.trim(name):gsub('^/+', ''):gsub('/+$', '')
    if not name or name == '' then
      return
    end
    local path = _join(dir, name)
    _run_and_refresh({ 'fs', 'mkdir', ':' .. path }, 'Create ' .. path)
  end)
end

local function _upload_source()
  local source = state.source
  local path = source and vim.api.nvim_buf_is_valid(source) and vim.api.nvim_buf_get_name(source)
  if not path or path == '' or vim.fn.filereadable(path) ~= 1 then
    _notify('No saved local file to upload: open the browser from a file', vim.log.levels.WARN)
    return
  end
  if vim.bo[source].modified then
    _notify('Save ' .. vim.fs.basename(path) .. ' before uploading it', vim.log.levels.WARN)
    return
  end
  local target = _join(_selected_dir(), vim.fs.basename(path))
  _run_and_refresh({ 'cp', path, ':' .. target }, 'Upload ' .. target)
end

local function _close()
  if _browser_valid() then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

---@return integer
local function _create_browser()
  -- A browser left over from before a plugin reload still holds the name
  local stale = vim.fn.bufnr('^' .. BROWSER_NAME .. '$')
  if stale > 0 then
    vim.api.nvim_buf_delete(stale, { force = true })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, BROWSER_NAME)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].filetype = 'micropython-files'

  local maps = {
    ['<CR>'] = { _open_entry, 'Open file' },
    d = { _delete_entry, 'Delete from device' },
    D = { _download_entry, 'Download into the project' },
    a = { _make_dir, 'Create directory' },
    u = { _upload_source, 'Upload the previous file here' },
    R = { M.refresh, 'Refresh' },
    q = { _close, 'Close' },
  }
  for lhs, map in pairs(maps) do
    vim.keymap.set('n', lhs, map[1], { buffer = buf, nowait = true, desc = map[2] })
  end
  return buf
end

---Open the device file browser
function M.open()
  if not Utils.check_port_configured() then
    return
  end

  local current = vim.api.nvim_get_current_buf()
  if current ~= state.buf and vim.bo[current].buftype == '' then
    state.source = current
  end

  if not _browser_valid() then
    state.buf = _create_browser()
    state.entries_by_line = {}
    _set_browser_lines({ 'Loading device files…' })
  end
  vim.api.nvim_set_current_buf(state.buf)
  M.refresh()
end

---@param buf integer
---@return string
local function _device_path(buf)
  return vim.api.nvim_buf_get_name(buf):sub(#PREFIX + 1)
end

---Show a device file that could not be loaded; the buffer stays read-only so :w cannot
---overwrite the device file with an empty one
---@param buf integer
---@param msg string
local function _read_failed(buf, msg)
  _notify(msg, vim.log.levels.ERROR)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

---Load an mp:// buffer from the device (BufReadCmd)
---@param buf integer
function M.read(buf)
  local path = _device_path(buf)
  local tmp = vim.fn.tempname()
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.b[buf].micropython_loaded = false

  Mpremote.run({ 'cp', ':' .. path, tmp }, {
    on_exit = function(result)
      if not vim.api.nvim_buf_is_valid(buf) then
        os.remove(tmp)
        return
      end
      if result.code ~= 0 then
        _read_failed(
          buf,
          'Failed to read ' .. path .. ' from the device:\n' .. Mpremote.error_output(result)
        )
        return
      end

      -- 'b' keeps a final empty item when the file ends with a newline
      local lines = vim.fn.readfile(tmp, 'b')
      os.remove(tmp)
      local eol = lines[#lines] == ''
      if eol then
        table.remove(lines)
      end

      vim.bo[buf].modifiable = true
      local undolevels = vim.bo[buf].undolevels
      vim.bo[buf].undolevels = -1
      -- Lines holding NUL bytes (binary files) are rejected
      local ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
      vim.bo[buf].undolevels = undolevels
      if not ok then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
        _read_failed(buf, path .. ' looks like a binary file and cannot be edited')
        return
      end

      vim.bo[buf].eol = eol
      vim.bo[buf].fixeol = false
      vim.bo[buf].modified = false
      vim.b[buf].micropython_loaded = true
      vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ''
    end,
  })
end

---Wait for mp:// writes still running, so quitting does not cut them off
function M.wait_for_writes()
  vim.wait(WRITE_WAIT_MS, function()
    return state.pending_writes == 0
  end, 50)
end

---Write an mp:// buffer to the device (BufWriteCmd)
---@param buf integer
function M.write(buf)
  local path = _device_path(buf)
  if not vim.b[buf].micropython_loaded then
    _notify(path .. ' was not loaded from the device, so it was not written', vim.log.levels.ERROR)
    return
  end

  local tmp = vim.fn.tempname()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.writefile(lines, tmp, vim.bo[buf].eol and '' or 'b')

  -- Marked written now so :wq works; restored if the device write fails
  vim.bo[buf].modified = false
  state.pending_writes = state.pending_writes + 1
  Mpremote.run({ 'cp', tmp, ':' .. path }, {
    name = 'Write ' .. path,
    on_exit = function(result)
      state.pending_writes = state.pending_writes - 1
      os.remove(tmp)
      if result.code ~= 0 and vim.api.nvim_buf_is_valid(buf) then
        vim.bo[buf].modified = true
      end
    end,
  })
end

return M
