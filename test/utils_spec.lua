local helpers = require('test.helpers')
local fixtures = require('test.fixtures')

describe('micropython_nvim.utils', function()
  local Utils
  local Config

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Utils = require('micropython_nvim.utils')
  end)

  describe('get_cwd', function()
    it('should return a string', function()
      local cwd = Utils.get_cwd()
      assert.is_string(cwd)
    end)

    it('should return non-empty path', function()
      local cwd = Utils.get_cwd()
      assert.is_true(#cwd > 0)
    end)
  end)

  describe('check_port_configured', function()
    it('should return true without notifying when a port is set', function()
      require('micropython_nvim.config').set_port('auto')
      local notifications, restore = helpers.mock_vim_notify()
      local ok = Utils.check_port_configured()
      restore()
      assert.is_true(ok)
      assert.equals(0, #notifications)
    end)

    it('should warn with the :MP set_port hint when no port is set', function()
      require('micropython_nvim.config').set_port('')
      local notifications, restore = helpers.mock_vim_notify()
      local ok = Utils.check_port_configured()
      restore()
      assert.is_false(ok)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
      assert.is_truthy(notifications[1].msg:find(':MP set_port', 1, true))
    end)
  end)

  describe('get_config_path', function()
    it('should return path ending with .micropython', function()
      local path = Utils.get_config_path()
      assert.is_true(path:match('%.micropython$') ~= nil)
    end)

    it('should include cwd in path', function()
      local path = Utils.get_config_path()
      local cwd = Utils.get_cwd()
      assert.is_true(path:find(cwd, 1, true) == 1)
    end)
  end)

  describe('PRESS_ENTER_PROMPT', function()
    it('should be defined', function()
      assert.is_string(Utils.PRESS_ENTER_PROMPT)
    end)

    it('should contain printf command', function()
      assert.is_true(Utils.PRESS_ENTER_PROMPT:find('printf') ~= nil)
    end)
  end)

  describe('get_directory_name', function()
    it('should return a string', function()
      local name = Utils.get_directory_name()
      assert.is_string(name)
    end)

    it('should return non-empty name', function()
      local name = Utils.get_directory_name()
      assert.is_true(#name > 0)
    end)

    it('should return lowercase name', function()
      local name = Utils.get_directory_name()
      assert.equals(name:lower(), name)
    end)

    it('should not contain invalid Python package characters', function()
      local name = Utils.get_directory_name()
      assert.is_nil(name:match('[^%w_]'))
    end)
  end)

  describe('debug_print', function()
    it('should not print when debug is disabled', function()
      Config.setup({ debug = false })
      local printed = false
      local original_print = _G.print
      _G.print = function()
        printed = true
      end
      Utils.debug_print('test message')
      _G.print = original_print
      assert.is_false(printed)
    end)

    it('should print when debug is enabled', function()
      Config.setup({ debug = true })
      helpers.reset_modules()
      Config = require('micropython_nvim.config')
      Config.setup({ debug = true })
      Utils = require('micropython_nvim.utils')

      local printed = false
      local original_print = _G.print
      _G.print = function()
        printed = true
      end
      Utils.debug_print('test message')
      _G.print = original_print
      assert.is_true(printed)
    end)
  end)

  describe('create_file_with_template', function()
    it('should create file with content', function()
      helpers.with_temp_dir(function(tmpdir)
        local filepath = tmpdir .. '/test.txt'
        local content = 'test content'

        local result = Utils.create_file_with_template(filepath, content)

        assert.is_true(result)
        assert.equals(1, vim.fn.filereadable(filepath))

        local file = io.open(filepath, 'r')
        local actual = file:read('*a')
        file:close()
        assert.equals(content, actual)
      end)
    end)

    it('should return false for invalid path', function()
      local notifications, restore = helpers.mock_vim_notify()
      local result = Utils.create_file_with_template('/nonexistent/dir/file.txt', 'content')
      restore()

      assert.is_false(result)
      assert.is_true(#notifications > 0)
    end)
  end)

  describe('set_config_value', function()
    local function write_and_set(content, key, value)
      local result, after
      helpers.with_temp_dir(function(tmpdir)
        local filepath = tmpdir .. '/config.txt'
        local file = io.open(filepath, 'w')
        file:write(content)
        file:close()

        result = Utils.set_config_value(filepath, key, value)

        file = io.open(filepath, 'r')
        after = file:read('*a')
        file:close()
      end)
      return result, after
    end

    it('should replace the key line and preserve other lines', function()
      local result, content = write_and_set('PORT=auto\nBAUD=115200\n', 'PORT', '/dev/ttyUSB0')

      assert.is_true(result)
      assert.equals('PORT=/dev/ttyUSB0\nBAUD=115200\n', content)
    end)

    it('should keep the comment in the :MP init config', function()
      local Project = require('micropython_nvim.project')
      local _, content = write_and_set(Project.TEMPLATES.micropython_config, 'PORT', '/dev/ttyACM0')

      assert.equals(
        Project.TEMPLATES.micropython_config:gsub('PORT=auto', 'PORT=/dev/ttyACM0'),
        content
      )
    end)

    it('should never rewrite lines that only mention the key', function()
      local _, content =
        write_and_set('# set PORT below\nMY_PORT=x\nPORTS=y\n', 'PORT', '/dev/ttyACM0')

      assert.equals('# set PORT below\nMY_PORT=x\nPORTS=y\nPORT=/dev/ttyACM0\n', content)
    end)

    it('should append the key when it is not set', function()
      local result, content = write_and_set('BAUD=115200\n', 'PORT', 'auto')

      assert.is_true(result)
      assert.equals('BAUD=115200\nPORT=auto\n', content)
    end)

    it('should match the key with surrounding whitespace', function()
      local _, content = write_and_set('  PORT = auto\n', 'PORT', '/dev/ttyACM0')

      assert.equals('PORT=/dev/ttyACM0\n', content)
    end)

    it('should collapse duplicate key lines into one', function()
      local _, content = write_and_set('PORT=a\nBAUD=1\nPORT=b\n', 'PORT', 'c')

      assert.equals('PORT=c\nBAUD=1\n', content)
    end)

    it('should return false for non-existent file', function()
      local _, restore = helpers.mock_vim_notify()
      local result = Utils.set_config_value('/nonexistent/file.txt', 'KEY', 'value')
      restore()

      assert.is_false(result)
    end)
  end)

  describe('config_exists', function()
    it('should return false when no config exists', function()
      local restore = helpers.mock_vim_fn({
        filereadable = function()
          return 0
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')

      assert.is_false(Utils.config_exists())

      restore()
    end)
  end)

  describe('read_config', function()
    local original_cwd

    before_each(function()
      original_cwd = vim.fn.getcwd()
    end)

    after_each(function()
      vim.cmd.cd(original_cwd)
    end)

    it('should load the port from .micropython, ignoring a v2 BAUD line', function()
      helpers.with_temp_dir(function(dir)
        vim.cmd.cd(dir)
        vim.fn.writefile(vim.split(fixtures.micropython_config, '\n'), dir .. '/.micropython')
        local _, restore = helpers.mock_vim_notify()
        Utils.read_config()
        restore()
        assert.equals('/dev/ttyUSB0', Config.get_port())
      end)
    end)

    it('should ignore a v2 .ampy config', function()
      helpers.with_temp_dir(function(dir)
        vim.cmd.cd(dir)
        vim.fn.writefile(vim.split(fixtures.ampy_config, '\n'), dir .. '/.ampy')
        local notifications, restore = helpers.mock_vim_notify()
        Utils.read_config()
        restore()
        assert.equals('auto', Config.get_port())
        assert.equals(0, #notifications)
      end)
    end)

    it('should not keep the v2 .ampy and deprecated helpers', function()
      for _, name in ipairs({
        'ampy_install_check',
        'get_ampy_path',
        'ampy_config_exists',
        'read_ampy_config',
        'get_mpremote_base',
      }) do
        assert.is_nil(Utils[name], name)
      end
    end)
  end)

  describe('pyproject_exists / requirements_exists', function()
    it('should check for pyproject.toml', function()
      local checked_path = nil
      local restore = helpers.mock_vim_fn({
        filereadable = function(path)
          checked_path = path
          return 0
        end,
        getcwd = function()
          return '/test/dir'
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')
      Utils.pyproject_exists()

      restore()
      assert.is_true(checked_path:find('pyproject.toml') ~= nil)
    end)

    it('should check for requirements.txt', function()
      local checked_path = nil
      local restore = helpers.mock_vim_fn({
        filereadable = function(path)
          checked_path = path
          return 0
        end,
        getcwd = function()
          return '/test/dir'
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')
      Utils.requirements_exists()

      restore()
      assert.is_true(checked_path:find('requirements.txt') ~= nil)
    end)
  end)

  describe('uv_available', function()
    it('should return true when uv is executable', function()
      local restore = helpers.mock_vim_fn({
        executable = function(cmd)
          return cmd == 'uv' and 1 or 0
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')

      assert.is_true(Utils.uv_available())
      restore()
    end)

    it('should return false when uv is not executable', function()
      local restore = helpers.mock_vim_fn({
        executable = function()
          return 0
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')

      assert.is_false(Utils.uv_available())
      restore()
    end)
  end)
end)
