local run = require('micropython_nvim.run')
local setup = require('micropython_nvim.setup')

local M = {}

function M.run()
  run.mprun()
end

function M.upload_current()
  run.mp_upload_current()
end

function M.set_baud_rate()
  setup.show_baud_rate_list()
end

function M.set_port()
  setup.set_port()
end

return M
