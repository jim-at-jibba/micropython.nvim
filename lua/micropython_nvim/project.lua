local Stubs = require('micropython_nvim.stubs')
local Utils = require('micropython_nvim.utils')
local UI = require('micropython_nvim.ui')

local M = {}

M.TEMPLATES = {
  pyright_config = Stubs.PYRIGHT_CONFIG,

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

  gitignore = [[
.venv/
typings/
__pycache__/
*.pyc
]],
}

---@param project_name string
---@param stubs string stub requirement
---@return string
local function _generate_pyproject(project_name, stubs)
  return string.format(
    [[
[project]
name = "%s"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "mpremote",
    "ruff",
]

[tool.uv]
dev-dependencies = [
    "%s",
]
]],
    project_name,
    stubs
  )
end

---@param path string
---@param content string
---@return boolean
local function _write_file_safe(path, content)
  local result = vim.fn.writefile(vim.fn.split(content, '\n'), path)
  if result == -1 then
    vim.notify('Failed to write ' .. path, vim.log.levels.ERROR, { title = 'micropython.nvim' })
    return false
  end
  return true
end

---Install dependencies, then the declared stubs into typings/ for pyright
---@param cwd string
local function _run_uv_sync(cwd)
  vim.notify('Running uv sync...', vim.log.levels.INFO, { title = 'micropython.nvim' })
  vim.fn.jobstart('uv sync', {
    cwd = cwd,
    on_exit = function(_, code, _)
      vim.schedule(function()
        if code == 0 then
          vim.notify('Dependencies installed', vim.log.levels.INFO, { title = 'micropython.nvim' })
          local stubs = Stubs.find_requirement()
          if stubs then
            Stubs.install(stubs)
          end
        else
          vim.notify(
            'uv sync failed (exit ' .. code .. ')',
            vim.log.levels.ERROR,
            { title = 'micropython.nvim' }
          )
        end
      end)
    end,
  })
end

---@param cwd string
local function _prompt_uv_sync(cwd)
  if Utils.uv_available() then
    UI.select({ 'Yes', 'No' }, {
      prompt = 'Run `uv sync` to install dependencies?',
    }, function(choice)
      if choice == 'Yes' then
        _run_uv_sync(cwd)
      end
    end)
  else
    vim.notify(
      'uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh',
      vim.log.levels.INFO,
      { title = 'micropython.nvim' }
    )
  end
end

local function _check_legacy_files()
  if Utils.requirements_exists() then
    vim.notify(
      'Found legacy requirements.txt. Consider removing after migration.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
  end

  if Utils.ampy_config_exists() then
    vim.notify(
      'Found legacy .ampy file. Consider removing it.',
      vim.log.levels.WARN,
      { title = 'micropython.nvim' }
    )
  end
end

---@param stubs string stub requirement
local function _create_project_files(stubs)
  local cwd = Utils.get_cwd()
  local project_name = Utils.get_directory_name()

  local files_to_create = {
    {
      path = cwd .. '/pyproject.toml',
      content = _generate_pyproject(project_name, stubs),
      name = 'pyproject.toml',
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
    {
      path = cwd .. '/.gitignore',
      content = M.TEMPLATES.gitignore,
      name = '.gitignore',
    },
  }

  for _, file in ipairs(files_to_create) do
    _write_file_safe(file.path, file.content)
  end

  _check_legacy_files()

  vim.notify('Project created with ' .. stubs, vim.log.levels.INFO, { title = 'micropython.nvim' })

  _prompt_uv_sync(cwd)
end

local function _choose_stubs_and_create()
  Stubs.choose(function(choice)
    if not choice then
      vim.notify('Project init cancelled', vim.log.levels.INFO, { title = 'micropython.nvim' })
      return
    end
    _create_project_files(choice)
  end)
end

---@param force? boolean
function M.init(force)
  force = force or false
  local cwd = Utils.get_cwd()

  local files_to_check = {
    'pyproject.toml',
    'pyrightconfig.json',
    'main.py',
    '.micropython',
    '.gitignore',
  }

  local existing_files = {}
  for _, filename in ipairs(files_to_check) do
    if vim.fn.filereadable(cwd .. '/' .. filename) == 1 then
      table.insert(existing_files, filename)
    end
  end

  if #existing_files > 0 and not force then
    UI.select({ 'Yes', 'No' }, {
      prompt = 'Files exist (' .. table.concat(existing_files, ', ') .. '). Overwrite?',
    }, function(choice)
      if choice == 'Yes' then
        _choose_stubs_and_create()
      else
        vim.notify('Project init cancelled', vim.log.levels.INFO, { title = 'micropython.nvim' })
      end
    end)
    return
  end

  _choose_stubs_and_create()
end

function M.install()
  local cwd = Utils.get_cwd()

  if not Utils.uv_available() then
    vim.notify(
      'uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh',
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end

  if not Utils.pyproject_exists() then
    vim.notify(
      'No pyproject.toml found. Run :MPInit first.',
      vim.log.levels.ERROR,
      { title = 'micropython.nvim' }
    )
    return
  end

  _run_uv_sync(cwd)
end

return M
