local Config = require('micropython_nvim.config')
local Mpremote = require('micropython_nvim.mpremote')
local Utils = require('micropython_nvim.utils')

local M = {}

local UV_INSTALL_URL = 'https://docs.astral.sh/uv/getting-started/installation/'

---@param name string
---@return boolean
local function _executable(name)
  return vim.fn.executable(name) == 1
end

---@param argv string[]
---@return string
local function _version(argv)
  local ok, output = pcall(vim.fn.system, argv)
  if not ok or vim.v.shell_error ~= 0 then
    return ''
  end
  return vim.trim(output or '')
end

local function _check_neovim()
  if vim.fn.has('nvim-0.9') == 1 then
    vim.health.ok('Neovim >= 0.9')
  else
    vim.health.error('Neovim >= 0.9 is required', { 'Upgrade Neovim' })
  end
end

---@return boolean available
local function _check_mpremote()
  local is_uv = Utils.is_uv_project()
  local hint = is_uv and 'Run `uv sync` in the project (or `:MP install`)'
    or 'Install with: pip install mpremote (or: uv tool install mpremote)'

  if not is_uv and not _executable('mpremote') then
    vim.health.error('mpremote not found', { hint })
    return false
  end

  local result = Mpremote.run_sync({ 'version' }, { connect = false })
  if result.code ~= 0 then
    vim.health.error('mpremote could not be run: ' .. Mpremote.error_output(result), { hint })
    return false
  end

  local source = is_uv and ' (via uv run)' or ''
  vim.health.ok(result.stdout .. source)
  return true
end

local function _check_uv()
  if not _executable('uv') then
    vim.health.warn('uv not found; needed for :MP init and :MP install', {
      'Install uv: ' .. UV_INSTALL_URL,
    })
    return
  end
  vim.health.ok(_version({ 'uv', '--version' }))
end

local function _check_snacks()
  if Utils.get_snacks() then
    vim.health.ok('snacks.nvim installed: used for terminals and pickers')
  else
    vim.health.info(
      'snacks.nvim not installed (optional): using the built-in terminal and vim.ui.select'
    )
  end
end

local function _check_mpflash()
  if _executable('mpflash') then
    vim.health.ok(_version({ 'mpflash', '--version' }))
  else
    vim.health.info(
      'mpflash not found (optional, for flashing firmware). '
        .. 'Install with: uv tool install mpflash (or: pip install mpflash)'
    )
  end
end

local function _check_project_config()
  if Utils.config_exists() then
    vim.health.ok('Project config found: ' .. Utils.get_config_path())
  elseif Utils.ampy_config_exists() then
    vim.health.warn('Legacy .ampy config found: ' .. Utils.get_ampy_path(), {
      'Run :MP init to create a .micropython config',
    })
  else
    vim.health.info(
      'No project config in '
        .. Utils.get_cwd()
        .. '. Run :MP init to set up a MicroPython project (from the project root)'
    )
  end
end

---@param port string
---@param device MicroPython.Device
---@return boolean
local function _matches(port, device)
  return port == device.port or port == 'id:' .. device.serial
end

local function _check_device()
  local result = Mpremote.run_sync({ 'connect', 'list' }, { connect = false })
  if result.code ~= 0 then
    vim.health.warn('Could not list devices: ' .. Mpremote.error_output(result))
    return
  end

  local devices = Mpremote.parse_device_list(result.stdout)
  if #devices == 0 then
    vim.health.warn('No MicroPython device found', {
      'Connect a board over USB with a data cable',
      'On Linux, add your user to the dialout (or uucp) group',
    })
    return
  end

  local port = Config.get_port()
  if port == 'auto' or port == '' then
    local ports = vim.tbl_map(function(device)
      return device.port
    end, devices)
    vim.health.ok('Port auto; devices found: ' .. table.concat(ports, ', '))
    return
  end

  for _, device in ipairs(devices) do
    if _matches(port, device) then
      vim.health.ok(string.format('Configured port %s is connected (%s)', port, device.port))
      return
    end
  end

  vim.health.warn('Configured port ' .. port .. ' is not connected', {
    'Run :MP set_port to choose a connected device',
    'Run :MP list_devices to see what is connected',
  })
end

function M.check()
  vim.health.start('micropython.nvim')
  _check_neovim()
  local has_mpremote = _check_mpremote()
  _check_uv()
  _check_mpflash()
  _check_snacks()

  vim.health.start('Project')
  _check_project_config()

  vim.health.start('Device')
  if has_mpremote then
    _check_device()
  else
    vim.health.info('Skipped: mpremote is not available')
  end
end

return M
