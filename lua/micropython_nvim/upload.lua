local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')

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

local AUGROUP = 'micropython_nvim_upload_on_save'

---@class MicroPython.UploadFile
---@field full string Local path
---@field relative string Path on the device, relative to its root

---The ignore list: defaults plus space-separated extra names or project-relative paths
---@param extra? string
---@return table<string, boolean>
local function _ignore_set(extra)
  local ignore = {}
  for name in pairs(M.DEFAULT_IGNORE_LIST) do
    ignore[(name:gsub('/+$', ''))] = true
  end
  for word in string.gmatch(extra or '', '%S+') do
    ignore[(word:gsub('/+$', ''))] = true
  end
  return ignore
end

---Whether a project-relative path, or any directory above it, is ignored by name or by path
---@param relative string
---@param ignore table<string, boolean>
---@return boolean
local function _is_ignored(relative, ignore)
  local prefix
  for _, name in ipairs(vim.split(relative, '/', { plain = true })) do
    prefix = prefix and (prefix .. '/' .. name) or name
    if ignore[name] or ignore[prefix] then
      return true
    end
  end
  return false
end

---@param root string
---@param ignore table<string, boolean>
---@param directory? string project-relative directory being scanned
---@return MicroPython.UploadFile[]
local function _collect_files(root, ignore, directory)
  local files = {}
  local path = directory and (root .. '/' .. directory) or root
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    vim.notify('Cannot open ' .. path, vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return files
  end

  while true do
    local name, file_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    local relative = directory and (directory .. '/' .. name) or name
    if _is_ignored(relative, ignore) then
      Utils.debug_print('Ignoring: ' .. relative)
    elseif file_type == 'directory' then
      vim.list_extend(files, _collect_files(root, ignore, relative))
    else
      table.insert(files, { full = root .. '/' .. relative, relative = relative })
    end
  end

  return files
end

---Directories that must exist on the device before the files are copied, parents first
---@param files MicroPython.UploadFile[]
---@return string[]
local function _parent_dirs(files)
  local seen, dirs = {}, {}
  for _, file in ipairs(files) do
    local dir = vim.fs.dirname(file.relative)
    while dir and dir ~= '.' and dir ~= '' and not seen[dir] do
      seen[dir] = true
      table.insert(dirs, dir)
      dir = vim.fs.dirname(dir)
    end
  end
  -- Parents sort before their children
  table.sort(dirs)
  return dirs
end

---@param s string
---@return string
local function _python_string(s)
  return "'" .. s:gsub('\\', '\\\\'):gsub("'", "\\'"):gsub('\n', '\\n') .. "'"
end

---Python that creates directories on the device, skipping any that already exist.
---Used instead of `fs mkdir`, which aborts the whole command when a directory exists.
---@param dirs string[]
---@return string
local function _mkdirs_code(dirs)
  local quoted = vim.tbl_map(_python_string, dirs)
  return table.concat({
    'import os',
    'for d in (' .. table.concat(quoted, ', ') .. ',):',
    ' try:',
    '  os.mkdir(d)',
    ' except OSError:',
    '  pass',
  }, '\n')
end

---One mpremote command that creates the needed directories and copies the files.
---cp skips files whose SHA256 already matches the device copy.
---@param files MicroPython.UploadFile[]
---@return string[]
local function _upload_args(files)
  local args = {}
  local dirs = _parent_dirs(files)
  if #dirs > 0 then
    vim.list_extend(args, { 'exec', _mkdirs_code(dirs) })
  end
  for _, file in ipairs(files) do
    if #args > 0 then
      table.insert(args, '+')
    end
    vim.list_extend(args, { 'cp', file.full, ':' .. file.relative })
  end
  return args
end

---The path of a file relative to the project root, or nil when it is outside the project
---@param path string
---@return string?
local function _project_relative(path)
  local root = vim.fs.normalize(Utils.get_cwd())
  path = vim.fs.normalize(path)
  if vim.startswith(path, root .. '/') then
    return path:sub(#root + 2)
  end
end

---@param path string
local function _upload_file(path)
  local relative = _project_relative(path) or vim.fs.basename(path)
  local args = _upload_args({ { full = path, relative = relative } })
  Mpremote.run(args, { name = 'Upload ' .. relative })
end

---Upload the current buffer to its project-relative path on the device
function M.upload_current()
  if not Utils.check_port_configured() then
    return
  end
  _upload_file(vim.api.nvim_buf_get_name(0))
end

---@class MicroPython.UploadAllOptions
---@field args? string Space-separated list of file/folder names or project paths to ignore

---Upload every project file that is not ignored, keeping the directory layout
---@param opts? MicroPython.UploadAllOptions
function M.upload_all(opts)
  if not Utils.check_port_configured() then
    return
  end

  opts = opts or {}
  local files = _collect_files(Utils.get_cwd(), _ignore_set(opts.args))
  if #files == 0 then
    vim.notify('No files to upload', vim.log.levels.WARN, { title = 'micropython.nvim' })
    return
  end

  Mpremote.run(_upload_args(files), { name = 'Upload all (' .. #files .. ' files)' })
end

---@param path string
local function _on_save(path)
  if not (Utils.config_exists() or Utils.ampy_config_exists()) then
    return
  end
  local relative = _project_relative(path)
  if not relative or _is_ignored(relative, _ignore_set()) then
    return
  end
  if not Config.is_port_configured() then
    return
  end
  _upload_file(path)
end

---Upload project files when they are written, if `upload_on_save` is enabled
function M.setup_upload_on_save()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  if not Config.config.upload_on_save then
    return
  end
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    desc = 'micropython.nvim: upload on save',
    callback = function(event)
      _on_save(event.match)
    end,
  })
end

return M
