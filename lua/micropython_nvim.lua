local M = {}

---@param opts? MicroPython.Config
function M.setup(opts)
  require('micropython_nvim.config').setup(opts)
  require('micropython_nvim.utils').read_config()
  require('micropython_nvim.upload').setup_upload_on_save()
end

function M.run()
  require('micropython_nvim.run').run()
end

function M.repl()
  require('micropython_nvim.repl').open()
end

function M.repl_send_line()
  require('micropython_nvim.repl').send_line()
end

---@param line1 integer
---@param line2 integer
function M.repl_send_range(line1, line2)
  require('micropython_nvim.repl').send_range(line1, line2)
end

function M.repl_send_selection()
  require('micropython_nvim.repl').send_selection()
end

function M.repl_send_buffer()
  require('micropython_nvim.repl').send_buffer()
end

function M.repl_interrupt()
  require('micropython_nvim.repl').interrupt()
end

function M.upload_current()
  require('micropython_nvim.upload').upload_current()
end

---@param opts? MicroPython.UploadAllOptions
function M.upload_all(opts)
  require('micropython_nvim.upload').upload_all(opts)
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

function M.install()
  require('micropython_nvim.project').install()
end

function M.mount()
  require('micropython_nvim.run').mount()
end

---@deprecated Use `mount`
function M.sync()
  M.mount()
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

function M.files()
  require('micropython_nvim.files').open()
end

function M.info()
  require('micropython_nvim.device').info()
end

---@param args string[] package, then an optional target directory on the device
function M.mip(args)
  require('micropython_nvim.device').mip(args)
end

---@param args string[] an optional firmware version
function M.flash(args)
  require('micropython_nvim.flash').flash(args)
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
  return ' P:' .. port
end

---@return boolean
function M.exists()
  return require('micropython_nvim.utils').config_exists()
end

return M
