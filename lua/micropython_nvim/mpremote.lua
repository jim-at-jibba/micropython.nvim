local Config = require('micropython_nvim.config')
local Utils = require('micropython_nvim.utils')

local M = {}

---@class MicroPython.MpremoteOpts
---@field connect? boolean Add the configured port as a connect argument (default true)

---@class MicroPython.MpremoteResult
---@field code integer Exit code, or -1 if mpremote could not be started
---@field stdout string
---@field stderr string

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
    local hint = argv[1] == 'uv' and 'uv sync' or 'pip install mpremote'
    local msg = string.format('mpremote not found (%s). Install with: %s', argv[1], hint)
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

return M
