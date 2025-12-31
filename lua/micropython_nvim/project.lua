local Utils = require('micropython_nvim.utils')

local M = {}

M.TEMPLATES = {
  requirements = [[
mpremote
micropython-rp2-stubs==1.22.1.post2
ruff
]],

  pyright_config = [[
{
  "reportMissingModuleSource": false
}
]],

  micropython_config = [[
# MicroPython project configuration
# PORT can be: auto, /dev/ttyUSB0, /dev/ttyACM0, id:<serial>, etc.
PORT=auto
# BAUD is optional - mpremote auto-detects, but can be set for edge cases
BAUD=115200
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

---@param path string
---@param content string
---@param force boolean
---@return boolean
local function _write_file_safe(path, content, force)
  if not force and vim.fn.filereadable(path) == 1 then
    return false
  end
  vim.fn.writefile(vim.fn.split(content, '\n'), path)
  return true
end

---@param force? boolean
function M.init(force)
  force = force or false
  local cwd = Utils.get_cwd()

  local files_to_create = {
    {
      path = cwd .. '/requirements.txt',
      content = M.TEMPLATES.requirements,
      name = 'requirements.txt',
    },
    {
      path = cwd .. '/pyrightconfig.json',
      content = M.TEMPLATES.pyright_config,
      name = 'pyrightconfig.json',
    },
    { path = cwd .. '/main.py', content = M.TEMPLATES.main, name = 'main.py' },
    {
      path = cwd .. '/.micropython',
      content = M.TEMPLATES.micropython_config,
      name = '.micropython',
    },
  }

  local existing_files = {}
  for _, file in ipairs(files_to_create) do
    if vim.fn.filereadable(file.path) == 1 then
      table.insert(existing_files, file.name)
    end
  end

  if #existing_files > 0 and not force then
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = 'Files exist (' .. table.concat(existing_files, ', ') .. '). Overwrite?',
    }, function(choice)
      if choice == 'Yes' then
        M.init(true)
      else
        vim.notify('Project init cancelled', vim.log.levels.INFO, { title = 'micropython.nvim' })
      end
    end)
    return
  end

  for _, file in ipairs(files_to_create) do
    _write_file_safe(file.path, file.content, true)
  end

  if Utils.ampy_config_exists() then
    vim.notify(
      'Found legacy .ampy file. Consider removing it.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
  end

  vim.notify('Project created', vim.log.levels.INFO, { title = 'micropython.nvim' })
end

return M
