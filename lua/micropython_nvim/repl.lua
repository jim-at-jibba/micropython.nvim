local Terminal = require('toggleterm.terminal').Terminal

local M = {}

function M.repl()
  local repl_assembled_command = string.format('rshell -p %s', _G['AMPY_PORT'])
  local term = Terminal:new({ cmd = repl_assembled_command, direction = 'float' })
  term:toggle()
end

return M
