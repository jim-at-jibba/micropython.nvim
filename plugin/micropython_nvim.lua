vim.api.nvim_create_user_command('MP', function(opts)
  local range = opts.range > 0 and { line1 = opts.line1, line2 = opts.line2 } or nil
  require('micropython_nvim.commands').dispatch(opts.fargs, range)
end, {
  nargs = '*',
  range = true,
  desc = 'MicroPython: run a subcommand (:MP <Tab> to list them)',
  complete = function(arglead, cmdline, cursorpos)
    return require('micropython_nvim.commands').complete(arglead, cmdline, cursorpos)
  end,
})

-- mp://<path> buffers read from and write to the device
local files_group = vim.api.nvim_create_augroup('micropython_nvim_files', { clear = true })
vim.api.nvim_create_autocmd('BufReadCmd', {
  group = files_group,
  pattern = 'mp://*',
  desc = 'micropython.nvim: read a device file',
  callback = function(event)
    require('micropython_nvim.files').read(event.buf)
  end,
})
vim.api.nvim_create_autocmd('BufWriteCmd', {
  group = files_group,
  pattern = 'mp://*',
  desc = 'micropython.nvim: write a device file',
  callback = function(event)
    require('micropython_nvim.files').write(event.buf)
  end,
})
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = files_group,
  desc = 'micropython.nvim: finish device file writes',
  callback = function()
    -- Only loaded once an mp:// buffer or the browser was used
    if package.loaded['micropython_nvim.files'] then
      require('micropython_nvim.files').wait_for_writes()
    end
  end,
})

-- Legacy :MPxxx commands, kept as aliases for their :MP subcommand
for legacy, subcommand in pairs(require('micropython_nvim.commands').LEGACY_ALIASES) do
  vim.api.nvim_create_user_command(legacy, function(opts)
    require('micropython_nvim.commands').dispatch(vim.list_extend({ subcommand }, opts.fargs))
  end, {
    nargs = subcommand == 'upload_all' and '*' or 0,
    desc = 'Alias for :MP ' .. subcommand,
  })
end
