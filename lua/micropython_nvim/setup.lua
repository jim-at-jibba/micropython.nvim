local M = {}

function M.show_baud_rate_list()
  -- 1200, 2400, 4800, 19200, 38400, 57600, and 115200
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
    print('You selected: ' .. choice)

    vim.g.AMPY_BAUD = choice
    M.set_baud_rate(choice)
  end)
end

function M.set_baud_rate(baud_rate)
  -- Validate baud_rate or set a default
  baud_rate = baud_rate or '9600'

  -- Use vim.cmd to set the environment variable
  vim.cmd('let $AMPY_BAUD = "' .. baud_rate .. '"')

  print('Baud rate set to: ' .. baud_rate)
end

return M
