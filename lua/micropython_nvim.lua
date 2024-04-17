local run = require('micropython_nvim.run')
local setup = require('micropython_nvim.setup')

local M = {}

function M.run()
  run.mprun()
end

function M.setBaudRate()
  setup.show_baud_rate_list()
end

return M
