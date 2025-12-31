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

vim.api.nvim_create_user_command('MPInstall', function()
  require('micropython_nvim').install()
end, { desc = 'Install project dependencies with uv' })

vim.api.nvim_create_user_command('MPSetStubs', function()
  require('micropython_nvim').set_stubs()
end, { desc = 'Set MicroPython stubs for board' })

vim.api.nvim_create_user_command('MPEraseOne', function()
  require('micropython_nvim').erase_one()
end, { desc = 'Erase single file from MicroPython device' })

vim.api.nvim_create_user_command('MPEraseAll', function()
  require('micropython_nvim').erase_all()
end, { desc = 'Erase all files from MicroPython device' })

vim.api.nvim_create_user_command('MPSync', function()
  require('micropython_nvim').sync()
end, { desc = 'Mount local directory on device for live development' })

vim.api.nvim_create_user_command('MPReset', function()
  require('micropython_nvim').soft_reset()
end, { desc = 'Soft reset MicroPython device' })

vim.api.nvim_create_user_command('MPHardReset', function()
  require('micropython_nvim').hard_reset()
end, { desc = 'Hard reset MicroPython device' })

vim.api.nvim_create_user_command('MPListDevices', function()
  require('micropython_nvim').list_devices()
end, { desc = 'List connected MicroPython devices' })

vim.api.nvim_create_user_command('MPListFiles', function()
  require('micropython_nvim').list_files()
end, { desc = 'List files on MicroPython device' })

vim.api.nvim_create_user_command('MPRunMain', function()
  require('micropython_nvim').run_main()
end, { desc = 'Run main.py on MicroPython device' })
