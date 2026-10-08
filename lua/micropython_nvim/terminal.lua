local Utils = require('micropython_nvim.utils')

local M = {}

---@param buf integer
---@return integer win
local function _open_float(buf)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  return vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' micropython.nvim ',
    title_pos = 'center',
  })
end

---Start a command as a terminal in the current buffer, which must be empty and unmodified
---@param command string|string[] shell string, or argv run without a shell
---@param job_opts table jobstart options (on_stdout, on_exit, ...)
---@return integer? job nil when the command could not be started
function M.start(command, job_opts)
  local ok, job
  if vim.fn.has('nvim-0.11') == 1 then
    ok, job = pcall(vim.fn.jobstart, command, vim.tbl_extend('force', job_opts, { term = true }))
  else
    ok, job = pcall(vim.fn.termopen, command, job_opts)
  end
  if ok and job > 0 then
    return job
  end
end

---Run a shell command in a floating terminal using Neovim's built-in terminal
---@param command string
local function _builtin_terminal(command)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = _open_float(buf)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  M.start(command, {
    -- Keep a failed command's output visible; q closes it
    on_exit = function(_, code)
      if code == 0 then
        vim.schedule(close)
      end
    end,
  })

  vim.keymap.set('n', 'q', close, { buffer = buf, desc = 'Close terminal' })
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { buffer = buf, desc = 'Exit terminal mode' })
  vim.cmd('startinsert')
end

---Open a shell command in a terminal: snacks.nvim when installed, otherwise built-in
---@param command string
function M.open(command)
  local snacks = Utils.get_snacks()
  if snacks and snacks.terminal then
    snacks.terminal(command)
    return
  end
  _builtin_terminal(command)
end

return M
