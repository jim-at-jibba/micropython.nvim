vim.api.nvim_create_user_command('MP', function(opts)
  require('micropython_nvim.commands').dispatch(opts.fargs)
end, {
  nargs = '*',
  desc = 'MicroPython: run a subcommand (:MP <Tab> to list them)',
  complete = function(arglead, cmdline, cursorpos)
    return require('micropython_nvim.commands').complete(arglead, cmdline, cursorpos)
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
