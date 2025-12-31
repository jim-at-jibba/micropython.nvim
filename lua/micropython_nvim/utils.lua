local Config = require('micropython_nvim.config')

local M = {}

M.PRESS_ENTER_PROMPT = 'printf "\\n\\033[0;33mPlease Press ENTER to continue \\033[0m"; read'

---@param message string
function M.debug_print(message)
  if Config.is_debug() then
    print(message)
  end
end

---@return boolean
function M.ampy_install_check()
  local ok, handle = pcall(io.popen, 'pip show ampy')
  if not ok or not handle then
    vim.notify(
      'Failed to check ampy installation',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return false
  end

  local result = handle:read('*a')
  handle:close()

  if result:match('ampy') then
    return true
  else
    vim.notify(
      'Ampy not found in the current venv',
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end
end

---@return string
function M.get_cwd()
  return vim.fn.getcwd()
end

---@return string
function M.get_ampy_path()
  return M.get_cwd() .. '/.ampy'
end

---@return boolean
function M.ampy_config_exists()
  return vim.fn.filereadable(M.get_ampy_path()) == 1
end

function M.read_ampy_config()
  local ampy_path = M.get_ampy_path()
  if not M.ampy_config_exists() then
    M.debug_print('No .ampy file found in the current directory')
    return
  end

  local handle = io.open(ampy_path, 'r')
  if not handle then
    vim.notify('Failed to open .ampy file', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return
  end

  local result = handle:read('*a')
  handle:close()

  for line in result:gmatch('[^\r\n]+') do
    local key, value = line:match('([^=]+)=([^=]+)')
    if key and value then
      key = key:match('^%s*(.-)%s*$')
      value = value:match('^%s*(.-)%s*$')
      if key == 'AMPY_PORT' then
        Config.set_port(value)
      elseif key == 'AMPY_BAUD' then
        Config.set_baud(value)
      end
    end
  end

  vim.notify(
    'Ampy config loaded from .ampy file',
    vim.log.levels.INFO,
    { title = 'micropython.nvim' }
  )
end

---@param path string
---@param template string
---@return boolean
function M.create_file_with_template(path, template)
  local file, err = io.open(path, 'w')
  if not file then
    vim.notify(
      'Error creating file: ' .. (err or 'unknown'),
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end

  file:write(template)
  file:close()
  M.debug_print('File created successfully at ' .. path)
  return true
end

---@param file_path string
---@param needle string
---@param replacement string
---@return boolean
function M.replace_line(file_path, needle, replacement)
  M.debug_print(string.format('Replacing line in file: %s %s %s', file_path, needle, replacement))

  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify(
      'File not readable: ' .. file_path,
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end

  local temp_path = file_path .. '_temp'
  local temp_file = io.open(temp_path, 'w')
  if not temp_file then
    vim.notify(
      'Failed to open temporary file for writing',
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end

  for line in io.lines(file_path) do
    if not line:match(needle) then
      temp_file:write(line .. '\n')
    else
      temp_file:write(replacement .. '\n')
    end
  end
  temp_file:close()

  local ok, err = os.rename(temp_path, file_path)
  if not ok then
    vim.notify(
      'Failed to rename temp file: ' .. (err or 'unknown'),
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end

  return true
end

return M
