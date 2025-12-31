local Config = require('micropython_nvim.config')
local Terminal = require('toggleterm.terminal').Terminal

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

  local repl_command = string.format('rshell -p %s repl', Config.get_port())
  local term = Terminal:new({ cmd = repl_command, direction = 'float' })
  term:toggle()
end

return M
