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

  describe('DEFAULT_IGNORE_LIST', function()
    it('should be a table', function()
      assert.is_table(Run.DEFAULT_IGNORE_LIST)
    end)

    it('should contain .git', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.git'])
    end)

    it('should contain .micropython', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.micropython'])
    end)

    it('should contain .ampy for backwards compatibility', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.ampy'])
    end)

    it('should contain __pycache__', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['__pycache__'])
    end)

    it('should contain pyproject.toml', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['pyproject.toml'])
    end)

    it('should contain uv.lock', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['uv.lock'])
    end)

    it('should contain .venv', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.venv'])
    end)

    it('should contain venv', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['venv'])
    end)

    it('should contain env', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['env'])
    end)

    it('should contain requirements.txt', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['requirements.txt'])
    end)

    it('should contain .vscode', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.vscode'])
    end)

    it('should contain .gitignore', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.gitignore'])
    end)

    it('should contain project.pymakr', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['project.pymakr'])
    end)

    it('should contain .python-version', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.python-version'])
    end)

    it('should contain .micropy/', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.micropy/'])
    end)

    it('should contain micropy.json', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['micropy.json'])
    end)

    it('should contain .idea', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.idea'])
    end)

    it('should contain README.md', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['README.md'])
    end)

    it('should contain LICENSE', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['LICENSE'])
    end)

    it('should not contain main.py', function()
      assert.is_nil(Run.DEFAULT_IGNORE_LIST['main.py'])
    end)

    it('should not contain lib/', function()
      assert.is_nil(Run.DEFAULT_IGNORE_LIST['lib/'])
    end)
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

  describe('upload_current', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.upload_current()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('upload_all', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.upload_all()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('No port configured') ~= nil)
    end)
  end)

  describe('sync', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      local notifications, restore = helpers.mock_vim_notify()

      Run.sync()

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

    it('upload_current should copy the buffer as one argv entry', function()
      vim.api.nvim_buf_set_name(0, '/tmp/my "odd" $dir/main.py')
      local path = vim.api.nvim_buf_get_name(0)
      Run.upload_current()
      assert.same({ 'connect', '/dev/ttyUSB0', 'cp', path, ':main.py' }, tail(calls[1], 5))
    end)

    it('soft_reset should run soft_reset in the background', function()
      Run.soft_reset()
      assert.same({ 'soft_reset' }, tail(calls[1], 1))
    end)

    it('hard_reset should run reset in the background', function()
      Run.hard_reset()
      assert.same({ 'reset' }, tail(calls[1], 1))
    end)

    it('upload_all should chain mkdir and cp with +', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.mkdir(dir .. '/lib', 'p')
        vim.fn.writefile({ '' }, dir .. '/lib/a b.py')
        local restore_cwd = helpers.mock_vim_fn({
          getcwd = function()
            return dir
          end,
          jobstart = function(argv, opts)
            table.insert(calls, { argv = argv, opts = opts })
            return #calls
          end,
        })
        Run.upload_all()
        restore_cwd()
        assert.same(
          { 'fs', 'mkdir', ':lib', '+', 'cp', dir .. '/lib/a b.py', ':lib/a b.py' },
          tail(calls[1], 7)
        )
      end)
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

    it('run should escape the file path for the terminal', function()
      vim.api.nvim_buf_set_name(0, "/tmp/it's here.py")
      Run.run()
      local path = vim.api.nvim_buf_get_name(0)
      assert.is_truthy(terminal_commands[1]:find(vim.fn.shellescape(path), 1, true))
    end)
  end)
end)
