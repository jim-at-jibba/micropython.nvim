local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')

local M = {}

---@type string[]
M.BAUD_RATES = {
  '1200',
  '2400',
  '4800',
  '19200',
  '38400',
  '57600',
  '115200',
}

---@type string[]
M.STUB_OPTIONS = {
  'micropython-stm32-stubs',
  'micropython-esp32-stubs',
  'micropython-esp32-um-tinypico-stubs',
  'micropython-esp8266-stubs',
  'micropython-rp2-stubs',
  'micropython-rp2-pico-stubs',
  'micropython-rp2-pico-w-stubs',
  'micropython-windows-stubs',
  'micropython-unix-stubs',
  'micropython-Webassembly-stubs',
  'samd-seeed_wio_terminal',
}

---@return string[]
local function _get_ports_list()
  local ports = {}
  local patterns = {
    '/dev/ttyUSB*',
    '/dev/ttyACM*',
    '/dev/ttyS*',
    '/dev/tty.usbmodem*',
  }

  for _, pattern in ipairs(patterns) do
    local ok, pfile = pcall(io.popen, 'ls ' .. pattern .. ' 2>/dev/null')
    if ok and pfile then
      for filename in pfile:lines() do
        table.insert(ports, filename)
      end
      pfile:close()
    end
  end

  Utils.debug_print('ports: ' .. vim.inspect(ports))
  return ports
end

function M.set_baud_rate()
  vim.ui.select(M.BAUD_RATES, {
    prompt = 'Select baud rate:',
  }, function(choice)
    if not choice then
      return
    end

    Config.set_baud(choice)

    local ampy_path = Utils.get_ampy_path()
    local result = Utils.replace_line(ampy_path, 'AMPY_BAUD', 'AMPY_BAUD=' .. choice)
    if result then
      vim.notify(
        'Baud rate set to: ' .. choice,
        vim.log.levels.INFO,
        { title = 'micropython.nvim' }
      )
    else
      vim.notify('Failed to set baud rate', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    end
  end)
end

function M.set_port()
  local ports = _get_ports_list()

  if #ports == 0 then
    vim.notify('No serial ports found', vim.log.levels.WARN, { title = 'micropython.nvim' })
    return
  end

  vim.ui.select(ports, {
    prompt = 'Select a port:',
  }, function(choice)
    if not choice then
      return
    end

    Config.set_port(choice)

    local ampy_path = Utils.get_ampy_path()
    local result = Utils.replace_line(ampy_path, 'AMPY_PORT', 'AMPY_PORT=' .. choice)
    if result then
      vim.notify('Port set to: ' .. choice, vim.log.levels.INFO, { title = 'micropython.nvim' })
    else
      vim.notify('Failed to set port', vim.log.levels.ERROR, { title = 'micropython.nvim' })
    end
  end)
end

function M.set_stubs()
  vim.ui.select(M.STUB_OPTIONS, {
    prompt = 'Select stubs for board:',
  }, function(choice)
    if not choice then
      return
    end

    local requirements_path = Utils.get_cwd() .. '/requirements.txt'
    local result = Utils.replace_line(requirements_path, 'micropython-', choice)
    if result then
      vim.notify(
        'MicroPython stubs set to: ' .. choice,
        vim.log.levels.INFO,
        { title = 'micropython.nvim' }
      )
    else
      vim.notify(
        'Failed to set micropython stubs',
        vim.log.levels.ERROR,
        { title = 'micropython.nvim' }
      )
    end
  end)
end

return M
