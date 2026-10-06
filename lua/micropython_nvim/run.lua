local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')
local UI = require('micropython_nvim.ui')

local M = {}

---@type table<string, boolean>
M.DEFAULT_IGNORE_LIST = {
  ['.git'] = true,
  ['pyproject.toml'] = true,
  ['uv.lock'] = true,
  ['requirements.txt'] = true,
  ['.ampy'] = true,
  ['.micropython'] = true,
  ['.vscode'] = true,
  ['.gitignore'] = true,
  ['project.pymakr'] = true,
  ['env'] = true,
  ['venv'] = true,
  ['.venv'] = true,
  ['__pycache__'] = true,
  ['.python-version'] = true,
  ['.micropy/'] = true,
  ['micropy.json'] = true,
  ['.idea'] = true,
  ['README.md'] = true,
  ['LICENSE'] = true,
}

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

---@param on_files fun(files: string[])
local function _get_device_files(on_files)
  Mpremote.run({ 'fs', 'ls', ':' }, {
    on_exit = function(result)
      if result.code ~= 0 then
        vim.notify(
          'Failed to list device files:\n' .. Mpremote.error_output(result),
          vim.log.levels.ERROR,
          { title = 'micropython.nvim' }
        )
        return
      end

      local files = {}
      for line in vim.gsplit(result.stdout, '\n') do
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
      on_files(files)
    end,
  })
end

---Append an mpremote command to a chain, joining commands with '+'
---@param args string[]
---@param command string[]
local function _chain(args, command)
  if #args > 0 then
    table.insert(args, '+')
  end
  vim.list_extend(args, command)
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
  local command = Mpremote.command({ 'run', file_path }) .. '; ' .. Utils.PRESS_ENTER_PROMPT
  Snacks.terminal(command)
end

function M.upload_current()
  if not _check_port_configured() then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  local filename = vim.fs.basename(file_path)
  Mpremote.run({ 'cp', file_path, ':' .. filename }, { name = 'Upload ' .. filename })
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
  local args = {}

  for _, file_info in ipairs(files) do
    local dir = vim.fs.dirname(file_info.relative)
    if dir and dir ~= '.' and not dirs_created[dir] then
      _chain(args, { 'fs', 'mkdir', ':' .. dir })
      dirs_created[dir] = true
    end
    _chain(args, { 'cp', file_info.full, ':' .. file_info.relative })
  end

  Mpremote.run(args, { name = 'Upload all (' .. #files .. ' files)' })
end

function M.sync()
  if not _check_port_configured() then
    return
  end

  local directory = Utils.get_cwd()
  local command = Mpremote.command({ 'mount', directory })
  Snacks.terminal(command)
end

function M.soft_reset()
  if not _check_port_configured() then
    return
  end

  Mpremote.run({ 'soft_reset' }, { name = 'Soft reset' })
end

function M.hard_reset()
  if not _check_port_configured() then
    return
  end

  Mpremote.run({ 'reset' }, { name = 'Hard reset' })
end

function M.erase_all()
  if not _check_port_configured() then
    return
  end

  local command = Mpremote.command({ 'fs', 'rm', '-r', ':' })
    .. ' 2>&1; '
    .. Utils.PRESS_ENTER_PROMPT
  Snacks.terminal(command)
end

function M.erase_one()
  if not _check_port_configured() then
    return
  end

  _get_device_files(function(files)
    if #files == 0 then
      vim.notify('No files found on device', vim.log.levels.WARN, { title = 'micropython.nvim' })
      return
    end

    UI.select(files, {
      prompt = 'Select a file on device to delete:',
    }, function(choice)
      if not choice then
        return
      end

      local is_dir = choice:match('/$')
      local args = is_dir and { 'fs', 'rm', '-r', ':' .. choice } or { 'fs', 'rm', ':' .. choice }
      Mpremote.run(args, { name = 'Delete ' .. choice })
    end)
  end)
end

function M.list_files()
  if not _check_port_configured() then
    return
  end

  local command = Mpremote.command({ 'tree', ':' }) .. '; ' .. Utils.PRESS_ENTER_PROMPT
  Snacks.terminal(command)
end

function M.run_main()
  if not _check_port_configured() then
    return
  end

  local command = Mpremote.command({ 'exec', "exec(open('main.py').read())" })
    .. '; '
    .. Utils.PRESS_ENTER_PROMPT
  Snacks.terminal(command)
end

return M
