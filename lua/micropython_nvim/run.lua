local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal

local M = {}

---@type table<string, boolean>
M.DEFAULT_IGNORE_LIST = {
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

---@param path string
---@param cmd_type string
---@return string
local function _assemble_command(path, cmd_type)
  return string.format(
    'ampy -p %s -b %s %s %s',
    Config.get_port(),
    Config.get_baud(),
    cmd_type,
    path
  )
end

---@param directory string
---@param ignore_list table<string, boolean>
---@return string[]
local function _create_upload_commands(directory, ignore_list)
  local commands = {}
  local handle = vim.loop.fs_scandir(directory)

  if not handle then
    vim.notify('Cannot open ' .. directory, vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return commands
  end

  while true do
    local name, _ = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    if not ignore_list[name] then
      local path = directory .. '/' .. name
      table.insert(commands, _assemble_command(path, 'put'))
    else
      Utils.debug_print(string.format('Ignoring: %s', name))
    end
  end

  return commands
end

---@param command string
---@param command_name string
local function _async_job(command, command_name)
  local job_id = vim.fn.jobstart(command, {
    on_exit = function(_, exit_status, _)
      if exit_status == 0 then
        vim.notify(
          command_name .. ' completed successfully',
          vim.log.levels.INFO,
          { title = 'micropython.nvim' }
        )
      else
        Utils.debug_print('Job failed with exit status: ' .. exit_status)
        vim.notify(command_name .. ' failed', vim.log.levels.ERROR, { title = 'micropython.nvim' })
      end
    end,
  })

  if job_id == 0 then
    vim.notify(
      'Failed to run command job: ' .. command_name,
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
  elseif job_id == -1 then
    vim.notify('Command not executable', vim.log.levels.ERROR, { title = 'micropython.nvim' })
  else
    vim.notify(command_name .. ' started', vim.log.levels.INFO, { title = 'micropython.nvim' })
  end
end

---@return boolean
local function _check_port_configured()
  if not Config.is_port_configured() then
    vim.notify(
      'No port configured. Run :MPSetPort first.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return false
  end
  return true
end

---@return string[]
local function _get_device_files()
  local files = {}
  local command = string.format('ampy -p %s -b %s ls', Config.get_port(), Config.get_baud())

  local ok, pfile = pcall(io.popen, command)
  if not ok or not pfile then
    vim.notify('Failed to list device files', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return files
  end

  for filename in pfile:lines() do
    table.insert(files, filename)
  end
  pfile:close()

  return files
end

function M.run()
  if not _check_port_configured() then
    return
  end

  local ampy_command = string.format(
    'ampy -p %s -b %s run %s; %s',
    Config.get_port(),
    Config.get_baud(),
    vim.api.nvim_buf_get_name(0),
    Utils.PRESS_ENTER_PROMPT
  )
  local term = Terminal:new({ cmd = ampy_command, direction = 'float' })
  term:toggle()
end

function M.upload_current()
  if not _check_port_configured() then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local file_path = '/tmp/' .. vim.fs.basename(vim.api.nvim_buf_get_name(0))

  local file = io.open(file_path, 'w+')
  if not file then
    vim.notify(
      'Failed to create temp file ' .. file_path,
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end

  for _, line in ipairs(lines) do
    file:write(line .. '\n')
  end
  file:close()

  _async_job(_assemble_command(file_path, 'put'), 'Upload current')
end

---@class MicroPython.UploadAllOptions
---@field args? string Space-separated list of files/folders to ignore

---@param opts? MicroPython.UploadAllOptions
function M.upload_all(opts)
  if not _check_port_configured() then
    return
  end

  opts = opts or {}
  local ignore_list = vim.tbl_extend('force', {}, M.DEFAULT_IGNORE_LIST)

  if opts.args and opts.args ~= '' then
    for word in string.gmatch(opts.args, '%S+') do
      ignore_list[word] = true
    end
  end

  local directory = Utils.get_cwd()
  local commands = _create_upload_commands(directory, ignore_list)

  if #commands == 0 then
    vim.notify('No files to upload', vim.log.levels.WARN, { title = 'micropython.nvim' })
    return
  end

  local long_command = table.concat(commands, '; ')
  _async_job(long_command, 'Upload all')
end

function M.erase_all()
  if not _check_port_configured() then
    return
  end

  local ampy_command = string.format(
    'ampy -p %s -b %s rmdir -r / 2>&1; %s',
    Config.get_port(),
    Config.get_baud(),
    Utils.PRESS_ENTER_PROMPT
  )
  local term = Terminal:new({ cmd = ampy_command, direction = 'float' })
  term:toggle()
end

function M.erase_one()
  if not _check_port_configured() then
    return
  end

  local files = _get_device_files()

  if #files == 0 then
    vim.notify('No files found on device', vim.log.levels.WARN, { title = 'micropython.nvim' })
    return
  end

  vim.ui.select(files, {
    prompt = 'Select a file on device to delete:',
  }, function(choice)
    if not choice then
      return
    end

    local extension = string.match(choice, '%.([^%.]+)$')
    local cmd_type = extension and 'rm' or 'rmdir'
    local command = _assemble_command(choice, cmd_type)
    _async_job(command, 'Delete ' .. (extension and 'file' or 'folder'))
  end)
end

return M
