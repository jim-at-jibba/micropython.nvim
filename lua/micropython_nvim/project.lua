local requirementsTemplate = [[
adafruit-ampy
rshell
micropython-rp2-stubs==1.22.1.post2
ruff
]]
local pyrightConfigTemplate = [[
{
  "reportMissingModuleSource": false
}
]]
local ampyConfigTemplateEmpty = [[
AMPY_BAUD=115200
AMPY_PORT=/dev/ttyUSB0
# Fix for macOS users' "Could not enter raw repl"; try 2.0 and lower from there:
# AMPY_DELAY=0.5
]]

local blinkTemplate = [[
from machine import Pin
from time import sleep

led = Pin("LED", Pin.OUT)

while True:
    led.value(not led.value())
    print("LED is ON" if led.value() else "LED is OFF")
    sleep(0.5)
]]

local M = {}

-- This is the initialization function for the module.
-- It sets up the necessary state and resources for the module to function properly.
-- Call this function before using any other functions in the module.
function M.init()
  vim.fn.writefile(vim.fn.split(requirementsTemplate, '\n'), 'requirements.txt')
  vim.fn.writefile(vim.fn.split(pyrightConfigTemplate, '\n'), 'pyrightconfig.json')
  vim.fn.writefile(vim.fn.split(blinkTemplate, '\n'), 'main.py')
  vim.fn.writefile(vim.fn.split(ampyConfigTemplateEmpty, '\n'), '.ampy')
  vim.notify('Project created', vim.log.levels.INFO)
end

return M
