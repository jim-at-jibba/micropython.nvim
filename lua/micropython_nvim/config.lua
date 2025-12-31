---@class MicroPython.Config
---@field port? string Device port (e.g., "/dev/ttyUSB0", "auto", or "id:<serial>")
---@field baud? number Baud rate for serial communication (optional, mpremote auto-detects)
---@field debug? boolean Enable debug logging

---@class MicroPython.State
---@field port string Current device port
---@field baud string Baud rate as string (for command assembly)
---@field initialized boolean

local M = {}

---@type MicroPython.Config
local defaults = {
  port = 'auto',
  baud = 115200,
  debug = false,
}

---@type MicroPython.Config
M.config = {}

---@type MicroPython.State
M.state = {
  port = 'auto',
  baud = '115200',
  initialized = false,
}

---@param opts? MicroPython.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})
  M.state.port = tostring(M.config.port)
  M.state.baud = tostring(M.config.baud)
end

---@return string
function M.get_port()
  return M.state.port
end

---@param port string
function M.set_port(port)
  M.state.port = port
end

---@return string
function M.get_baud()
  return M.state.baud
end

---@param baud string
function M.set_baud(baud)
  M.state.baud = baud
end

---@return boolean
function M.is_debug()
  return M.config.debug == true
end

---@return boolean
function M.is_port_configured()
  return M.state.port ~= nil and M.state.port ~= ''
end

---@return string
function M.get_connect_arg()
  local port = M.state.port
  if port == 'auto' or port == '' then
    return ''
  end
  return 'connect ' .. port
end

return M
