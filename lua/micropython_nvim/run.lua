local Utils = require('micropython_nvim.utils')
local Mpremote = require('micropython_nvim.mpremote')
local Terminal = require('micropython_nvim.terminal')
local UI = require('micropython_nvim.ui')

local M = {}

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

function M.run()
  if not Utils.check_port_configured() then
    return
  end

  -- The REPL holds the serial port, so run through it when it is open
  local Repl = require('micropython_nvim.repl')
  if Repl.is_running() then
    Repl.run_buffer()
    return
  end

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = Mpremote.command({ 'run', file_path }) .. '; ' .. Utils.PRESS_ENTER_PROMPT
  Terminal.open(command)
end

function M.sync()
  if not Utils.check_port_configured() then
    return
  end

  local directory = Utils.get_cwd()
  local command = Mpremote.command({ 'mount', directory })
  Terminal.open(command)
end

function M.soft_reset()
  if not Utils.check_port_configured() then
    return
  end

  Mpremote.run({ 'soft_reset' }, { name = 'Soft reset' })
end

function M.hard_reset()
  if not Utils.check_port_configured() then
    return
  end

  Mpremote.run({ 'reset' }, { name = 'Hard reset' })
end

function M.erase_all()
  if not Utils.check_port_configured() then
    return
  end

  local command = Mpremote.command({ 'fs', 'rm', '-r', ':' })
    .. ' 2>&1; '
    .. Utils.PRESS_ENTER_PROMPT
  Terminal.open(command)
end

function M.erase_one()
  if not Utils.check_port_configured() then
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
  if not Utils.check_port_configured() then
    return
  end

  local command = Mpremote.command({ 'tree', ':' }) .. '; ' .. Utils.PRESS_ENTER_PROMPT
  Terminal.open(command)
end

---Run the project's local main.py, as the device would at boot
function M.run_main()
  if not Utils.check_port_configured() then
    return
  end

  local main = Utils.get_cwd() .. '/main.py'
  if vim.fn.filereadable(main) ~= 1 then
    vim.notify(
      'No main.py in ' .. Utils.get_cwd() .. '. Open Neovim at the project root.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
    return
  end

  local Repl = require('micropython_nvim.repl')
  if Repl.is_running() then
    Repl.run_lines(vim.fn.readfile(main))
    return
  end

  Terminal.open(Mpremote.command({ 'run', main }) .. '; ' .. Utils.PRESS_ENTER_PROMPT)
end

return M
