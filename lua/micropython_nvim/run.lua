local M = {}

local utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal

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
  local command = 'ampy run  ' .. vim.api.nvim_buf_get_name(0) .. '; ' .. utils.extra
  local term = Terminal:new({ cmd = command, direction = 'float' })
  term:toggle()
end

return M
