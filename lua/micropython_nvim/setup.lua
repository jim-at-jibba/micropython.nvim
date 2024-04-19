local utils = require('micropython_nvim.utils')
local M = {}

--- This function displays a list of available baud rates for the MicroPython device.
-- The baud rate is the rate at which information is transferred in a communication channel.
-- In the context of MicroPython and Neovim, it's the speed at which Neovim communicates with the MicroPython device.
function M.show_baud_rate_list()
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
  local pfile

  -- For Unix/Linux/MacOS:
  local command = 'ls /dev/tty*'

  -- Open the command for reading
  pfile = io.popen(command)

  if pfile then
    for filename in pfile:lines() do
      table.insert(ports, filename)
    end

    -- Close the file handle
    pfile:close()
  end

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

return M
