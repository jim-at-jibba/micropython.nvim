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

    it('should create parent directories for nested files before copying', function()
      helpers.with_temp_dir(function(tmpdir)
        local nested_dir = tmpdir .. '/web/resources/templates'
        local nested_file = nested_dir .. '/info.html'
        local command = nil

        vim.fn.mkdir(nested_dir, 'p')

        local file = io.open(nested_file, 'w')
        assert.is_not_nil(file)
        file:write('<h1>info</h1>')
        file:close()

        local restore = helpers.mock_vim_fn({
          executable = function()
            return 0
          end,
          filereadable = function()
            return 0
          end,
          getcwd = function()
            return tmpdir
          end,
          jobstart = function(cmd)
            command = cmd
            return 1
          end,
        })

        Run.upload_all()

        restore()

        assert.is_not_nil(command)
        assert.is_true(
          command:find(
            'fs mkdir :web + fs mkdir :web/resources + fs mkdir :web/resources/templates',
            1,
            true
          ) ~= nil
        )
        assert.is_true(
          command:find(
            string.format('cp "%s" :web/resources/templates/info.html', nested_file),
            1,
            true
          ) ~= nil
        )
      end)
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
end)
