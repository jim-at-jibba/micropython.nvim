local Config = require('micropython_nvim.config')
local Mpremote = require('micropython_nvim.mpremote')
local Utils = require('micropython_nvim.utils')

local M = {}

---@class MicroPython.Board
---@field platform? string sys.platform, e.g. "rp2", "esp32", "pyboard"
---@field build? string Firmware build, e.g. "RPI_PICO_W" (MicroPython 1.22+)
---@field machine? string e.g. "Raspberry Pi Pico W with RP2040"
---@field version? string Release version, e.g. "1.24.1"; nil for preview builds

-- Prints one tab-separated line per field, so the output can be parsed reliably
local DETECT_SCRIPT = [[
import os, sys
v = sys.implementation.version
print('platform\t' + sys.platform)
print('build\t' + getattr(sys.implementation, '_build', ''))
print('machine\t' + os.uname().machine)
print('version\t%d.%d.%d\t%s' % (v[0], v[1], v[2], v[3] if len(v) > 3 else ''))
]]

-- Stub packages offered when picking manually (all published on PyPI)
M.PACKAGES = {
  'micropython-rp2-stubs',
  'micropython-rp2-rpi_pico-stubs',
  'micropython-rp2-rpi_pico_w-stubs',
  'micropython-rp2-rpi_pico2-stubs',
  'micropython-rp2-rpi_pico2_w-stubs',
  'micropython-esp32-stubs',
  'micropython-esp32-esp32_generic-stubs',
  'micropython-esp32-esp32_generic_c3-stubs',
  'micropython-esp32-esp32_generic_s2-stubs',
  'micropython-esp32-esp32_generic_s3-stubs',
  'micropython-esp8266-stubs',
  'micropython-stm32-stubs',
  'micropython-stm32-pybv11-stubs',
  'micropython-samd-stubs',
  'micropython-samd-seeed_wio_terminal-stubs',
  'micropython-nrf-stubs',
  'micropython-mimxrt-stubs',
  'micropython-unix-stubs',
  'micropython-windows-stubs',
  'micropython-webassembly-stubs',
}

-- sys.platform values whose stubs are published under another port name
local PORTS = {
  rp2 = 'rp2',
  esp32 = 'esp32',
  esp8266 = 'esp8266',
  pyboard = 'stm32',
  samd = 'samd',
  mimxrt = 'mimxrt',
  linux = 'unix',
  darwin = 'unix',
  win32 = 'windows',
  webassembly = 'webassembly',
}

local TYPINGS = 'typings'

-- pyright reads stubs from stubPath before its bundled CPython stdlib, so MicroPython's
-- `time`, `machine` etc. win over CPython's. The stubs themselves are not project code, so
-- they are excluded from checking (alongside pyright's default excludes)
local PYRIGHT_EXCLUDE = { TYPINGS, '**/node_modules', '**/__pycache__', '**/.*' }

M.PYRIGHT_CONFIG = string.format(
  [[
{
  "stubPath": "%s",
  "exclude": %s,
  "reportMissingModuleSource": false
}
]],
  TYPINGS,
  vim.json.encode(PYRIGHT_EXCLUDE):gsub(',', ', ')
)

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---Parse the output of the detection script
---@param output string
---@return MicroPython.Board
function M.parse_board(output)
  local board = {}
  for line in vim.gsplit(output, '\n') do
    local fields = vim.split((line:gsub('\r$', '')), '\t')
    local key, value = fields[1], fields[2]
    if key == 'version' then
      if value and value:match('^%d+%.%d+%.%d+$') and (fields[3] or '') == '' then
        board.version = value
      end
    elseif (key == 'platform' or key == 'build' or key == 'machine') and value and value ~= '' then
      board[key] = value
    end
  end
  return board
end

---Stub packages for a board, most specific first: the board package, then the port package
---@param board MicroPython.Board
---@return string[]
function M.packages_for(board)
  local platform = board.platform or ''
  local port = PORTS[platform] or (platform:match('^nrf') and 'nrf')
  if not port then
    return {}
  end

  local packages = {}
  if board.build then
    local name = board.build:gsub('%-.*$', ''):lower()
    table.insert(packages, string.format('micropython-%s-%s-stubs', port, name))
  end
  table.insert(packages, string.format('micropython-%s-stubs', port))
  return packages
end

---A requirement for a stub package, pinned to a MicroPython version when given
---@param package string
---@param version? string
---@return string
function M.requirement(package, version)
  if version then
    return string.format('%s==%s.*', package, version)
  end
  return package
end

---The stub requirement a project declares in pyproject.toml or requirements.txt
---@return string?
function M.find_requirement()
  local cwd = Utils.get_cwd()
  for _, file in ipairs({ 'pyproject.toml', 'requirements.txt' }) do
    local path = cwd .. '/' .. file
    if vim.fn.filereadable(path) == 1 then
      for _, line in ipairs(vim.fn.readfile(path)) do
        local requirement = line:match('(micropython%-[%w_%-]+%-stubs[^"%s,]*)')
        if requirement and not requirement:match('^micropython%-stdlib%-stubs') then
          return requirement
        end
      end
    end
  end
end

---Run a command, collecting its output
---@param argv string[]
---@param opts { cwd?: string }
---@param on_exit fun(result: MicroPython.MpremoteResult)
local function _job(argv, opts, on_exit)
  local stdout, stderr = {}, {}
  local ok, job = pcall(vim.fn.jobstart, argv, {
    cwd = opts.cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_stderr = function(_, data)
      stderr = data
    end,
    on_exit = function(_, code)
      on_exit({
        code = code,
        stdout = vim.trim(table.concat(stdout, '\n')),
        stderr = vim.trim(table.concat(stderr, '\n')),
      })
    end,
  })
  if not ok or job <= 0 then
    on_exit({ code = -1, stdout = '', stderr = argv[1] .. ' could not be started' })
  end
end

---Releases of a package on PyPI, as MicroPython versions
---@param package string
---@param on_versions fun(versions: table<string, true>|false|nil) false: not on PyPI, nil: unknown
local function _pypi_versions(package, on_versions)
  local url = 'https://pypi.org/pypi/' .. package .. '/json'
  _job({ 'curl', '-sSfL', '--max-time', '10', url }, {}, function(result)
    if result.code ~= 0 then
      if result.stderr:find('404', 1, true) then
        on_versions(false)
      else
        on_versions(nil)
      end
      return
    end
    local ok, data = pcall(vim.json.decode, result.stdout)
    if not ok or type(data) ~= 'table' or type(data.releases) ~= 'table' then
      on_versions(nil)
      return
    end
    local versions = {}
    for release in pairs(data.releases) do
      local version = release:match('^(%d+%.%d+%.%d+)')
      if version then
        versions[version] = true
      end
    end
    on_versions(versions)
  end)
end

---@param on_board fun(board?: MicroPython.Board)
local function _detect(on_board)
  if not Config.is_port_configured() then
    on_board(nil)
    return
  end
  Mpremote.run({ 'exec', DETECT_SCRIPT }, {
    on_exit = function(result)
      Utils.debug_print('board detection: ' .. vim.inspect(result))
      on_board(result.code == 0 and M.parse_board(result.stdout) or nil)
    end,
  })
end

---Stub requirements matching the connected board, checked against PyPI
---@param on_suggestions fun(suggestions: string[], board?: MicroPython.Board)
function M.suggest(on_suggestions)
  _detect(function(board)
    local packages = board and M.packages_for(board) or {}
    if #packages == 0 then
      on_suggestions({}, board)
      return
    end

    local found, pending = {}, #packages
    for i, package in ipairs(packages) do
      _pypi_versions(package, function(versions)
        if versions ~= false then
          local version = versions and board.version and versions[board.version] and board.version
          found[i] = M.requirement(package, version or nil)
        end
        pending = pending - 1
        if pending == 0 then
          local suggestions = {}
          for j = 1, #packages do
            table.insert(suggestions, found[j])
          end
          on_suggestions(suggestions, board)
        end
      end)
    end
  end)
end

---@param board? MicroPython.Board
---@return string
local function _prompt(board)
  if not board then
    return 'No device detected. Select stubs:'
  end
  local name = board.machine or board.platform or 'device'
  if board.version then
    name = string.format('%s, MicroPython %s', name, board.version)
  end
  return string.format('Stubs for %s:', name)
end

---Pick stubs: those matching the connected board first, then every known package
---@param on_choice fun(requirement?: string)
function M.choose(on_choice)
  M.suggest(function(suggestions, board)
    local items = vim.deepcopy(suggestions)
    local suggested = {}
    for _, requirement in ipairs(suggestions) do
      suggested[requirement:match('^[^=]+')] = true
    end
    for _, package in ipairs(M.PACKAGES) do
      if not suggested[package] then
        table.insert(items, package)
      end
    end
    require('micropython_nvim.ui').select(items, { prompt = _prompt(board) }, on_choice)
  end)
end

---Point pyright at typings/: add stubPath (and exclude typings/ when nothing is excluded yet)
---to pyrightconfig.json, or create one unless pyproject.toml configures pyright
function M.configure_pyright()
  local cwd = Utils.get_cwd()
  local path = cwd .. '/pyrightconfig.json'

  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path)
    local ok, config = pcall(vim.json.decode, table.concat(lines, '\n'))
    if not ok or type(config) ~= 'table' or config.stubPath then
      return
    end
    if vim.tbl_isempty(config) then
      lines = vim.split(vim.trim(M.PYRIGHT_CONFIG), '\n')
    else
      local open = 1
      while not lines[open]:find('{', 1, true) do
        open = open + 1
      end
      local before, after = lines[open]:match('^(.-{)(.*)$')
      local added = { before, string.format('  "stubPath": "%s",', TYPINGS) }
      if not config.exclude then
        table.insert(added, '  "exclude": ' .. vim.json.encode(PYRIGHT_EXCLUDE) .. ',')
      end
      if vim.trim(after) ~= '' then
        table.insert(added, after)
      end
      local rest = vim.list_slice(lines, open + 1)
      lines = vim.list_extend(vim.list_slice(lines, 1, open - 1), added)
      vim.list_extend(lines, rest)
    end
    vim.fn.writefile(lines, path)
    return
  end

  local pyproject = cwd .. '/pyproject.toml'
  if vim.fn.filereadable(pyproject) == 1 then
    for _, line in ipairs(vim.fn.readfile(pyproject)) do
      if line:match('^%s*%[tool%.pyright%]') then
        return
      end
    end
  end
  vim.fn.writefile(vim.split(vim.trim(M.PYRIGHT_CONFIG), '\n'), path)
end

---Remove a typings folder that holds stubs from an earlier install
---@param path string
local function _clear_typings(path)
  if #vim.fn.glob(path .. '/micropython_*stubs-*.dist-info', false, true) > 0 then
    vim.fn.delete(path, 'rf')
  end
end

---Install stubs into the project's typings folder, where pyright looks first
---@param requirement string
---@param on_done? fun(ok: boolean)
function M.install(requirement, on_done)
  local cwd = Utils.get_cwd()
  if not Utils.uv_available() then
    _notify(
      string.format(
        'uv not found. Install uv, or run: pip install --target %s %s',
        TYPINGS,
        requirement
      ),
      vim.log.levels.WARN
    )
    return
  end

  _clear_typings(cwd .. '/' .. TYPINGS)
  _notify(string.format('Installing %s into %s/...', requirement, TYPINGS), vim.log.levels.INFO)
  _job({ 'uv', 'pip', 'install', '--target', TYPINGS, requirement }, { cwd = cwd }, function(result)
    if result.code == 0 then
      _notify('Installed ' .. requirement, vim.log.levels.INFO)
    else
      _notify('Installing stubs failed:\n' .. Mpremote.error_output(result), vim.log.levels.ERROR)
    end
    if on_done then
      on_done(result.code == 0)
    end
  end)
end

return M
