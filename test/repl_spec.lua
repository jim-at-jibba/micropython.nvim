local helpers = require('test.helpers')

describe('micropython_nvim.repl', function()
  local Repl
  local Config
  local out

  ---Stand in for `mpremote repl`: a raw-mode terminal that records what it receives
  local function fake_repl()
    out = vim.fn.tempname()
    require('micropython_nvim.mpremote').argv = function()
      return {
        'sh',
        '-c',
        'stty raw -echo; printf "Connected to MicroPython\\r\\n"; cat > '
          .. vim.fn.shellescape(out),
      }
    end
  end

  ---@param expected string
  ---@return string received
  local function wait_for_received(expected)
    local received = ''
    vim.wait(3000, function()
      received = vim.fn.filereadable(out) == 1 and table.concat(vim.fn.readfile(out, 'b'), '\n')
        or ''
      return received == expected
    end, 20)
    return received
  end

  ---@return integer[]
  local function repl_windows()
    return vim.tbl_filter(function(win)
      return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal'
    end, vim.api.nvim_list_wins())
  end

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Config.set_port('/dev/ttyUSB0')
    fake_repl()
    Repl = require('micropython_nvim.repl')
  end)

  after_each(function()
    Repl.close()
    vim.cmd('silent! only')
    vim.cmd('enew!')
  end)

  describe('format_send', function()
    it('should send a single line followed by Enter', function()
      assert.equals('x = 1\r', Repl.format_send({ 'x = 1' }))
    end)

    it('should send several lines in paste mode', function()
      assert.equals(
        '\5for i in range(3):\r    print(i)\4',
        Repl.format_send({ 'for i in range(3):', '    print(i)' })
      )
    end)

    it('should remove indentation shared by every line', function()
      assert.equals(
        '\5if x:\r    y()\r\rz()\4',
        Repl.format_send({ '    if x:', '        y()', '', '    z()' })
      )
    end)

    it('should dedent tab-indented lines', function()
      assert.equals('return 1\r', Repl.format_send({ '\t\treturn 1' }))
    end)

    it('should drop blank lines around the text', function()
      assert.equals('x = 1\r', Repl.format_send({ '', '  ', 'x = 1', '' }))
    end)

    it('should paste a single line that opens a block', function()
      assert.equals('\5for i in range(3):\4', Repl.format_send({ 'for i in range(3):' }))
      assert.equals(
        '\5for i in range(3): print(i)\4',
        Repl.format_send({ 'for i in range(3): print(i)' })
      )
      assert.equals('\5@micropython.native\4', Repl.format_send({ '@micropython.native' }))
    end)

    it('should type a single line that only starts like a keyword', function()
      assert.equals('format = 1\r', Repl.format_send({ 'format = 1' }))
    end)

    it('should return nil when there is nothing to send', function()
      assert.is_nil(Repl.format_send({}))
      assert.is_nil(Repl.format_send({ '', '   ' }))
    end)
  end)

  describe('open', function()
    it('should warn when the port is not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()
      Repl.open()
      restore()
      assert.is_truthy(notifications[1].msg:find('No port configured'))
      assert.equals(0, #repl_windows())
    end)

    it('should open the REPL in a focused split, not a float', function()
      Repl.open()
      local win = vim.api.nvim_get_current_win()
      assert.equals('terminal', vim.bo.buftype)
      assert.equals('', vim.api.nvim_win_get_config(win).relative)
      assert.equals(2, #vim.api.nvim_list_wins())
    end)

    it('should start mpremote repl', function()
      local received
      require('micropython_nvim.mpremote').argv = function(args)
        received = args
        return { 'sh', '-c', 'sleep 5' }
      end
      Repl.open()
      assert.same({ 'repl' }, received)
    end)

    it('should focus the existing REPL instead of starting another', function()
      Repl.open()
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd('wincmd p')

      Repl.open()

      assert.equals(buf, vim.api.nvim_get_current_buf())
      assert.equals(1, #repl_windows())
    end)

    it('should show the REPL again after its window was closed', function()
      Repl.open()
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd('close')

      Repl.open()

      assert.equals(buf, vim.api.nvim_get_current_buf())
    end)

    it('should start a new REPL when the old one has exited', function()
      require('micropython_nvim.mpremote').argv = function()
        return { 'sh', '-c', 'exit 0' }
      end
      Repl.open()
      local buf = vim.api.nvim_get_current_buf()
      vim.wait(2000, function()
        return not Repl.is_running()
      end)
      fake_repl()

      Repl.open()

      assert.is_true(Repl.is_running())
      assert.are_not.equal(buf, vim.api.nvim_get_current_buf())
    end)

    it('should report a missing mpremote and leave no window behind', function()
      require('micropython_nvim.mpremote').argv = function()
        return { 'mpremote-not-installed', 'repl' }
      end
      local notifications, restore = helpers.mock_vim_notify()

      Repl.open()

      restore()
      assert.is_truthy(notifications[1].msg:find('mpremote not found'))
      assert.equals(1, #vim.api.nvim_list_wins())
      assert.is_false(Repl.is_running())
    end)

    it('should not use the snacks.nvim terminal', function()
      local restore = helpers.stub_snacks()
      local used = false
      _G.Snacks.terminal = function()
        used = true
      end
      Repl.open()
      restore()
      assert.is_false(used)
      assert.equals('terminal', vim.bo.buftype)
    end)

    it('should work without snacks.nvim', function()
      local restore = helpers.hide_snacks()
      Repl.open()
      restore()
      assert.equals('terminal', vim.bo.buftype)
    end)
  end)

  describe('sending', function()
    local source

    before_each(function()
      source = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, {
        'import time',
        'for i in range(3):',
        '    print(i)',
      })
    end)

    it('should start the REPL without leaving the buffer and send the current line', function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      Repl.send_line()

      assert.equals(source, vim.api.nvim_get_current_buf())
      assert.equals(1, #repl_windows())
      assert.equals('import time\r', wait_for_received('import time\r'))
    end)

    it('should send the visual selection in paste mode', function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd('normal! Vj')
      Repl.send_selection()

      local expected = '\5for i in range(3):\r    print(i)\4'
      assert.equals(expected, wait_for_received(expected))
      assert.equals('n', vim.api.nvim_get_mode().mode)
    end)

    it('should send the last selection from normal mode', function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd('normal! Vj\27')
      Repl.send_selection()

      local expected = '\5for i in range(3):\r    print(i)\4'
      assert.equals(expected, wait_for_received(expected))
    end)

    it('should send the whole buffer', function()
      Repl.send_buffer()

      local expected = '\5import time\rfor i in range(3):\r    print(i)\4'
      assert.equals(expected, wait_for_received(expected))
    end)

    it('should send long text in full', function()
      local lines = {}
      for i = 1, 200 do
        table.insert(lines, string.format('value_%03d = %d', i, i))
      end
      vim.api.nvim_buf_set_lines(source, 0, -1, false, lines)

      Repl.send_buffer()

      local expected = '\5' .. table.concat(lines, '\r') .. '\4'
      assert.equals(expected, wait_for_received(expected))
    end)

    it('should do nothing for a blank line', function()
      vim.api.nvim_buf_set_lines(source, 0, -1, false, { '' })
      Repl.send_line()
      assert.equals(0, #repl_windows())
    end)

    it('should interrupt running code with Ctrl-C', function()
      Repl.open()
      vim.cmd('wincmd p')
      Repl.interrupt()
      assert.equals('\3', wait_for_received('\3'))
    end)

    it('should interrupt ahead of text still being sent', function()
      Repl.open()
      vim.cmd('wincmd p')
      local lines = {}
      for i = 1, 200 do
        table.insert(lines, string.format('value_%03d = %d', i, i))
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.wait(2000, function()
        return vim.fn.filereadable(out) == 1
      end)

      Repl.send_buffer()
      Repl.interrupt()

      local received = ''
      vim.wait(2000, function()
        received = table.concat(vim.fn.readfile(out, 'b'), '\n')
        return received:find('\3', 1, true) ~= nil
      end, 20)
      assert.is_true(#received < 256)
    end)

    it('should warn when interrupting without a REPL', function()
      local notifications, restore = helpers.mock_vim_notify()
      Repl.interrupt()
      restore()
      assert.is_truthy(notifications[1].msg:find('REPL is not open'))
    end)
  end)

  describe(':MP run with the REPL open', function()
    it('should stop running code and then run the buffer in the REPL', function()
      local restore_snacks = helpers.stub_snacks()
      local terminal_used = false
      _G.Snacks.terminal = function()
        terminal_used = true
      end
      Repl.open()
      vim.cmd('wincmd p')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'print("a")', 'print("b")' })

      require('micropython_nvim.run').run()

      restore_snacks()
      local expected = '\3\5print("a")\rprint("b")\4'
      assert.equals(expected, wait_for_received(expected))
      assert.is_false(terminal_used)
    end)
  end)

  describe('commands', function()
    before_each(function()
      vim.cmd('runtime plugin/micropython_nvim.lua')
    end)

    it('should send a visual range with :MP send', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a = 1', 'b = 2', 'c = 3' })
      vim.cmd('2,3MP send')

      local expected = '\5b = 2\rc = 3\4'
      assert.equals(expected, wait_for_received(expected))
    end)

    it('should send the current line with :MP send and no range', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a = 1', 'b = 2' })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd('MP send')
      assert.equals('b = 2\r', wait_for_received('b = 2\r'))
    end)

    it('should refuse a range for a subcommand that does not take one', function()
      local notifications, restore = helpers.mock_vim_notify()
      vim.cmd('1MP repl')
      restore()
      assert.is_truthy(notifications[1].msg:find('does not take a line range'))
      assert.equals(0, #repl_windows())
    end)

    it('should interrupt with :MP interrupt', function()
      Repl.open()
      vim.cmd('wincmd p')
      vim.cmd('MP interrupt')
      assert.equals('\3', wait_for_received('\3'))
    end)
  end)
end)
