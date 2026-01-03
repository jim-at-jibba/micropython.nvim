local helpers = require('test.helpers')

describe('micropython_nvim', function()
  local M
  local Config

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    M = require('micropython_nvim')
  end)

  describe('setup', function()
    it('should be a function', function()
      assert.is_function(M.setup)
    end)

    it('should configure the plugin', function()
      M.setup({ port = '/dev/ttyUSB0', baud = 9600 })

      helpers.reset_modules()
      Config = require('micropython_nvim.config')

      assert.equals('/dev/ttyUSB0', Config.get_port())
      assert.equals('9600', Config.get_baud())
    end)
  end)

  describe('statusline', function()
    it('should be a function', function()
      assert.is_function(M.statusline)
    end)

    it('should return auto format for auto port', function()
      Config.set_port('auto')
      assert.equals(' auto', M.statusline())
    end)

    it('should return port and baud for specific port', function()
      Config.set_port('/dev/ttyUSB0')
      Config.set_baud('9600')
      assert.equals(' P:/dev/ttyUSB0 BR:9600', M.statusline())
    end)

    it('should include microchip icon', function()
      local result = M.statusline()
      assert.is_true(result:find('') ~= nil)
    end)
  end)

  describe('exists', function()
    it('should be a function', function()
      assert.is_function(M.exists)
    end)

    it('should return boolean', function()
      local result = M.exists()
      assert.is_boolean(result)
    end)
  end)

  describe('initialise (deprecated)', function()
    it('should be a function', function()
      assert.is_function(M.initialise)
    end)

    it('should show deprecation warning', function()
      local notifications, restore = helpers.mock_vim_notify()

      M.initialise()

      restore()
      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:find('deprecated') ~= nil)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe('public API functions exist', function()
    it('should have run', function()
      assert.is_function(M.run)
    end)

    it('should have repl', function()
      assert.is_function(M.repl)
    end)

    it('should have upload_current', function()
      assert.is_function(M.upload_current)
    end)

    it('should have upload_all', function()
      assert.is_function(M.upload_all)
    end)

    it('should have set_baud_rate', function()
      assert.is_function(M.set_baud_rate)
    end)

    it('should have set_port', function()
      assert.is_function(M.set_port)
    end)

    it('should have set_stubs', function()
      assert.is_function(M.set_stubs)
    end)

    it('should have erase_all', function()
      assert.is_function(M.erase_all)
    end)

    it('should have erase_one', function()
      assert.is_function(M.erase_one)
    end)

    it('should have init', function()
      assert.is_function(M.init)
    end)

    it('should have install', function()
      assert.is_function(M.install)
    end)

    it('should have sync', function()
      assert.is_function(M.sync)
    end)

    it('should have soft_reset', function()
      assert.is_function(M.soft_reset)
    end)

    it('should have hard_reset', function()
      assert.is_function(M.hard_reset)
    end)

    it('should have list_devices', function()
      assert.is_function(M.list_devices)
    end)

    it('should have list_files', function()
      assert.is_function(M.list_files)
    end)

    it('should have run_main', function()
      assert.is_function(M.run_main)
    end)
  end)
end)
