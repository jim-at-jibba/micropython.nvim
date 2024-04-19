local Terminal = require('toggleterm.terminal').Terminal

local M = {}

--- Opens a MicroPython REPL in a floating terminal using rshell.
-- The port is taken from the global variable 'AMPY_PORT'.
-- The command used is 'rshell -p <port>'.
function M.repl()
  local repl_assembled_command = string.format('rshell -p %s', _G['AMPY_PORT'])
  local term = Terminal:new({ cmd = repl_assembled_command, direction = 'float' })
  term:toggle()
end

return M
