local Mpremote = require('micropython_nvim.mpremote')
local Terminal = require('micropython_nvim.terminal')
local Utils = require('micropython_nvim.utils')

local M = {}

function M.open()
  if not Utils.check_port_configured() then
    return
  end

  local repl_command = Mpremote.command({ 'repl' })
  Terminal.open(repl_command)
end

return M
