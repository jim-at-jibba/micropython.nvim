local Utils = require('micropython_nvim.utils')

local M = {}

M.TEMPLATES = {
  requirements = [[
adafruit-ampy
rshell
micropython-rp2-stubs==1.22.1.post2
ruff
]],

  pyright_config = [[
{
  "reportMissingModuleSource": false
}
]],

  ampy_config = [[
AMPY_BAUD=115200
AMPY_PORT=/dev/ttyUSB0
# Fix for macOS users' "Could not enter raw repl"; try 2.0 and lower from there:
# AMPY_DELAY=0.5
]],

  main = [[
from machine import Pin
from time import sleep

led = Pin("LED", Pin.OUT)

while True:
    led.value(not led.value())
    print("LED is ON" if led.value() else "LED is OFF")
    sleep(0.5)
]],
}

function M.init()
  local cwd = Utils.get_cwd()

  vim.fn.writefile(vim.fn.split(M.TEMPLATES.requirements, '\n'), cwd .. '/requirements.txt')
  vim.fn.writefile(vim.fn.split(M.TEMPLATES.pyright_config, '\n'), cwd .. '/pyrightconfig.json')
  vim.fn.writefile(vim.fn.split(M.TEMPLATES.main, '\n'), cwd .. '/main.py')
  vim.fn.writefile(vim.fn.split(M.TEMPLATES.ampy_config, '\n'), cwd .. '/.ampy')

  vim.notify('Project created', vim.log.levels.INFO, { title = 'micropython.nvim' })
end

return M
