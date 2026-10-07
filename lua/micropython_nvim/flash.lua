local Config = require('micropython_nvim.config')
local Device = require('micropython_nvim.device')
local Mpremote = require('micropython_nvim.mpremote')
local Utils = require('micropython_nvim.utils')

local M = {}

M.INSTALL_HINT = 'Install with: uv tool install mpflash (or: pip install mpflash)'

-- How many recent releases the version picker offers, after stable and preview
M.MAX_VERSIONS = 10

-- Versions mpflash resolves itself: the latest release and the latest nightly build
M.CHANNELS = { 'stable', 'preview' }

-- How long to wait after closing the REPL before mpremote and mpflash open the port
local REPL_RELEASE_MS = 500

local RELEASES_REPO = 'https://github.com/micropython/micropython'

---@class MicroPython.FlashTarget
---@field serial? string Serial port to flash; mpflash flashes every connected board without one
---@field detected boolean Whether MicroPython answered; if not, mpflash asks for the board

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---@param version string
---@return integer[]
local function _version_parts(version)
  return vim.tbl_map(tonumber, vim.split(version, '.', { plain = true }))
end

---Release versions from `git ls-remote --tags` output, newest first
---@param output string
---@return string[]
function M.parse_versions(output)
  local versions = {}
  for line in vim.gsplit(output, '\n') do
    local version = line:match('refs/tags/v(%d+%.%d+%.%d+)%s*$')
    if version then
      table.insert(versions, version)
    end
  end
  table.sort(versions, function(a, b)
    local x, y = _version_parts(a), _version_parts(b)
    for i = 1, 3 do
      if x[i] ~= y[i] then
        return x[i] > y[i]
      end
    end
    return false
  end)
  return vim.list_slice(versions, 1, M.MAX_VERSIONS)
end

---The mpflash command: on PATH, else from the uv project's venv; nil if not installed
---@return string[]?
function M.mpflash()
  if vim.fn.executable('mpflash') == 1 then
    return { 'mpflash' }
  end
  if Utils.is_uv_project() and vim.fn.executable(Utils.get_cwd() .. '/.venv/bin/mpflash') == 1 then
    return { 'uv', 'run', 'mpflash' }
  end
  return nil
end

---mpflash argv to flash a firmware version
---@param mpflash string[] The mpflash command, from M.mpflash()
---@param version string 'stable', 'preview' or a release such as '1.24.1'
---@param target MicroPython.FlashTarget
---@return string[]
function M.argv(mpflash, version, target)
  local args = vim.list_extend(vim.deepcopy(mpflash), { 'flash', '--version', version })
  if target.serial then
    vim.list_extend(args, { '--serial', target.serial })
  end
  if not target.detected then
    vim.list_extend(args, { '--board', '?' })
  end
  return args
end

---Completion for :MP flash
---@param arglead string
---@param index integer
---@return string[]
function M.complete(arglead, index)
  if index > 1 then
    return {}
  end
  return vim.tbl_filter(function(channel)
    return vim.startswith(channel, arglead)
  end, M.CHANNELS)
end

---The serial port mpremote would connect to; nil if no connected device matches
---@param on_serial fun(serial?: string)
local function _resolve_serial(on_serial)
  local port = Config.get_port()
  if port ~= 'auto' and not vim.startswith(port, 'id:') then
    on_serial(port)
    return
  end
  Mpremote.run({ 'connect', 'list' }, {
    connect = false,
    on_exit = function(result)
      for _, device in ipairs(Mpremote.parse_device_list(result.stdout)) do
        -- mpremote's auto picks the first port with a USB vid:pid, listed as 0000:0000 without one
        local matches = port == 'auto' and not vim.startswith(device.manufacturer, '0000:0000')
          or port == 'id:' .. device.serial
        if matches then
          on_serial(device.port)
          return
        end
      end
      on_serial(nil)
    end,
  })
end

---@param on_versions fun(versions: string[])
local function _fetch_versions(on_versions)
  Utils.run_job({ 'git', 'ls-remote', '--tags', '--refs', RELEASES_REPO }, {}, function(result)
    if result.code ~= 0 then
      Utils.debug_print('fetching MicroPython releases failed: ' .. result.stderr)
      on_versions({})
      return
    end
    on_versions(M.parse_versions(result.stdout))
  end)
end

---@param board? MicroPython.Board
---@return string
local function _prompt(board)
  if not board then
    return 'No MicroPython detected (mpflash will ask for the board). Flash firmware:'
  end
  local name = board.machine or board.platform or 'device'
  local current = board.version and ('MicroPython ' .. board.version) or 'a preview build'
  return string.format('Flash %s (now %s) with:', name, current)
end

---@param mpflash string[]
---@param version string
---@param target MicroPython.FlashTarget
local function _run(mpflash, version, target)
  local command = Utils.shell_join(M.argv(mpflash, version, target))
  require('micropython_nvim.terminal').open(command .. ' 2>&1; ' .. Utils.PRESS_ENTER_PROMPT)
end

---Detect the board, resolve its serial port and pick a version, then flash
---@param mpflash string[]
---@param version? string
local function _start(mpflash, version)
  local board, serial, versions
  local pending = version and 2 or 3

  local function done()
    pending = pending - 1
    if pending > 0 then
      return
    end
    if not serial then
      _notify(
        'No connected device found to flash. Connect the board, or run :MP set_port. '
          .. 'A board with no serial port (a Pico in BOOTSEL mode) can be flashed from a shell: '
          .. 'mpflash flash --board <BOARD_ID>',
        vim.log.levels.ERROR
      )
      return
    end

    local target = { serial = serial, detected = board ~= nil }
    if version then
      _run(mpflash, version, target)
      return
    end
    local items = vim.list_extend(vim.deepcopy(M.CHANNELS), versions)
    require('micropython_nvim.ui').select(items, { prompt = _prompt(board) }, function(choice)
      if not choice then
        return
      end
      _run(mpflash, choice, target)
    end)
  end

  _notify('Detecting the board to flash...', vim.log.levels.INFO)
  Device.detect(function(detected)
    board = detected
    done()
  end)
  _resolve_serial(function(resolved)
    serial = resolved
    done()
  end)
  if not version then
    _fetch_versions(function(fetched)
      versions = fetched
      done()
    end)
  end
end

---Flash MicroPython firmware with mpflash: `:MP flash [version]`, or pick a version
---@param args string[]
function M.flash(args)
  if #args > 1 then
    _notify('Usage: :MP flash [stable|preview|<version>]', vim.log.levels.ERROR)
    return
  end
  local mpflash = M.mpflash()
  if not mpflash then
    _notify('mpflash not found. ' .. M.INSTALL_HINT, vim.log.levels.ERROR)
    return
  end
  if not Utils.check_port_configured() then
    return
  end

  -- The REPL holds the serial port, which mpflash needs; give mpremote time to let go of it
  local Repl = require('micropython_nvim.repl')
  if Repl.is_running() then
    Repl.close()
    vim.defer_fn(function()
      _start(mpflash, args[1])
    end, REPL_RELEASE_MS)
    return
  end
  _start(mpflash, args[1])
end

return M
