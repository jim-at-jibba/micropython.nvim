local run = require('micropython_nvim.run')

local M = {}

function M.run()
  run.mprun()
end

return M
