local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')

local M = {}

---@class MicroPython.MpremoteOpts
---@field connect? boolean Add the configured port as a connect argument (default true)

---@class MicroPython.MpremoteResult
---@field code integer Exit code, or -1 if mpremote could not be started
---@field stdout string
---@field stderr string

---@class MicroPython.Device
---@field port string
---@field serial string
---@field manufacturer string

---@class MicroPython.MpremoteRunOpts: MicroPython.MpremoteOpts
---@field name? string Label for notifications; when set, start, success and failure are reported
---@field on_exit? fun(result: MicroPython.MpremoteResult)

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---@param lines string[]
---@return string
local function _join(lines)
  return vim.trim(table.concat(lines, '\n'))
end

---The most useful error text from a result: stderr, falling back to stdout
---@param result MicroPython.MpremoteResult
---@return string
function M.error_output(result)
  return result.stderr ~= '' and result.stderr or result.stdout
end

---@param name string
---@param result MicroPython.MpremoteResult
local function _report(name, result)
  if result.code == 0 then
    _notify(name .. ' completed successfully', vim.log.levels.INFO)
    return
  end

  local output = M.error_output(result)
  if output == '' then
    _notify(string.format('%s failed (exit code %d)', name, result.code), vim.log.levels.ERROR)
  else
    _notify(name .. ' failed:\n' .. output, vim.log.levels.ERROR)
  end
end

---Build the mpremote argv: uv-aware, with the configured port unless opts.connect is false
---@param args string[]
---@param opts? MicroPython.MpremoteOpts
---@return string[]
function M.argv(args, opts)
  opts = opts or {}
  local argv = Utils.is_uv_project() and { 'uv', 'run', 'mpremote' } or { 'mpremote' }

  local port = Config.get_port()
  if opts.connect ~= false and port ~= 'auto' and port ~= '' then
    vim.list_extend(argv, { 'connect', port })
  end

  return vim.list_extend(argv, args)
end

---Build a shell-escaped mpremote command string for use in a terminal
---@param args string[]
---@param opts? MicroPython.MpremoteOpts
---@return string
function M.command(args, opts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, M.argv(args, opts)), ' ')
end

---The error for an mpremote argv that could not be started, with an install hint
---@param argv string[]
---@return string
function M.not_found_message(argv)
  local hint = argv[1] == 'uv' and 'uv sync' or 'pip install mpremote'
  return string.format('mpremote not found (%s). Install with: %s', argv[1], hint)
end

---Run mpremote in the background without a shell
---@param args string[]
---@param opts? MicroPython.MpremoteRunOpts
---@return integer? job_id
function M.run(args, opts)
  opts = opts or {}
  local argv = M.argv(args, opts)
  Utils.debug_print('mpremote: ' .. table.concat(argv, ' '))

  local stdout, stderr = {}, {}
  local ok, job_id = pcall(vim.fn.jobstart, argv, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_stderr = function(_, data)
      stderr = data
    end,
    on_exit = function(_, code)
      local result = { code = code, stdout = _join(stdout), stderr = _join(stderr) }
      if opts.name then
        _report(opts.name, result)
      end
      if opts.on_exit then
        opts.on_exit(result)
      end
    end,
  })

  if not ok or job_id <= 0 then
    local msg = M.not_found_message(argv)
    if opts.name then
      _notify(msg, vim.log.levels.ERROR)
    end
    if opts.on_exit then
      opts.on_exit({ code = -1, stdout = '', stderr = msg })
    end
    return nil
  end

  if opts.name then
    _notify(opts.name .. ' started', vim.log.levels.INFO)
  end
  return job_id
end

---Run mpremote and wait for it to finish. Only for contexts that must block, like :checkhealth.
---@param args string[]
---@param opts? MicroPython.MpremoteOpts
---@param timeout_ms? integer Default 5000
---@return MicroPython.MpremoteResult
function M.run_sync(args, opts, timeout_ms)
  timeout_ms = timeout_ms or 5000
  local result
  local job_id = M.run(args, {
    connect = (opts or {}).connect,
    on_exit = function(r)
      result = r
    end,
  })

  vim.wait(timeout_ms, function()
    return result ~= nil
  end, 50)

  if not result then
    if job_id then
      pcall(vim.fn.jobstop, job_id)
    end
    return { code = -1, stdout = '', stderr = string.format('timed out after %dms', timeout_ms) }
  end
  return result
end

---Parse `mpremote connect list` output
---@param output string
---@return MicroPython.Device[]
function M.parse_device_list(output)
  local devices = {}
  for line in vim.gsplit(output, '\n') do
    local port, serial, manufacturer = line:match('^(%S+)%s+(%S+)%s+(.+)$')
    if port then
      table.insert(devices, { port = port, serial = serial, manufacturer = manufacturer })
    end
  end
  return devices
end

return M
