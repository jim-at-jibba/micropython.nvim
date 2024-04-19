local nvim = vim.api -- alias for Neovim API
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
    nvim.nvim_buf_get_name(0),
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

  -- Get all lines in the buffer
  local buf = nvim.nvim_get_current_buf()
  local lines = nvim.nvim_buf_get_lines(buf, 0, -1, false)

  local filePath = '/tmp/main.py'

  local file = io.open(filePath, 'w+')
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. '\n')
    end
    file:close()
    local ampy_assembled_command = string.format(
      'ampy -p %s -b %s put %s; %s',
      _G['AMPY_PORT'],
      _G['AMPY_BAUD'],
      filePath,
      utils.extra
    )
    local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
    term:toggle()
    vim.notify('Upload successful', vim.log.levels.INFO)
  else
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
  end
end

function M.erase_all()
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s rmdir -r / 2>&1; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

return M
