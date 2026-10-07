local Mpremote = require('micropython_nvim.mpremote')
local Terminal = require('micropython_nvim.terminal')
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
-- Time for interrupted code to print its traceback and return to the prompt
local INTERRUPT_SETTLE_MS = 200

local state = {
  ---@type integer?
  buf = nil,
  ---@type integer?
  job = nil,
  -- mpremote ignores input until it has connected; the outbox waits for its first output
  ready = false,
  -- Chunks still to be written, in order, each with the pause that follows it
  ---@type { data: string, delay: integer }[]
  outbox = {},
  sending = false,
}

---@param msg string
---@param level integer
local function _notify(msg, level)
  vim.notify(msg, level, { title = 'micropython.nvim' })
end

---Whether the REPL's mpremote is running. Tracked by on_exit rather than jobwait(), which can
---hang when called from inside the job's own callbacks.
---@return boolean
function M.is_running()
  return state.job ~= nil
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

---@param job integer the REPL this loop writes to; a restarted REPL stops the old loop
local function _write_next_chunk(job)
  if state.job ~= job then
    return
  end
  if not M.is_running() or #state.outbox == 0 then
    state.outbox = {}
    state.sending = false
    return
  end
  state.sending = true
  local chunk = table.remove(state.outbox, 1)
  -- The process may have exited before its on_exit has run
  if not pcall(vim.api.nvim_chan_send, job, chunk.data) then
    state.outbox = {}
    state.sending = false
    return
  end
  _scroll_to_end()
  vim.defer_fn(function()
    _write_next_chunk(job)
  end, chunk.delay)
end

local function _start_writing()
  if state.ready and not state.sending then
    _write_next_chunk(state.job)
  end
end

---Queue keystrokes for the REPL
---@param data string
---@param settle_ms? integer pause after the last chunk
local function _write(data, settle_ms)
  for i = 1, #data, CHUNK_SIZE do
    local last = i + CHUNK_SIZE > #data
    table.insert(state.outbox, {
      data = data:sub(i, i + CHUNK_SIZE - 1),
      delay = last and settle_ms or CHUNK_DELAY_MS,
    })
  end
  _start_writing()
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
  state.outbox = {}
  state.sending = false

  local argv = Mpremote.argv({ 'repl' })
  local job = Terminal.start(argv, {
    on_stdout = function()
      if not state.ready and state.buf == buf then
        state.ready = true
        _start_writing()
      end
    end,
    on_exit = function()
      if state.buf ~= buf then
        return
      end
      if #state.outbox > 0 then
        _notify('The REPL exited before all the code was sent', vim.log.levels.WARN)
      end
      state.job, state.outbox, state.sending = nil, {}, false
    end,
  })
  if not job then
    vim.api.nvim_buf_delete(buf, { force = true })
    state.buf = nil
    _notify(Mpremote.not_found_message(argv), vim.log.levels.ERROR)
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

local BLOCK_KEYWORDS = {
  'if',
  'elif',
  'else',
  'for',
  'while',
  'def',
  'class',
  'with',
  'try',
  'except',
  'finally',
  'async',
}

---Whether a line is a compound statement, which the REPL would wait to see the end of
---@param line string
---@return boolean
local function _opens_block(line)
  local word = line:match('^([%a_]+)')
  return line:find(':%s*$') ~= nil
    or line:sub(1, 1) == '@'
    or (word ~= nil and vim.tbl_contains(BLOCK_KEYWORDS, word))
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
  if #lines == 1 and not _opens_block(lines[1]) then
    return lines[1] .. ENTER
  end
  return CTRL_E .. table.concat(lines, ENTER) .. CTRL_D
end

---Type keystrokes into the REPL, opening it without leaving the current window
---@param data string
---@param settle_ms? integer pause before anything sent after this
local function _send(data, settle_ms)
  if _ensure(false) then
    _write(data, settle_ms)
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
  -- Ahead of anything still queued, which it would only interrupt
  state.outbox = {}
  _send(CTRL_C, INTERRUPT_SETTLE_MS)
end

---Stop whatever is running and run the current buffer in the REPL
function M.run_buffer()
  local data = M.format_send(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  if data then
    _send(CTRL_C, INTERRUPT_SETTLE_MS)
    _send(data)
  end
end

return M
