local Config = require('micropython_nvim.config')
local Mpremote = require('micropython_nvim.mpremote')
local Terminal = require('micropython_nvim.terminal')

local M = {}

function M.open()
  if not Config.is_port_configured() then
    vim.notify(
      'No port configured. Run :MPSetPort first.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return
  end

  local repl_command = Mpremote.command({ 'repl' })
  Terminal.open(repl_command)
end

return M
