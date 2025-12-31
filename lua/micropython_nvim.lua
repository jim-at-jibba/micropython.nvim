local M = {}

---@param opts? MicroPython.Config
function M.setup(opts)
  require('micropython_nvim.config').setup(opts)
  require('micropython_nvim.utils').read_ampy_config()
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

---@return string
function M.statusline()
  local Config = require('micropython_nvim.config')
  return ' P:' .. Config.get_port() .. ' BR: ' .. Config.get_baud()
end

---@return boolean
function M.exists()
  return require('micropython_nvim.utils').ampy_config_exists()
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
