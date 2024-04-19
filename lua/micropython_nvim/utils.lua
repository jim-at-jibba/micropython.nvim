local debug = true
local M = {}

M.extra = 'printf "\\\\n\\\\033[0;33mPlease Press ENTER to continue \\\\033[0m"; read'

-- NOTE(JGB): Cant get this to work without printing to the screen
--- Checks if 'ampy' is installed in the current Python environment.
-- @return true if 'ampy' is found, false otherwise.
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

--- Reads the .ampy configuration file in the current working directory and sets the variables in it as global variables.
-- The .ampy file should contain lines in the format 'KEY=VALUE'.
function M.readAmpyConfig()
  local cw_dir = vim.fn.getcwd()
  local handle = io.popen('cat ' .. cw_dir .. '/.ampy')

  if handle ~= nil then
    local result = handle:read('*a')
    print(type(result))
    if result == '' then
      if debug then
        vim.notify('No .ampy file found in the current directory', vim.log.levels.ERROR)
      end
      return
    end

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
end

--- Creates a new file at the specified path and writes a template string to it.
-- @param path The path where the file should be created.
-- @param template The string that should be written to the file.
function M.create_file_with_template(path, template)
  -- Open or create the file at the specified path for writing
  local file, err = io.open(path, 'w')
  if err then
    -- Error handling if the file cannot be opened/created
    print('Error creating file:', err)
    return
  end

  -- Write the template content to the file
  file:write(template)

  -- Close the file
  file:close()

  print('File created successfully with template content at ' .. path)
end

--- Replaces a line in a file that contains a specific string (needle) with a new line (replacement).
-- @param file The path to the file.
-- @param needle The string to search for in the file.
-- @param replacement The string to replace the found line with.
-- @usage replaceLine('/path/to/file', 'search string', 'replacement string')
function M.replaceLine(file, needle, replacement)
  if debug then
    print('Replacing line in file:', file, needle, replacement)
  end
  local temp_file = io.open(file .. '_temp', 'w')
  if not temp_file then
    vim.notify('Failed to open temporary file for writing', vim.log.levels.ERROR)
    return false
  end

  for line in io.lines(file) do
    if not line:match(needle) then
      temp_file:write(line .. '\n')
    else
      temp_file:write(replacement .. '\n')
    end
  end
  temp_file:close()
  os.rename(file .. '_temp', file)
  return true
end

return M
