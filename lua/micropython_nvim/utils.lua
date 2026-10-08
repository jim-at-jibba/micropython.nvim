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
function M.uv_available()
  return vim.fn.executable('uv') == 1
end

---@return string
function M.get_cwd()
  return vim.fn.getcwd()
end

---Warn and return false when no device port is configured
---@return boolean
function M.check_port_configured()
  if Config.is_port_configured() then
    return true
  end
  vim.notify(
    'No port configured. Run :MP set_port first.',
    vim.log.levels.WARN,
    { title = 'micropython.nvim' }
  )
  return false
end

---@return boolean
function M.pyproject_exists()
  return vim.fn.filereadable(M.get_cwd() .. '/pyproject.toml') == 1
end

---@class MicroPython.JobResult
---@field code integer Exit code, or -1 if the command could not be started
---@field stdout string
---@field stderr string

---Join an argv into a shell-escaped command string, for a terminal
---@param argv string[]
---@return string
function M.shell_join(argv)
  return table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
end

---Run a command in the background without a shell, collecting its output
---@param argv string[]
---@param opts { cwd?: string }
---@param on_exit fun(result: MicroPython.JobResult)
function M.run_job(argv, opts, on_exit)
  local stdout, stderr = {}, {}
  local ok, job = pcall(vim.fn.jobstart, argv, {
    cwd = opts.cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_stderr = function(_, data)
      stderr = data
    end,
    on_exit = function(_, code)
      on_exit({
        code = code,
        stdout = vim.trim(table.concat(stdout, '\n')),
        stderr = vim.trim(table.concat(stderr, '\n')),
      })
    end,
  })
  if not ok or job <= 0 then
    on_exit({ code = -1, stdout = '', stderr = argv[1] .. ' could not be started' })
  end
end

---snacks.nvim if installed (module or the Snacks global), else nil
---@return table|nil
function M.get_snacks()
  local ok, snacks = pcall(require, 'snacks')
  if ok and snacks then
    return snacks
  end
  return rawget(_G, 'Snacks')
end

---@return boolean
function M.is_uv_project()
  return M.uv_available() and M.pyproject_exists()
end

---@return boolean
function M.mpremote_install_check()
  local is_uv = M.is_uv_project()
  local cmd = is_uv and 'uv run mpremote --version 2>/dev/null' or 'mpremote --version 2>/dev/null'

  local ok, handle = pcall(io.popen, cmd)
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
    local install_hint = is_uv and 'uv sync' or 'pip install mpremote'
    vim.notify(
      'mpremote not found. Install with: ' .. install_hint,
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return false
  end
end

---@return string
function M.get_config_path()
  return M.get_cwd() .. '/.micropython'
end

---@return boolean
function M.config_exists()
  return vim.fn.filereadable(M.get_config_path()) == 1
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

---Load the port from the project's .micropython file
---@return nil
function M.read_config()
  local path = M.get_config_path()
  if not M.config_exists() then
    M.debug_print('No config file found in the current directory')
    return
  end

  local handle = io.open(path, 'r')
  if not handle then
    vim.notify('Failed to open config file', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return
  end

  local content = handle:read('*a')
  handle:close()

  local config = _parse_config_content(content)
  if config['PORT'] then
    Config.set_port(config['PORT'])
  end

  vim.notify('Config loaded from ' .. path, vim.log.levels.INFO, { title = 'micropython.nvim' })
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

---@return boolean
function M.requirements_exists()
  return vim.fn.filereadable(M.get_cwd() .. '/requirements.txt') == 1
end

---@return string
function M.get_directory_name()
  local cwd = M.get_cwd()
  local name = vim.fn.fnamemodify(cwd, ':t')
  -- Sanitize for Python package name: replace invalid chars, handle leading digits
  name = name:gsub('[^%w_]', '_'):gsub('^(%d)', '_%1'):lower()
  return name
end

return M
