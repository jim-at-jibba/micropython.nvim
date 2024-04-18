local M = {}

local utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal
local filepath = vim.api.nvim_buf_get_name(0)

-- function M.piobuild()
--   utils.cd_pioini()
--   local command = 'pio run; ' .. utils.extra
--   local term = Terminal:new({ cmd = command, direction = 'float' })
--   term:toggle()
-- end
--
-- function M.pioupload()
--   utils.cd_pioini()
--   local command = 'pio run --target upload; ' .. utils.extra
--   local term = Terminal:new({ cmd = command, direction = 'float' })
--   term:toggle()
-- end
--
-- function M.pioclean()
--   utils.cd_pioini()
--   local command = 'pio run --target clean; ' .. utils.extra
--   local term = Terminal:new({ cmd = command, direction = 'float' })
--   term:toggle()
-- end

function M.mprun()
  -- if not utils.ampy_install_check() then
  --   return
  -- end
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s run %s %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    filepath,
    utils.extra
  )
  print(ampy_assembled_command)
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

function M.mp_upload_current()
  -- if not utils.ampy_install_check() then
  --   return
  -- end
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s put %s %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    filepath,
    utils.extra
  )
  print(ampy_assembled_command)
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

return M
