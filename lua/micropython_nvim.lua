local M = {}

---@param opts? MicroPython.Config
function M.setup(opts)
  require('micropython_nvim.config').setup(opts)
  require('micropython_nvim.utils').read_config()
end

function M.run()
  require('micropython_nvim.run').run()
end

function M.repl()
  require('micropython_nvim.repl').open()
end

function M.upload_current()
  require('micropython_nvim.run').upload_current()
end

---@param opts? MicroPython.UploadAllOptions
function M.upload_all(opts)
  require('micropython_nvim.run').upload_all(opts)
end

function M.set_baud_rate()
  require('micropython_nvim.setup').set_baud_rate()
end

function M.set_port()
  require('micropython_nvim.setup').set_port()
end

function M.set_stubs()
  require('micropython_nvim.setup').set_stubs()
end

function M.erase_all()
  require('micropython_nvim.run').erase_all()
end

function M.erase_one()
  require('micropython_nvim.run').erase_one()
end

function M.init()
  require('micropython_nvim.project').init()
end

function M.sync()
  require('micropython_nvim.run').sync()
end

function M.soft_reset()
  require('micropython_nvim.run').soft_reset()
end

function M.hard_reset()
  require('micropython_nvim.run').hard_reset()
end

function M.list_devices()
  require('micropython_nvim.setup').show_devices()
end

function M.list_files()
  require('micropython_nvim.run').list_files()
end

function M.run_main()
  require('micropython_nvim.run').run_main()
end

---@return string
function M.statusline()
  local Config = require('micropython_nvim.config')
  local port = Config.get_port()
  if port == 'auto' then
    return ' auto'
  end
  return ' P:' .. port .. ' BR:' .. Config.get_baud()
end

---@return boolean
function M.exists()
  local Utils = require('micropython_nvim.utils')
  return Utils.config_exists() or Utils.ampy_config_exists()
end

---@deprecated Use setup() instead
function M.initialise()
  vim.notify(
    'initialise() is deprecated, use setup() instead',
    vim.log.levels.WARN,
    { title = 'micropython.nvim' }
  )
  M.setup()
end

return M
