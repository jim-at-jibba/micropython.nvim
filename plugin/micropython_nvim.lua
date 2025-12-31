vim.api.nvim_create_user_command('MPRun', function()
  require('micropython_nvim').run()
end, { desc = 'Run current buffer on MicroPython device' })

vim.api.nvim_create_user_command('MPUpload', function()
  require('micropython_nvim').upload_current()
end, { desc = 'Upload current buffer to MicroPython device' })

vim.api.nvim_create_user_command('MPUploadAll', function(opts)
  require('micropython_nvim').upload_all({ args = opts.args })
end, { nargs = '?', desc = 'Upload all files to MicroPython device' })

vim.api.nvim_create_user_command('MPSetBaud', function()
  require('micropython_nvim').set_baud_rate()
end, { desc = 'Set baud rate for MicroPython device' })

vim.api.nvim_create_user_command('MPSetPort', function()
  require('micropython_nvim').set_port()
end, { desc = 'Set port for MicroPython device' })

vim.api.nvim_create_user_command('MPRepl', function()
  require('micropython_nvim').repl()
end, { desc = 'Open MicroPython REPL' })

vim.api.nvim_create_user_command('MPInit', function()
  require('micropython_nvim').init()
end, { desc = 'Initialize MicroPython project' })

vim.api.nvim_create_user_command('MPSetStubs', function()
  require('micropython_nvim').set_stubs()
end, { desc = 'Set MicroPython stubs for board' })

vim.api.nvim_create_user_command('MPEraseOne', function()
  require('micropython_nvim').erase_one()
end, { desc = 'Erase single file from MicroPython device' })
