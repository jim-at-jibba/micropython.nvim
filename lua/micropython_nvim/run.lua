local nvim = vim.api -- alias for Neovim API
local M = {}

local utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal

--- Runs a MicroPython script on a device using ampy.
-- The script to run is the current buffer in Neovim.
-- The port and baud rate are taken from the global variables 'AMPY_PORT' and 'AMPY_BAUD'.
-- The command is run in a floating terminal.
function M.mprun()
  -- if not utils.ampy_install_check() then
  --   return
  -- end
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s run %s; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    nvim.nvim_buf_get_name(0),
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

local function upload_one(file_path)
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s put %s; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    file_path,
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

local function upload_all(directory, ignore_list)
  -- if not utils.ampy_install_check() then
  --   return
  -- endlocal directory_contents = io.popen("ls " .. project_dir)

  local handle = vim.loop.fs_scandir(directory)

  if handle == nil then
    print('Cannot open ' .. directory)
    return
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if name == nil then
      break
    end

    if ignore_list[name] then
      print('Ignoring: ' .. name)
    else
      local path = directory .. '/' .. name

      if type == 'directory' then
        upload_all(path, ignore_list)
      else
        print('uploadinging...', path)
        upload_one(path)
      end
    end
  end
end

--- Uploads the current buffer in Neovim to a MicroPython device using ampy.
-- The port and baud rate are taken from the global variables 'AMPY_PORT' and 'AMPY_BAUD'.
-- The command is run in a floating terminal.
function M.mp_upload_current()
  -- if not utils.ampy_install_check() then
  --   return
  -- end

  -- Get all lines in the buffer
  local buf = nvim.nvim_get_current_buf()
  local lines = nvim.nvim_buf_get_lines(buf, 0, -1, false)

  local filePath = '/tmp/main.py'

  local file = io.open(filePath, 'w+')
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. '\n')
    end
    file:close()
    upload_one(filePath)
    vim.notify('Upload successful', vim.log.levels.INFO)
  else
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
  end
end

--- This function uploads all files in the current directory to a MicroPython board.
function M.mp_upload_all(opt)
  local ignore_list = {
    ['.git'] = true,
    ['requirements.txt'] = true,
    ['.ampy'] = true,
    ['.vscode'] = true,
    ['.gitignore'] = true,
    ['project.pymakr'] = true,
    ['env'] = true,
    ['venv'] = true,
    ['__pycache__'] = true,
    ['.python-version'] = true,
    ['.micropy/'] = true,
    ['micropy.json'] = true,
  }

  if opt.args ~= nil and opt.args ~= '' then
    for word in string.gmatch(opt.args, '%S+') do
      ignore_list[word] = true
    end
  end
  local directory = vim.fn.getcwd()

  for k, v in pairs(ignore_list) do
    print('Ignore', k, v)
  end
  upload_all(directory, ignore_list)
end

function M.erase_all()
  local ampy_assembled_command = string.format(
    'ampy -p %s -b %s rmdir -r / 2>&1; %s',
    _G['AMPY_PORT'],
    _G['AMPY_BAUD'],
    utils.extra
  )
  local term = Terminal:new({ cmd = ampy_assembled_command, direction = 'float' })
  term:toggle()
end

return M
