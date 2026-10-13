local helpers = require('test.helpers')

describe('micropython_nvim.run', function()
  local Run
  local Config

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Run = require('micropython_nvim.run')
  end)

  describe('run', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.run()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('mount', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.mount()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('soft_reset', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.soft_reset()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('hard_reset', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.hard_reset()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('erase_all', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.erase_all()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('erase_one', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.erase_one()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('list_files', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.list_files()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('run_main', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.run_main()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('device commands', function()
    local calls
    local restore_fn
    local restore_notify
    local restore_snacks
    local terminal_commands

    before_each(function()
      calls = {}
      terminal_commands = {}
      Config.set_port('/dev/ttyUSB0')
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(argv, opts)
          table.insert(calls, { argv = argv, opts = opts })
          return #calls
        end,
      })
      restore_notify = select(2, helpers.mock_vim_notify())
      restore_snacks = helpers.stub_snacks()
      Snacks.terminal = function(cmd)
        table.insert(terminal_commands, cmd)
      end
    end)

    after_each(function()
      restore_fn()
      restore_notify()
      restore_snacks()
    end)

    ---@param call table
    ---@param n integer
    ---@return string[]
    local function tail(call, n)
      return vim.list_slice(call.argv, #call.argv - n + 1)
    end

    it('soft_reset should run soft_reset in the background', function()
      Run.soft_reset()
      assert.same({ 'soft_reset' }, tail(calls[1], 1))
    end)

    it('hard_reset should run reset in the background', function()
      Run.hard_reset()
      assert.same({ 'reset' }, tail(calls[1], 1))
    end)

    it('erase_one should list device files without blocking', function()
      local chosen
      package.loaded['micropython_nvim.ui'] = {
        select = function(items, _, cb)
          chosen = items
          cb(nil)
        end,
      }
      Run = (function()
        package.loaded['micropython_nvim.run'] = nil
        return require('micropython_nvim.run')
      end)()

      Run.erase_one()
      assert.same({ 'fs', 'ls', ':' }, tail(calls[1], 3))
      assert.is_nil(chosen)

      calls[1].opts.on_stdout(1, { 'ls :', '         139 main.py', '           0 lib/', '' })
      calls[1].opts.on_stderr(1, { '' })
      calls[1].opts.on_exit(1, 0)
      assert.same({ 'main.py', 'lib/' }, chosen)
    end)

    describe('erase confirmation', function()
      local prompts
      local answer
      local notifications

      before_each(function()
        prompts = {}
        answer = 'Yes'
        notifications = helpers.mock_vim_notify()
        require('micropython_nvim.ui').select = function(_, opts, cb)
          table.insert(prompts, opts.prompt)
          cb(answer)
        end
      end)

      ---List main.py and lib/ on the device, then pick one
      ---@param choice string
      local function erase_one(choice)
        require('micropython_nvim.ui').select = function(items, opts, cb)
          table.insert(prompts, opts.prompt)
          cb(items[1] == 'Yes' and answer or choice)
        end
        Run.erase_one()
        calls[1].opts.on_stdout(1, { '         139 main.py', '           0 lib/', '' })
        calls[1].opts.on_stderr(1, { '' })
        calls[1].opts.on_exit(1, 0)
      end

      local function cancelled()
        for _, n in ipairs(notifications) do
          if n.msg:find('nothing was deleted', 1, true) then
            return true
          end
        end
        return false
      end

      it('erase_all should ask, naming the port, and erase on Yes', function()
        Run.erase_all()
        assert.same({ 'Delete every file on /dev/ttyUSB0?' }, prompts)
        assert.equals(1, #terminal_commands)
        assert.is_truthy(terminal_commands[1]:find("'rm' '-r' ':'", 1, true))
      end)

      it('erase_all should name an auto port as the auto-detected device', function()
        Config.set_port('auto')
        Run.erase_all()
        assert.same({ 'Delete every file on the auto-detected device?' }, prompts)
      end)

      for _, case in ipairs({ { 'No', 'No' }, { 'cancel', nil } }) do
        it('erase_all should delete nothing on ' .. case[1], function()
          answer = case[2]
          Run.erase_all()
          assert.equals(0, #terminal_commands)
          assert.is_true(cancelled())
        end)

        it('erase_one should delete nothing on ' .. case[1], function()
          answer = case[2]
          erase_one('main.py')
          assert.equals(1, #calls)
          assert.is_true(cancelled())
        end)
      end

      it('erase_one should ask about a file and delete it on Yes', function()
        erase_one('main.py')
        assert.equals('Delete main.py?', prompts[2])
        assert.same({ 'fs', 'rm', ':main.py' }, tail(calls[2], 3))
      end)

      it('erase_one should ask about a folder and its contents', function()
        erase_one('lib/')
        assert.equals('Delete lib/ and everything in it?', prompts[2])
        assert.same({ 'fs', 'rm', '-r', ':lib/' }, tail(calls[2], 4))
      end)
    end)

    describe('run_main', function()
      ---@param fn fun(dir: string)
      local function in_project(fn)
        helpers.with_temp_dir(function(dir)
          local cwd = vim.fn.getcwd()
          vim.cmd.cd(dir)
          local ok, err = pcall(fn, vim.fn.getcwd())
          vim.cmd.cd(cwd)
          assert(ok, err)
        end)
      end

      it("should run the project's local main.py", function()
        in_project(function(dir)
          vim.fn.writefile({ 'print("hi")' }, dir .. '/main.py')
          Run.run_main()
          assert.equals(1, #terminal_commands)
          local expected = "'run' " .. vim.fn.shellescape(dir .. '/main.py')
          assert.is_truthy(terminal_commands[1]:find(expected, 1, true))
          assert.is_falsy(terminal_commands[1]:find('exec', 1, true))
          assert.is_truthy(terminal_commands[1]:find('2>&1', 1, true))
        end)
      end)

      it('should warn when the project has no main.py', function()
        in_project(function()
          local notifications, restore = helpers.mock_vim_notify()
          Run.run_main()
          restore()
          assert.equals(0, #terminal_commands)
          assert.equals(vim.log.levels.WARN, notifications[1].level)
          assert.is_truthy(notifications[1].msg:find('main.py', 1, true))
        end)
      end)

      it('should run main.py through the REPL when it holds the port', function()
        local ran
        package.loaded['micropython_nvim.repl'] = {
          is_running = function()
            return true
          end,
          run_lines = function(lines)
            ran = lines
          end,
        }
        in_project(function(dir)
          vim.fn.writefile({ 'print("hi")' }, dir .. '/main.py')
          Run.run_main()
        end)
        assert.same({ 'print("hi")' }, ran)
        assert.equals(0, #terminal_commands)
      end)
    end)

    it('run should escape the file path for the terminal', function()
      vim.api.nvim_buf_set_name(0, "/tmp/it's here.py")
      Run.run()
      local path = vim.api.nvim_buf_get_name(0)
      assert.is_truthy(terminal_commands[1]:find(vim.fn.shellescape(path), 1, true))
    end)
  end)
end)
