local Mpremote = require('micropython_nvim.mpremote')
local Utils = require('micropython_nvim.utils')

local M = {}

local CTRL_C = '\3'
local CTRL_D = '\4'
local CTRL_E = '\5'
local ENTER = '\r'
local SPLIT_HEIGHT = 15
-- Sent in small pieces so a device's serial receive buffer is not overrun
local CHUNK_SIZE = 128
local CHUNK_DELAY_MS = 20

local state = {
  ---@type integer?
  buf = nil,
  ---@type integer?
  job = nil,
  -- mpremote ignores input until it has connected; text waits for its first output
  ready = false,
  ---@type string[]
  pending = {},
  -- Chunks still to be written, in order
  ---@type string[]
  outbox = {},
  sending = false,
}

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---@return boolean
function M.is_running()
  return state.job ~= nil and vim.fn.jobwait({ state.job }, 0)[1] == -1
end

---@param buf integer
---@return integer?
local function _window_for(buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
end

---Keep the REPL scrolled to its latest output
local function _scroll_to_end()
  local win = state.buf and _window_for(state.buf)
  if win then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(state.buf), 0 })
  end
end

local function _write_next_chunk()
  if not M.is_running() or #state.outbox == 0 then
    state.outbox = {}
    state.sending = false
    return
  end
  state.sending = true
  vim.api.nvim_chan_send(state.job, table.remove(state.outbox, 1))
  _scroll_to_end()
  vim.defer_fn(_write_next_chunk, CHUNK_DELAY_MS)
end

---@param data string
local function _write(data)
  for i = 1, #data, CHUNK_SIZE do
    table.insert(state.outbox, data:sub(i, i + CHUNK_SIZE - 1))
  end
  if not state.sending then
    _write_next_chunk()
  end
end

local function _flush_pending()
  state.ready = true
  for _, data in ipairs(state.pending) do
    _write(data)
  end
  state.pending = {}
end

---Show the REPL buffer in a split at the bottom
---@param buf? integer existing buffer, or nil for a new one
---@return integer win
local function _open_split(buf)
  vim.cmd('botright ' .. SPLIT_HEIGHT .. 'split')
  local win = vim.api.nvim_get_current_win()
  if buf then
    vim.api.nvim_win_set_buf(win, buf)
  else
    vim.cmd('enew')
  end
  return win
end

---@return boolean started
local function _start()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  _open_split()
  local buf = vim.api.nvim_get_current_buf()
  state.buf = buf
  state.ready = false
  state.pending = {}
  state.outbox = {}
  state.sending = false

  local job_opts = {
    on_stdout = function()
      if not state.ready and state.buf == buf then
        _flush_pending()
      end
    end,
    on_exit = function()
      if state.buf == buf then
        state.job = nil
      end
    end,
  }
  local argv = Mpremote.argv({ 'repl' })
  local ok, job
  if vim.fn.has('nvim-0.11') == 1 then
    job_opts.term = true
    ok, job = pcall(vim.fn.jobstart, argv, job_opts)
  else
    ok, job = pcall(vim.fn.termopen, argv, job_opts)
  end
  if not ok or job <= 0 then
    vim.api.nvim_buf_delete(buf, { force = true })
    state.buf = nil
    local hint = argv[1] == 'uv' and 'uv sync' or 'pip install mpremote'
    _notify(
      string.format('mpremote not found (%s). Install with: %s', argv[1], hint),
      vim.log.levels.ERROR
    )
    return false
  end
  state.job = job

  vim.bo[buf].bufhidden = 'hide'
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { buffer = buf, desc = 'Exit terminal mode' })
  return true
end

---Show the REPL, starting it if needed
---@param focus boolean
---@return boolean ok
local function _ensure(focus)
  if not Utils.check_port_configured() then
    return false
  end

  local previous = vim.api.nvim_get_current_win()
  if M.is_running() then
    local win = _window_for(state.buf) or _open_split(state.buf)
    vim.api.nvim_set_current_win(win)
  elseif not _start() then
    vim.api.nvim_set_current_win(previous)
    return false
  end

  if focus then
    vim.cmd('startinsert')
  else
    vim.api.nvim_set_current_win(previous)
  end
  return true
end

---Open or focus the persistent REPL split
function M.open()
  _ensure(true)
end

---Close the REPL and stop mpremote
function M.close()
  if M.is_running() then
    vim.fn.jobstop(state.job)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf, state.job = nil, nil
end

---@param lines string[]
---@return string[]
local function _dedent(lines)
  local indent
  for _, line in ipairs(lines) do
    if line:find('%S') then
      local prefix = line:match('^%s*')
      if not indent then
        indent = prefix
      else
        local i = 0
        while i < #indent and i < #prefix and indent:byte(i + 1) == prefix:byte(i + 1) do
          i = i + 1
        end
        indent = indent:sub(1, i)
      end
    end
  end
  return vim.tbl_map(function(line)
    return line:sub(#indent + 1)
  end, lines)
end

---The keystrokes that enter source lines at the REPL: one line is typed, several are pasted
---in paste mode so the REPL's auto-indent does not change them. Returns nil for blank text.
---@param lines string[]
---@return string?
function M.format_send(lines)
  local first, last = 1, #lines
  while first <= last and not lines[first]:find('%S') do
    first = first + 1
  end
  while last >= first and not lines[last]:find('%S') do
    last = last - 1
  end
  if first > last then
    return nil
  end

  lines = _dedent(vim.list_slice(lines, first, last))
  if #lines == 1 then
    return lines[1] .. ENTER
  end
  return CTRL_E .. table.concat(lines, ENTER) .. CTRL_D
end

---Type keystrokes into the REPL, opening it without leaving the current window
---@param data string
local function _send(data)
  if not _ensure(false) then
    return
  end
  if state.ready then
    _write(data)
  else
    table.insert(state.pending, data)
  end
end

---@param lines string[]
local function _send_lines(lines)
  local data = M.format_send(lines)
  if data then
    _send(data)
  end
end

---Send lines line1..line2 of the current buffer
---@param line1 integer
---@param line2 integer
function M.send_range(line1, line2)
  _send_lines(vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false))
end

---Send the line under the cursor
function M.send_line()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  M.send_range(line, line)
end

---Send the lines of the visual selection, or of the last selection when not in visual mode
function M.send_selection()
  local mode = vim.api.nvim_get_mode().mode
  local line1, line2
  if mode:match('^[vV\22]') then
    line1, line2 = vim.fn.line('v'), vim.fn.line('.')
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
  else
    line1, line2 = vim.fn.line("'<"), vim.fn.line("'>")
  end
  if line1 > line2 then
    line1, line2 = line2, line1
  end
  if line1 > 0 then
    M.send_range(line1, line2)
  end
end

---Send the whole buffer
function M.send_buffer()
  M.send_range(1, vim.api.nvim_buf_line_count(0))
end

---Stop running code on the device (Ctrl-C)
function M.interrupt()
  if not M.is_running() then
    _notify('The REPL is not open. Run :MP repl first.', vim.log.levels.WARN)
    return
  end
  _send(CTRL_C)
end

---Stop whatever is running and run the current buffer in the REPL
function M.run_buffer()
  local data = M.format_send(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  if data then
    _send(CTRL_C .. data)
  end
end

return M
