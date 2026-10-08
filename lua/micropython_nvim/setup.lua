local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')
local Stubs = require('micropython_nvim.stubs')
local UI = require('micropython_nvim.ui')

local M = {}

---@param on_devices fun(devices: MicroPython.Device[], err?: string)
function M.list_devices(on_devices)
  Mpremote.run({ 'connect', 'list' }, {
    connect = false,
    on_exit = function(result)
      if result.code ~= 0 then
        on_devices({}, Mpremote.error_output(result))
        return
      end
      on_devices(Mpremote.parse_device_list(result.stdout))
    end,
  })
end

---@param on_ports fun(ports: string[])
local function _get_ports_list(on_ports)
  M.list_devices(function(devices)
    local ports = { 'auto' }
    for _, device in ipairs(devices) do
      table.insert(ports, device.port)
    end

    if #devices == 0 then
      local patterns = {
        '/dev/ttyUSB*',
        '/dev/ttyACM*',
        '/dev/ttyS*',
        '/dev/tty.usbmodem*',
        '/dev/cu.usbmodem*',
      }
      for _, pattern in ipairs(patterns) do
        vim.list_extend(ports, vim.fn.glob(pattern, false, true))
      end
    end

    Utils.debug_print('ports: ' .. vim.inspect(ports))
    on_ports(ports)
  end)
end

function M.show_devices()
  M.list_devices(function(devices, err)
    if err then
      vim.notify(
        'Failed to list devices:\n' .. err,
        vim.log.levels.ERROR,
        { title = 'micropython.nvim' }
      )
      return
    end

    if #devices == 0 then
      vim.notify(
        'No MicroPython devices found',
        vim.log.levels.WARN,
        { title = 'micropython.nvim' }
      )
      return
    end

    local lines = { 'Available MicroPython devices:', '' }
    for _, device in ipairs(devices) do
      table.insert(
        lines,
        string.format('  %s (%s) - %s', device.port, device.serial, device.manufacturer)
      )
    end

    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'micropython.nvim' })
  end)
end

function M.set_port()
  _get_ports_list(function(ports)
    UI.select(ports, {
      prompt = 'Select a port:',
    }, function(choice)
      if not choice then
        return
      end

      Config.set_port(choice)

      local config_path = Utils.get_config_path()
      if Utils.config_exists() then
        local result = Utils.replace_line(config_path, 'PORT', 'PORT=' .. choice)
        if result then
          vim.notify('Port set to: ' .. choice, vim.log.levels.INFO, { title = 'micropython.nvim' })
        else
          vim.notify('Failed to set port', vim.log.levels.ERROR, { title = 'micropython.nvim' })
        end
      else
        vim.notify(
          'No config file found. Run :MP init first.',
          vim.log.levels.WARN,
          { title = 'micropython.nvim' }
        )
      end
    end)
  end)
end

---Switch the project's stubs: the board on the device is suggested first, the choice is
---declared in pyproject.toml or requirements.txt and installed into typings/ for pyright
function M.set_stubs()
  if not Utils.pyproject_exists() and not Utils.requirements_exists() then
    vim.notify(
      'No pyproject.toml or requirements.txt found. Run :MP init first.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return
  end

  Stubs.choose(function(choice)
    if not choice then
      return
    end

    if not Stubs.declare(choice) then
      vim.notify(
        'No MicroPython stubs declared in pyproject.toml or requirements.txt. Add '
          .. choice
          .. ' to your dev dependencies, then run :MP install.',
        vim.log.levels.WARN,
        { title = 'micropython.nvim' }
      )
      return
    end

    Stubs.configure_pyright()
    vim.notify(
      'MicroPython stubs set to: ' .. choice,
      vim.log.levels.INFO,
      { title = 'micropython.nvim' }
    )
    Stubs.install(choice)
  end)
end

return M
