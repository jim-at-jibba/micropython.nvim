local M = {}

local utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal

--- Runs a MicroPython script on a device using ampy.
-- The script to run is the current buffer in Neovim.
-- The port and baud rate are taken from the global variables 'AMPY_PORT' and 'AMPY_BAUD'.
-- The command is run in a floating terminal.
function M.mprun()
  -- if not utils.ampy_install_check() then
  --   return
  -- end
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s run %s; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    vim.api.nvim_buf_get_name(0),
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

--- Uploads the current buffer in Neovim to a MicroPython device using ampy.
-- The port and baud rate are taken from the global variables 'AMPY_PORT' and 'AMPY_BAUD'.
-- The command is run in a floating terminal.
function M.mp_upload_current()
  -- if not utils.ampy_install_check() then
  --   return
  -- end
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s put %s; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    vim.api.nvim_buf_get_name(0),
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

return M
