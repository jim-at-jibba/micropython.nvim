local M = {}

---@class MicroPython.Subcommand
---@field desc string Shown in the :MP picker and used for the legacy alias description
---@field impl fun(args: string[], range?: MicroPython.Range) Called with the arguments after the subcommand name
---@field complete? fun(arglead: string): string[] Completes the subcommand's own arguments
---@field range? boolean Accepts a line range, as in :'<,'>MP send

---@class MicroPython.Range
---@field line1 integer
---@field line2 integer

---@param name string
---@return fun(args: string[])
local function _facade(name)
  return function()
    require('micropython_nvim')[name]()
  end
end

---All :MP subcommands. New features add an entry here.
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
  send = {
    desc = 'Send the current line, or a range of lines, to the REPL',
    range = true,
    impl = function(_, range)
      if range then
        require('micropython_nvim').repl_send_range(range.line1, range.line2)
      else
        require('micropython_nvim').repl_send_line()
      end
    end,
  },
  send_buffer = { desc = 'Send the whole buffer to the REPL', impl = _facade('repl_send_buffer') },
  interrupt = { desc = 'Stop running code on the device', impl = _facade('repl_interrupt') },
  info = {
    desc = 'Show firmware, board, storage and clock of the device',
    impl = _facade('info'),
  },
  mip = {
    desc = 'Install a package on the device: mip <package> [target directory]',
    impl = function(args)
      require('micropython_nvim').mip(args)
    end,
    complete = function(arglead)
      return require('micropython_nvim.device').mip_complete(arglead)
    end,
  },
  sync = { desc = 'Mount the project directory on the device', impl = _facade('sync') },
  reset = { desc = 'Soft reset the device', impl = _facade('soft_reset') },
  hard_reset = { desc = 'Hard reset the device', impl = _facade('hard_reset') },
  list_files = { desc = 'List files on the device', impl = _facade('list_files') },
  files = { desc = 'Browse and edit files on the device', impl = _facade('files') },
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

---@return string[]
function M.names()
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return names
end

---@param name string
---@param args string[]
---@param range? MicroPython.Range
local function _run(name, args, range)
  local subcommand = M.subcommands[name]
  if not subcommand then
    vim.notify(
      string.format('Unknown subcommand "%s". Available: %s', name, table.concat(M.names(), ', ')),
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end
  if range and not subcommand.range then
    vim.notify(
      string.format('"%s" does not take a line range', name),
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end
  subcommand.impl(args, range)
end

---Run `:[range]MP <subcommand> [args...]`; with no subcommand, pick one
---@param fargs string[]
---@param range? MicroPython.Range Lines given to :MP, if any
function M.dispatch(fargs, range)
  if #fargs == 0 then
    require('micropython_nvim.ui').select(M.names(), { prompt = 'MicroPython:' }, function(choice)
      if not choice then
        return
      end
      _run(choice, {})
    end)
    return
  end

  _run(fargs[1], vim.list_slice(fargs, 2), range)
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
