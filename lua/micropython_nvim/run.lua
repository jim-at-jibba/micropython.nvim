local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Terminal = require('toggleterm.terminal').Terminal

local M = {}

---@type table<string, boolean>
M.DEFAULT_IGNORE_LIST = {
  ['.git'] = true,
  ['requirements.txt'] = true,
  ['.ampy'] = true,
  ['.micropython'] = true,
  ['.vscode'] = true,
  ['.gitignore'] = true,
  ['project.pymakr'] = true,
  ['env'] = true,
  ['venv'] = true,
  ['__pycache__'] = true,
  ['.python-version'] = true,
  ['.micropy/'] = true,
  ['micropy.json'] = true,
  ['.idea'] = true,
  ['README.md'] = true,
  ['LICENSE'] = true,
}

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
  local command = Utils.get_mpremote_base() .. 'fs ls :'

  local ok, pfile = pcall(io.popen, command .. ' 2>/dev/null')
  if not ok or not pfile then
    vim.notify('Failed to list device files', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return files
  end

  for line in pfile:lines() do
    local filename = line:match('^%s*%d+%s+(.+)$')
    if filename then
      table.insert(files, filename)
    else
      local dirname = line:match('^%s*(.+)/$')
      if dirname then
        table.insert(files, dirname .. '/')
      end
    end
  end
  pfile:close()

  return files
end

---@param directory string
---@param ignore_list table<string, boolean>
---@param base_path? string
---@return string[]
local function _collect_files_recursive(directory, ignore_list, base_path)
  local files = {}
  base_path = base_path or directory
  local handle = vim.loop.fs_scandir(directory)

  if not handle then
    vim.notify('Cannot open ' .. directory, vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return files
  end

  while true do
    local name, file_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    if not ignore_list[name] then
      local full_path = directory .. '/' .. name
      local relative_path = full_path:sub(#base_path + 2)

      if file_type == 'directory' then
        local sub_files = _collect_files_recursive(full_path, ignore_list, base_path)
        for _, f in ipairs(sub_files) do
          table.insert(files, f)
        end
      else
        table.insert(files, { full = full_path, relative = relative_path })
      end
    else
      Utils.debug_print(string.format('Ignoring: %s', name))
    end
  end

  return files
end

function M.run()
  if not _check_port_configured() then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  local command =
    string.format('%srun "%s"; %s', Utils.get_mpremote_base(), file_path, Utils.PRESS_ENTER_PROMPT)
  local term = Terminal:new({ cmd = command, direction = 'float' })
  term:toggle()
end

function M.upload_current()
  if not _check_port_configured() then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  local filename = vim.fs.basename(file_path)
  local command = string.format('%scp "%s" :%s', Utils.get_mpremote_base(), file_path, filename)

  _async_job(command, 'Upload ' .. filename)
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
  local files = _collect_files_recursive(directory, ignore_list)

  if #files == 0 then
    vim.notify('No files to upload', vim.log.levels.WARN, { title = 'micropython.nvim' })
    return
  end

  local dirs_created = {}
  local commands = {}

  for _, file_info in ipairs(files) do
    local dir = vim.fs.dirname(file_info.relative)
    if dir and dir ~= '.' and not dirs_created[dir] then
      table.insert(
        commands,
        string.format('%sfs mkdir :%s 2>/dev/null || true', Utils.get_mpremote_base(), dir)
      )
      dirs_created[dir] = true
    end
    table.insert(
      commands,
      string.format('%scp "%s" :%s', Utils.get_mpremote_base(), file_info.full, file_info.relative)
    )
  end

  local long_command = table.concat(commands, ' && ')
  _async_job(long_command, 'Upload all (' .. #files .. ' files)')
end

function M.sync()
  if not _check_port_configured() then
    return
  end

  local directory = Utils.get_cwd()
  local command = string.format('%smount %s', Utils.get_mpremote_base(), directory)
  local term = Terminal:new({ cmd = command, direction = 'float' })
  term:toggle()
end

function M.soft_reset()
  if not _check_port_configured() then
    return
  end

  local command = Utils.get_mpremote_base() .. 'soft_reset'
  _async_job(command, 'Soft reset')
end

function M.hard_reset()
  if not _check_port_configured() then
    return
  end

  local command = Utils.get_mpremote_base() .. 'reset'
  _async_job(command, 'Hard reset')
end

function M.erase_all()
  if not _check_port_configured() then
    return
  end

  local command =
    string.format('%sfs rm -r : 2>&1; %s', Utils.get_mpremote_base(), Utils.PRESS_ENTER_PROMPT)
  local term = Terminal:new({ cmd = command, direction = 'float' })
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

    local is_dir = choice:match('/$')
    local cmd_type = is_dir and 'fs rm -r' or 'fs rm'
    local command = string.format('%s%s :%s', Utils.get_mpremote_base(), cmd_type, choice)
    _async_job(command, 'Delete ' .. choice)
  end)
end

function M.list_files()
  if not _check_port_configured() then
    return
  end

  local command =
    string.format('%sfs ls :; %s', Utils.get_mpremote_base(), Utils.PRESS_ENTER_PROMPT)
  local term = Terminal:new({ cmd = command, direction = 'float' })
  term:toggle()
end

function M.run_main()
  if not _check_port_configured() then
    return
  end

  local command =
    string.format('%sexec "import main"; %s', Utils.get_mpremote_base(), Utils.PRESS_ENTER_PROMPT)
  local term = Terminal:new({ cmd = command, direction = 'float' })
  term:toggle()
end

return M
