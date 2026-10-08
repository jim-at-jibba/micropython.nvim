local helpers = require('test.helpers')

describe('micropython_nvim.terminal', function()
  local Terminal

  before_each(function()
    helpers.reset_modules()
    Terminal = require('micropython_nvim.terminal')
  end)

  after_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == 'terminal' then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)

  ---@return boolean
  local function in_floating_terminal()
    local win = vim.api.nvim_get_current_win()
    return vim.api.nvim_win_get_config(win).relative ~= ''
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal'
  end

  it('should use snacks.nvim when it is installed', function()
    local restore = helpers.stub_snacks()
    local received
    _G.Snacks.terminal = function(command)
      received = command
    end

    Terminal.open('mpremote repl')

    restore()
    assert.equals('mpremote repl', received)
  end)

  describe('without snacks.nvim', function()
    local restore_snacks

    before_each(function()
      restore_snacks = helpers.hide_snacks()
    end)

    after_each(function()
      restore_snacks()
    end)

    it('should open the command in a floating terminal', function()
      Terminal.open('echo hello; sleep 5')
      assert.is_true(in_floating_terminal())
    end)

    it('should open :MP run in a terminal', function()
      require('micropython_nvim.config').setup({})
      vim.cmd('edit ' .. vim.fn.tempname() .. '.py')
      require('micropython_nvim.commands').dispatch({ 'run' })
      assert.is_true(in_floating_terminal())
    end)

    it('should run the command', function()
      Terminal.open('echo micropython-terminal-ok; sleep 5')
      local buf = vim.api.nvim_get_current_buf()

      local found = vim.wait(3000, function()
        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        return text:find('micropython-terminal-ok', 1, true) ~= nil
      end)

      assert.is_true(found)
    end)

    it('should keep the window open when the command fails', function()
      Terminal.open('echo connection failed; exit 1')
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_get_current_buf()

      vim.wait(3000, function()
        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        return text:find('exited', 1, true) ~= nil
      end)
      vim.wait(100)

      assert.is_true(vim.api.nvim_win_is_valid(win))
    end)

    it('should close the window when the command exits', function()
      Terminal.open('true')
      local win = vim.api.nvim_get_current_win()

      local closed = vim.wait(3000, function()
        return not vim.api.nvim_win_is_valid(win)
      end)

      assert.is_true(closed)
    end)
  end)
end)
