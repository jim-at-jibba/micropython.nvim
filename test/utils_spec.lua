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

  describe('get_ampy_path', function()
    it('should return path ending with .ampy', function()
      local path = Utils.get_ampy_path()
      assert.is_true(path:match('%.ampy$') ~= nil)
    end)

    it('should include cwd in path', function()
      local path = Utils.get_ampy_path()
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

  describe('get_mpremote_base', function()
    it('should return mpremote for auto port', function()
      Config.set_port('auto')
      local base = Utils.get_mpremote_base()
      assert.equals('mpremote ', base)
    end)

    it('should return mpremote for empty port', function()
      Config.set_port('')
      local base = Utils.get_mpremote_base()
      assert.equals('mpremote ', base)
    end)

    it('should include connect arg for specific port', function()
      Config.set_port('/dev/ttyUSB0')
      local base = Utils.get_mpremote_base()
      assert.equals('mpremote connect /dev/ttyUSB0 ', base)
    end)

    it('should include connect arg for serial id', function()
      Config.set_port('id:12345678')
      local base = Utils.get_mpremote_base()
      assert.equals('mpremote connect id:12345678 ', base)
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
      local original_print = print
      print = function()
        printed = true
      end
      Utils.debug_print('test message')
      print = original_print
      assert.is_false(printed)
    end)

    it('should print when debug is enabled', function()
      Config.setup({ debug = true })
      helpers.reset_modules()
      Config = require('micropython_nvim.config')
      Config.setup({ debug = true })
      Utils = require('micropython_nvim.utils')

      local printed = false
      local original_print = print
      print = function()
        printed = true
      end
      Utils.debug_print('test message')
      print = original_print
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

  describe('replace_line', function()
    it('should replace matching line', function()
      helpers.with_temp_dir(function(tmpdir)
        local filepath = tmpdir .. '/config.txt'
        local file = io.open(filepath, 'w')
        file:write('PORT=auto\nBAUD=115200\n')
        file:close()

        local result = Utils.replace_line(filepath, 'PORT', 'PORT=/dev/ttyUSB0')

        assert.is_true(result)

        file = io.open(filepath, 'r')
        local content = file:read('*a')
        file:close()

        assert.is_true(content:find('PORT=/dev/ttyUSB0') ~= nil)
        assert.is_nil(content:find('PORT=auto'))
      end)
    end)

    it('should preserve non-matching lines', function()
      helpers.with_temp_dir(function(tmpdir)
        local filepath = tmpdir .. '/config.txt'
        local file = io.open(filepath, 'w')
        file:write('PORT=auto\nBAUD=115200\n')
        file:close()

        Utils.replace_line(filepath, 'PORT', 'PORT=/dev/ttyUSB0')

        file = io.open(filepath, 'r')
        local content = file:read('*a')
        file:close()

        assert.is_true(content:find('BAUD=115200') ~= nil)
      end)
    end)

    it('should return false for non-existent file', function()
      local notifications, restore = helpers.mock_vim_notify()
      local result = Utils.replace_line('/nonexistent/file.txt', 'needle', 'replacement')
      restore()

      assert.is_false(result)
    end)
  end)

  describe('config_exists / ampy_config_exists', function()
    it('should return false when no config exists', function()
      local restore = helpers.mock_vim_fn({
        filereadable = function()
          return 0
        end,
      })

      helpers.reset_modules()
      Utils = require('micropython_nvim.utils')

      assert.is_false(Utils.config_exists())
      assert.is_false(Utils.ampy_config_exists())

      restore()
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
