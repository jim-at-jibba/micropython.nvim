local M = {}

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

function M.set_baud_rate(baud_rate)
  baud_rate = baud_rate or '9600'
  -- Sets the baud rate for the ampy command in the shell
  vim.cmd('let $AMPY_BAUD = "' .. baud_rate .. '"')
  vim.notify('Baud rate set to: ' .. baud_rate, vim.log.levels.INFO)
end

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

function M.set_port()
  local ports = getPortsList()

  vim.ui.select(ports, {}, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    -- set the baud rate in the global variable
    vim.g.AMPY_PORT = choice
    -- M.set_baud_rate(choice)
  end)
end

function M.set_port_var(port)
  port = port or '9600'
  -- Sets the port for the ampy command in the shell
  vim.cmd('let $AMPY_PORT = "' .. port .. '"')
  vim.notify('Port set to: ' .. port, vim.log.levels.INFO)
end

return M
