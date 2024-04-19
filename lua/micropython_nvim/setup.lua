local utils = require('micropython_nvim.utils')
local M = {}

--- Shows a list of baud rates for the user to select from.
-- The selected baud rate is set as a global variable and passed to the set_baud_rate function.
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

  vim.ui.select(options, {}, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    -- set the baud rate in the global variable
    vim.g.AMPY_BAUD = choice
    M.set_baud_rate(choice)
  end)
end

--- Sets the baud rate for the ampy command in the shell.
-- @param baud_rate The baud rate to set. If not provided, defaults to '9600'.
function M.set_baud_rate(baud_rate)
  baud_rate = baud_rate or '9600'
  -- Sets the baud rate for the ampy command in the shell
  _G['AMPY_BAUD'] = baud_rate
  vim.notify('Baud rate set to: ' .. baud_rate, vim.log.levels.INFO)
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

  vim.ui.select(ports, {}, function(choice)
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
