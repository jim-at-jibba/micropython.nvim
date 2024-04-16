local M = {}

function M.ampy_install_check()
  -- this needs to check the current environment for the ampy tool
  local check_ampy = 'pip list | grep -q ampy'
  local status = os.execute(check_ampy) == 0

  if status == 0 then
    vim.notify('Ampy not found in the current venv', vim.log.levels.ERROR)
    return false
  end
  return true
end

return M
