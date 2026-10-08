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
