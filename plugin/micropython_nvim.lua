local plugin = require('micropython_nvim')

vim.api.nvim_create_user_command('MPRun', plugin.run, {})
vim.api.nvim_create_user_command('MPSetBaud', plugin.setBaudRate, {})
