local utils = require('micropython_nvim.utils')
local M = {}

--- This function displays a list of available baud rates for the MicroPython device.
-- The baud rate is the rate at which information is transferred in a communication channel.
-- In the context of MicroPython and Neovim, it's the speed at which Neovim communicates with the MicroPython device.
function M.set_baud_rate()
  local options = {
    '1200',
    '2400',
    '4800',
    '19200',
    '38400',
    '57600',
    '115200',
  }

  vim.ui.select(options, {
    prompt = 'Select baud rate:',
  }, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    -- set the baud rate in the global variable
    _G['AMPY_BAUD'] = choice
    -- Remove the line containing AMPY_BAUD from the .ampy file
    local cw_dir = vim.fn.getcwd()
    local result = utils.replaceLine(cw_dir .. '/.ampy', 'AMPY_BAUD', 'AMPY_BAUD=' .. choice)
    if result then
      vim.notify('Baud rate set to: ' .. choice, vim.log.levels.INFO)
    else
      vim.notify('Failed to set baud rate', vim.log.levels.ERROR)
    end
  end)
end

--- Gets a list of available ports.
-- This function is specific to Unix/Linux/MacOS and gets the list of ports by running the 'ls /dev/tty*' command.
-- @return A table containing the names of the available ports.
local function getPortsList()
  local ports = {}
  -- Device patterns to check
  local patterns = {
    '/dev/ttyUSB*', -- USB-to-Serial adapters
    '/dev/ttyACM*', -- Arduino and similar CDC devices
    '/dev/ttyS*', -- Hardware serial ports
    '/dev/tty.usbmodem*',
  }

  for _, pattern in ipairs(patterns) do
    local pfile = io.popen('ls ' .. pattern .. ' 2>/dev/null')
    if pfile then
      for filename in pfile:lines() do
        table.insert(ports, filename)
      end
      pfile:close()
    end
  end

  vim.notify('🪚 ports: ' .. tostring(ports))
  return ports
end

--- Shows a list of available ports for the user to select from.
-- The selected port is set as a global variable and the line containing 'AMPY_PORT' in the .ampy file is replaced with 'AMPY_PORT=<selected port>'.
function M.set_port()
  local ports = getPortsList()

  vim.ui.select(ports, {
    prompt = 'Select a port:',
  }, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    -- set the baud rate in the global variable
    _G['AMPY_PORT'] = choice
    -- Remove the line containing AMPY_PORT from the .ampy file
    local cw_dir = vim.fn.getcwd()
    local result = utils.replaceLine(cw_dir .. '/.ampy', 'AMPY_PORT', 'AMPY_PORT=' .. choice)
    if result then
      vim.notify('Port set to: ' .. choice, vim.log.levels.INFO)
    else
      vim.notify('Failed to set port', vim.log.levels.ERROR)
    end
  end)
end

--- This function sets up stubs for the MicroPython environment in Neovim.
-- Stubs are used to provide autocompletion and linting for MicroPython specific modules and functions.
-- This function should be called during the setup phase of the plugin.
function M.set_stubs()
  local options = {
    'stm32',
    'esp32',
    'esp32-um-tinypico',
    'esp8266',
    'rp2',
    'rp2-pico',
    'rp2-pico-w',
    'windows',
    'unix',
    'Webassembly',
  }

  local newOptions = {}

  for i, option in ipairs(options) do
    newOptions[i] = string.format('micropython-%s-stubs', option)
  end

  table.insert(newOptions, 'samd-seeed_wio_terminal')

  vim.ui.select(newOptions, {
    prompt = 'Select stubs for board:',
  }, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    -- set the baud rate in the global variable
    -- Remove the line containing AMPY_BAUD from the .ampy file
    local cw_dir = vim.fn.getcwd()
    local result = utils.replaceLine(cw_dir .. '/requirements.txt', 'micropython-', choice)
    if result then
      vim.notify('MicroPython stubs set to: ' .. choice, vim.log.levels.INFO)
    else
      vim.notify('Failed to set micropython stubs', vim.log.levels.ERROR)
    end
  end)
end

return M
