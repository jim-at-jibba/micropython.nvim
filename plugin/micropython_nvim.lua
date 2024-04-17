local test = require('micropython_nvim')

vim.api.nvim_create_user_command('MPRun', test.run, {})
