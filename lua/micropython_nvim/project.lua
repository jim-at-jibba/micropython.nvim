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
-- AMPY_PORT=
-- AMPY_BAUD=
-- # Fix for macOS users' "Could not enter raw repl"; try 2.0 and lower from there:
-- AMPY_DELAY=0.5
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

function M.init()
  -- local projectPath = vim.fn.input('Enter project path: ')
  -- local projectPath = vim.fn.expand(projectPath)
  -- vim.fn.mkdir(projectPath, 'p')
  -- vim.fn.chdir(projectPath)

  vim.fn.writefile(vim.fn.split(requirementsTemplate, '\n'), 'requirements.txt')
  vim.fn.writefile(vim.fn.split(pyrightConfigTemplate, '\n'), 'pyrightconfig.json')
  vim.fn.writefile(vim.fn.split(blinkTemplate, '\n'), 'main.py')
  vim.fn.writefile(vim.fn.split(ampyConfigTemplateEmpty, '\n'), '.ampy')
  -- print('Creating ampy config file', _G['AMPY_PORT'], _G['AMPY_BAUD'], _G['AMPY_DELAY'])
  -- createAmpyConfig()
  vim.notify('Project created', vim.log.levels.INFO)
end

return M
