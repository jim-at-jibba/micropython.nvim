local Config = require('micropython_nvim.config')
local Mpremote = require('micropython_nvim.mpremote')
local Utils = require('micropython_nvim.utils')

local M = {}

---@class MicroPython.DeviceInfo
---@field firmware? string
---@field board? string
---@field storage? { total: integer, free: integer } Bytes on the root filesystem
---@field time? string Device clock, YYYY-MM-DD HH:MM:SS

-- Prints one tab-separated line per field, so the output can be parsed reliably
local INFO_SCRIPT = [[
import os, time
u = os.uname()
print('firmware\t' + u.version)
print('board\t' + u.machine)
try:
    s = os.statvfs('/')
    print('storage\t%d\t%d' % (s[0] * s[2], s[0] * s[3]))
except Exception:
    pass
try:
    print('time\t%04d-%02d-%02d %02d:%02d:%02d' % time.localtime()[:6])
except Exception:
    pass
]]

-- Common micropython-lib packages offered by :MP mip completion and its picker
M.MIP_PACKAGES = {
  'aioble',
  'aiohttp',
  'aiorepl',
  'base64',
  'collections-defaultdict',
  'datetime',
  'dht',
  'ds18x20',
  'hmac',
  'logging',
  'neopixel',
  'ntptime',
  'onewire',
  'requests',
  'ssd1306',
  'umqtt.robust',
  'umqtt.simple',
  'unittest',
  'urllib.urequest',
  'webrepl',
}

local MIP_SOURCES = { 'github:', 'gitlab:' }

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---Parse the output of the info script
---@param output string
---@return MicroPython.DeviceInfo
function M.parse_info(output)
  local info = {}
  for line in vim.gsplit(output, '\n') do
    local fields = vim.split((line:gsub('\r$', '')), '\t')
    local key = fields[1]
    local total, free = tonumber(fields[2]), tonumber(fields[3])
    if key == 'storage' and #fields == 3 and total and free then
      info.storage = { total = total, free = free }
    elseif (key == 'firmware' or key == 'board' or key == 'time') and #fields == 2 then
      info[key] = fields[2]
    end
  end
  return info
end

---@param bytes integer
---@return string
local function _size(bytes)
  if bytes >= 1024 * 1024 then
    return string.format('%.1f MiB', bytes / (1024 * 1024))
  end
  return string.format('%.1f KiB', bytes / 1024)
end

---@param label string
---@param value? string
---@return string
local function _field(label, value)
  return string.format('%-14s%s', label .. ':', value or 'unknown')
end

---Readable lines describing a device
---@param info MicroPython.DeviceInfo
---@return string[]
function M.format_info(info)
  local storage
  if info.storage then
    local total, free = info.storage.total, info.storage.free
    storage =
      string.format('%s used of %s (%s free)', _size(total - free), _size(total), _size(free))
  end
  return {
    _field('Firmware', info.firmware and 'MicroPython ' .. info.firmware),
    _field('Board', info.board),
    _field('Storage', storage),
    _field('Device time', info.time),
  }
end

local function _set_clock()
  Mpremote.run({ 'rtc', '--set' }, { name = 'Set device clock' })
end

---@param lines string[]
local function _show(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width, math.max(vim.o.columns - 4, 1))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width + 2,
    height = #lines,
    row = math.max(math.floor((vim.o.lines - #lines) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = 'minimal',
    border = 'rounded',
    title = ' MicroPython device ',
    title_pos = 'center',
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set('n', 'q', close, vim.tbl_extend('force', opts, { desc = 'Close' }))
  vim.keymap.set('n', '<Esc>', close, vim.tbl_extend('force', opts, { desc = 'Close' }))
  vim.keymap.set('n', 's', function()
    close()
    _set_clock()
  end, vim.tbl_extend('force', opts, { desc = 'Set the device clock from this computer' }))
end

---Show firmware, board, storage and clock of the device, offering to set its clock
function M.info()
  if not Utils.check_port_configured() then
    return
  end

  Mpremote.run({ 'exec', INFO_SCRIPT }, {
    on_exit = function(result)
      if result.code ~= 0 then
        _notify('Device info failed:\n' .. Mpremote.error_output(result), vim.log.levels.ERROR)
        return
      end
      local lines = { _field('Port', Config.get_port()) }
      vim.list_extend(lines, M.format_info(M.parse_info(result.stdout)))
      vim.list_extend(lines, { '', 's  set the device clock from this computer', 'q  close' })
      _show(lines)
    end,
  })
end

---mpremote arguments to install a package with mip
---@param package string micropython-lib name, or github:org/repo[@branch] and similar
---@param target? string directory on the device
---@return string[]
function M.mip_args(package, target)
  local args = { 'mip', 'install' }
  if target then
    vim.list_extend(args, { '--target', target })
  end
  table.insert(args, package)
  return args
end

---Completion for :MP mip: common micropython-lib packages and package sources
---@param arglead string
---@param index? integer which argument is being completed; only the package is completed
---@return string[]
function M.mip_complete(arglead, index)
  if index and index > 1 then
    return {}
  end
  local candidates = vim.list_extend(vim.deepcopy(M.MIP_PACKAGES), MIP_SOURCES)
  return vim.tbl_filter(function(name)
    return vim.startswith(name, arglead)
  end, candidates)
end

---@param package string
---@param target? string
local function _install(package, target)
  Mpremote.run(M.mip_args(package, target), { name = 'Install ' .. package })
end

---Install a package on the device: `:MP mip <package> [target]`, or pick one with no arguments
---@param args string[]
function M.mip(args)
  if #args > 2 then
    _notify('Usage: :MP mip <package> [target directory]', vim.log.levels.ERROR)
    return
  end
  if not Utils.check_port_configured() then
    return
  end

  if #args > 0 then
    _install(args[1], args[2])
    return
  end
  require('micropython_nvim.ui').select(
    M.MIP_PACKAGES,
    { prompt = 'Install package:' },
    function(choice)
      if not choice then
        return
      end
      _install(choice)
    end
  )
end

return M
