local M = {}

---@class MicroPython.Subcommand
---@field desc string Shown in the :MP picker and used for the legacy alias description
---@field impl fun(args: string[]) Called with the arguments after the subcommand name
---@field complete? fun(arglead: string): string[] Completes the subcommand's own arguments

---@param name string
---@return fun(args: string[])
local function _facade(name)
  return function()
    require('micropython_nvim')[name]()
  end
end

---All :MP subcommands. New features register here (or via M.register).
---@type table<string, MicroPython.Subcommand>
M.subcommands = {
  run = { desc = 'Run current buffer on the device', impl = _facade('run') },
  run_main = { desc = 'Run main.py on the device', impl = _facade('run_main') },
  upload = { desc = 'Upload current buffer to the device', impl = _facade('upload_current') },
  upload_all = {
    desc = 'Upload all project files (arguments are extra names to ignore)',
    impl = function(args)
      require('micropython_nvim').upload_all({ args = table.concat(args, ' ') })
    end,
  },
  repl = { desc = 'Open the MicroPython REPL', impl = _facade('repl') },
  sync = { desc = 'Mount the project directory on the device', impl = _facade('sync') },
  reset = { desc = 'Soft reset the device', impl = _facade('soft_reset') },
  hard_reset = { desc = 'Hard reset the device', impl = _facade('hard_reset') },
  list_files = { desc = 'List files on the device', impl = _facade('list_files') },
  erase = { desc = 'Delete a file or folder from the device', impl = _facade('erase_one') },
  erase_all = { desc = 'Delete all files from the device', impl = _facade('erase_all') },
  init = { desc = 'Initialise a MicroPython project', impl = _facade('init') },
  install = { desc = 'Install project dependencies with uv', impl = _facade('install') },
  set_port = { desc = 'Set the device port', impl = _facade('set_port') },
  set_baud = { desc = 'Set the baud rate', impl = _facade('set_baud_rate') },
  set_stubs = { desc = 'Set MicroPython stubs for your board', impl = _facade('set_stubs') },
  list_devices = { desc = 'List connected MicroPython devices', impl = _facade('list_devices') },
  health = {
    desc = 'Run :checkhealth micropython_nvim',
    impl = function()
      vim.cmd('checkhealth micropython_nvim')
    end,
  },
}

---Pre-:MP commands, kept as aliases for their :MP subcommand
---@type table<string, string>
M.LEGACY_ALIASES = {
  MPRun = 'run',
  MPRunMain = 'run_main',
  MPUpload = 'upload',
  MPUploadAll = 'upload_all',
  MPRepl = 'repl',
  MPSync = 'sync',
  MPReset = 'reset',
  MPHardReset = 'hard_reset',
  MPListFiles = 'list_files',
  MPEraseOne = 'erase',
  MPEraseAll = 'erase_all',
  MPInit = 'init',
  MPInstall = 'install',
  MPSetPort = 'set_port',
  MPSetBaud = 'set_baud',
  MPSetStubs = 'set_stubs',
  MPListDevices = 'list_devices',
}

---@param name string
---@param subcommand MicroPython.Subcommand
function M.register(name, subcommand)
  M.subcommands[name] = subcommand
end

---@return string[]
function M.names()
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return names
end

---@param name string
---@param args string[]
local function _run(name, args)
  local subcommand = M.subcommands[name]
  if not subcommand then
    vim.notify(
      string.format('Unknown subcommand "%s". Available: %s', name, table.concat(M.names(), ', ')),
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end
  subcommand.impl(args)
end

---Run `:MP <subcommand> [args...]`; with no subcommand, pick one
---@param fargs string[]
function M.dispatch(fargs)
  if #fargs == 0 then
    require('micropython_nvim.ui').select(M.names(), { prompt = 'MicroPython:' }, function(choice)
      if not choice then
        return
      end
      _run(choice, {})
    end)
    return
  end

  _run(fargs[1], vim.list_slice(fargs, 2))
end

---Completion for :MP
---@param arglead string
---@param cmdline string
---@param cursorpos integer
---@return string[]
function M.complete(arglead, cmdline, cursorpos)
  local words = vim.split(cmdline:sub(1, cursorpos), '%s+', { trimempty = true })
  -- Words before the one being completed, excluding the command itself
  local completed = #words - 1 - (arglead == '' and 0 or 1)

  if completed == 0 then
    return vim.tbl_filter(function(name)
      return vim.startswith(name, arglead)
    end, M.names())
  end

  local subcommand = M.subcommands[words[2]]
  if subcommand and subcommand.complete then
    return subcommand.complete(arglead)
  end
  return {}
end

return M
