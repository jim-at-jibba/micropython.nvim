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

local function assemble_command(path, type)
  return string.format('ampy -p %s -b %s %s %s', _G['AMPY_PORT'], _G['AMPY_BAUD'], type, path)
end

local function create_upload_all_commands_table(directory, ignore_list)
  local commands = {}

  local handle = vim.loop.fs_scandir(directory)

  if handle == nil then
    print('Cannot open ' .. directory)
    return commands
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if name == nil then
      break
    end

    if not ignore_list[name] then
      local path = directory .. '/' .. name

      if type == 'directory' then
        table.insert(commands, assemble_command(path, 'put'))
      else
        table.insert(commands, assemble_command(path, 'put'))
      end
    else
      utils.debugPrint(string.format('Ignoring: %s', name))
    end
  end

  return commands
end

local function create_delete_all_commands_table(directory, ignore_list)
  local commands = {}

  local handle = vim.loop.fs_scandir(directory)

  if handle == nil then
    print('Cannot open ' .. directory)
    return commands
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if name == nil then
      break
    end

    if not ignore_list[name] then
      local path = directory .. '/' .. name

      if type == 'directory' then
        table.insert(commands, assemble_command(path, 'put'))
      else
        table.insert(commands, assemble_command(path, 'put'))
      end
    else
      utils.debugPrint(string.format('Ignoring: %s', name))
    end
  end

  return commands
end

local function async_job(command, command_name)
  local job_id = vim.fn.jobstart(command, {
    on_exit = function(j, exit_status, _)
      if exit_status == 0 then
        vim.notify(command_name .. ' completed successfully', vim.log.levels.INFO)
      else
        utils.debugPrint('Job failed with exit status: ' .. exit_status)
      end
    end,
  })

  if job_id == 0 then
    vim.notify('Failed to run command job: ' .. command_name, vim.log.levels.ERROR)
  elseif job_id == -1 then
    vim.notify('Command not executable', vim.log.levels.ERROR)
  else
    vim.notify(command_name .. ' started', vim.log.levels.INFO)
  end
end

--- Uploads the current buffer in Neovim to a MicroPython device using ampy.
-- The port and baud rate are taken from the global variables 'AMPY_PORT' and 'AMPY_BAUD'.
-- The command is run in a floating terminal.
function M.mp_upload_current()
  local buf = nvim.nvim_get_current_buf()
  local lines = nvim.nvim_buf_get_lines(buf, 0, -1, false)

  local filePath = '/tmp/' .. vim.fs.basename(nvim.nvim_buf_get_name(0))

  local file = io.open(filePath, 'w+')
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. '\n')
    end
    file:close()
    async_job(assemble_command(filePath, 'put'), 'Upload current')
  else
    vim.notify('Failed to create temp file ' .. filePath, vim.log.levels.ERROR)
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

  -- this needs to return a list of commands, if a directory is found command should be to upload whole directory
  local commands = create_upload_all_commands_table(directory, ignore_list)

  local long_command = table.concat(commands, '; ')
  async_job(long_command, 'Upload all')
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

local function getFilesList()
  local files = {}
  local pfile

  local command = string.format('ampy -p %s -b %s ls', _G['AMPY_PORT'], _G['AMPY_BAUD'])
  pfile = io.popen(command)

  if pfile then
    for filename in pfile:lines() do
      table.insert(files, filename)
    end

    -- Close the file handle
    pfile:close()
  end

  return files
end

function M.erase_one()
  local files = getFilesList()

  vim.ui.select(files, {
    prompt = 'Select a file on device to delete:',
  }, function(choice)
    if not choice then
      print('No selection made')
      return
    end

    local extension = string.match(choice, '%.([^%.]+)$')
    if extension then
      local command = assemble_command(choice, 'rm')
      async_job(command, 'Delete file')
    else
      local command = assemble_command(choice, 'rmdir')
      async_job(command, 'Delete folder')
    end
  end)
end

return M
