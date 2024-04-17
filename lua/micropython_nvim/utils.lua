local M = {}

M.extra = 'printf "\\\\n\\\\033[0;33mPlease Press ENTER to continue \\\\033[0m"; read' 

-- NOTE(JGB): Cant get this to work without printing to the screen
function M.ampy_install_check()
  local handle = io.popen('pip show ampy')

  local result = handle:read('*a')
  handle:close()

  if result:match('ampy') then -- checks if 'ampy' is in the result
    return true
  else
    vim.notify('Ampy not found in the current venv', vim.log.levels.ERROR)
    return false
  end
end

return M
