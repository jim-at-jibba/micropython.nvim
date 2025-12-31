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
function M.mpremote_install_check()
  local ok, handle = pcall(io.popen, 'mpremote --version 2>/dev/null')
  if not ok or not handle then
    vim.notify(
      'Failed to check mpremote installation',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return false
  end

  local result = handle:read('*a')
  handle:close()

  if result:match('mpremote') then
    return true
  else
    vim.notify(
      'mpremote not found. Install with: pip install mpremote',
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end
end

---@deprecated Use mpremote_install_check() instead
---@return boolean
function M.ampy_install_check()
  M.debug_print('ampy_install_check is deprecated, use mpremote_install_check')
  return M.mpremote_install_check()
end

---@return string
function M.get_cwd()
  return vim.fn.getcwd()
end

---@return string
function M.get_config_path()
  return M.get_cwd() .. '/.micropython'
end

---@deprecated Use get_config_path() instead
---@return string
function M.get_ampy_path()
  return M.get_cwd() .. '/.ampy'
end

---@return boolean
function M.config_exists()
  return vim.fn.filereadable(M.get_config_path()) == 1
end

---@deprecated Use config_exists() instead
---@return boolean
function M.ampy_config_exists()
  return vim.fn.filereadable(M.get_ampy_path()) == 1
end

---@param content string
---@return table<string, string>
local function _parse_config_content(content)
  local config = {}
  for line in content:gmatch('[^\r\n]+') do
    if not line:match('^%s*#') then
      local key, value = line:match('([^=]+)=([^=]+)')
      if key and value then
        key = key:match('^%s*(.-)%s*$')
        value = value:match('^%s*(.-)%s*$')
        config[key] = value
      end
    end
  end
  return config
end

---@return nil
function M.read_config()
  local config_path = M.get_config_path()
  local ampy_path = M.get_ampy_path()
  local path_to_use = nil
  local is_legacy = false

  if M.config_exists() then
    path_to_use = config_path
  elseif M.ampy_config_exists() then
    path_to_use = ampy_path
    is_legacy = true
    vim.notify(
      '.ampy config is deprecated. Run :MPInit to migrate to .micropython',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
  else
    M.debug_print('No config file found in the current directory')
    return
  end

  local handle = io.open(path_to_use, 'r')
  if not handle then
    vim.notify('Failed to open config file', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return
  end

  local content = handle:read('*a')
  handle:close()

  local config = _parse_config_content(content)

  if is_legacy then
    if config['AMPY_PORT'] then
      Config.set_port(config['AMPY_PORT'])
    end
    if config['AMPY_BAUD'] then
      Config.set_baud(config['AMPY_BAUD'])
    end
  else
    if config['PORT'] then
      Config.set_port(config['PORT'])
    end
    if config['BAUD'] then
      Config.set_baud(config['BAUD'])
    end
  end

  vim.notify(
    'Config loaded from ' .. path_to_use,
    vim.log.levels.INFO,
    { title = 'micropython.nvim' }
  )
end

---@deprecated Use read_config() instead
---@return nil
function M.read_ampy_config()
  M.read_config()
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

---@return string
function M.get_mpremote_base()
  local connect_arg = Config.get_connect_arg()
  if connect_arg ~= '' then
    return 'mpremote ' .. connect_arg .. ' '
  end
  return 'mpremote '
end

return M
