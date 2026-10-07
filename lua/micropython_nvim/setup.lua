local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')
local UI = require('micropython_nvim.ui')

local M = {}

---@type string[]
M.BAUD_RATES = {
  '1200',
  '2400',
  '4800',
  '19200',
  '38400',
  '57600',
  '115200',
}

---@type string[]
M.STUB_OPTIONS = {
  'micropython-rp2-stubs',
  'micropython-rp2-pico-stubs',
  'micropython-rp2-pico-w-stubs',
  'micropython-esp32-stubs',
  'micropython-esp32-um-tinypico-stubs',
  'micropython-esp8266-stubs',
  'micropython-stm32-stubs',
  'micropython-samd-stubs',
  'micropython-unix-stubs',
  'micropython-windows-stubs',
  'micropython-webassembly-stubs',
}

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

function M.set_baud_rate()
  UI.select(M.BAUD_RATES, {
    prompt = 'Select baud rate:',
  }, function(choice)
    if not choice then
      return
    end

    Config.set_baud(choice)

    local config_path = Utils.get_config_path()
    if Utils.config_exists() then
      local result = Utils.replace_line(config_path, 'BAUD', 'BAUD=' .. choice)
      if result then
        vim.notify(
          'Baud rate set to: ' .. choice,
          vim.log.levels.INFO,
          { title = 'micropython.nvim' }
        )
      else
        vim.notify('Failed to set baud rate', vim.log.levels.ERROR, { title = 'micropython.nvim' })
      end
    elseif Utils.ampy_config_exists() then
      local ampy_path = Utils.get_ampy_path()
      local result = Utils.replace_line(ampy_path, 'AMPY_BAUD', 'AMPY_BAUD=' .. choice)
      if result then
        vim.notify(
          'Baud rate set to: ' .. choice,
          vim.log.levels.INFO,
          { title = 'micropython.nvim' }
        )
      else
        vim.notify('Failed to set baud rate', vim.log.levels.ERROR, { title = 'micropython.nvim' })
      end
    else
      vim.notify(
        'No config file found. Run :MPInit first.',
        vim.log.levels.WARN,
        { title = 'micropython.nvim' }
      )
    end
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
      elseif Utils.ampy_config_exists() then
        local ampy_path = Utils.get_ampy_path()
        local result = Utils.replace_line(ampy_path, 'AMPY_PORT', 'AMPY_PORT=' .. choice)
        if result then
          vim.notify('Port set to: ' .. choice, vim.log.levels.INFO, { title = 'micropython.nvim' })
        else
          vim.notify('Failed to set port', vim.log.levels.ERROR, { title = 'micropython.nvim' })
        end
      else
        vim.notify(
          'No config file found. Run :MPInit first.',
          vim.log.levels.WARN,
          { title = 'micropython.nvim' }
        )
      end
    end)
  end)
end

function M.set_stubs()
  UI.select(M.STUB_OPTIONS, {
    prompt = 'Select stubs for board:',
  }, function(choice)
    if not choice then
      return
    end

    local cwd = Utils.get_cwd()
    local result

    if Utils.pyproject_exists() then
      local pyproject_path = cwd .. '/pyproject.toml'
      local new_line = string.format('    "%s",', choice)
      result = Utils.replace_line(pyproject_path, 'micropython%-.*%-stubs', new_line)
    elseif Utils.requirements_exists() then
      local requirements_path = cwd .. '/requirements.txt'
      result = Utils.replace_line(requirements_path, 'micropython%-.*%-stubs', choice)
    else
      vim.notify(
        'No pyproject.toml or requirements.txt found. Run :MPInit first.',
        vim.log.levels.WARN,
        { title = 'micropython.nvim' }
      )
      return
    end

    if result then
      vim.notify(
        'MicroPython stubs set to: ' .. choice,
        vim.log.levels.INFO,
        { title = 'micropython.nvim' }
      )
    else
      vim.notify(
        'Failed to set micropython stubs',
        vim.log.levels.ERROR,
        { title = 'micropython.nvim' }
      )
    end
  end)
end

return M
