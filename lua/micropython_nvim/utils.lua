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

function M.readAmpyConfig()
  local cw_dir = vim.fn.getcwd()
  local handle = io.popen('cat ' .. cw_dir .. '/.ampy')

  if handle == nil then
    vim.notify('No .ampy file found in the current directory', vim.log.levels.ERROR)
    return
  end
  local result = handle:read('*a')
  local lines = {}
  for s in result:gmatch('[^\r\n]+') do
    table.insert(lines, s)
  end

  for _, line in ipairs(lines) do
    -- Split the line on "="
    local key, value = line:match('([^=]+)=([^=]+)')
    if key and value then
      -- Trim whitespace
      key = key:match('^%s*(.-)%s*$')
      value = value:match('^%s*(.-)%s*$')
      -- Assign to global variable
      _G[key] = value
    end
  end

  handle:close()
  vim.notify('Ampy config variables set from .ampy file', vim.log.levels.INFO)
end

return M
