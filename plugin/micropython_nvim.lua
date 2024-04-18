local plugin = require('micropython_nvim')

vim.api.nvim_create_user_command('MPRun', plugin.run, {})
vim.api.nvim_create_user_command('MPSetBaud', plugin.set_baud_rate, {})
vim.api.nvim_create_user_command('MPSetPort', plugin.set_port, {})
