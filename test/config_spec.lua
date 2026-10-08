local helpers = require('test.helpers')

describe('micropython_nvim.config', function()
  local Config

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
  end)

  describe('setup', function()
    it('should use defaults when no options provided', function()
      Config.setup()
      assert.equals('auto', Config.get_port())
      assert.is_false(Config.is_debug())
    end)

    it('should have no baud rate setting', function()
      Config.setup({})
      assert.is_nil(Config.config.baud)
      assert.is_nil(Config.get_baud)
    end)

    it('should use defaults with empty options', function()
      Config.setup({})
      assert.equals('auto', Config.get_port())
      assert.is_false(Config.is_debug())
    end)

    it('should merge user options with defaults', function()
      Config.setup({ port = '/dev/ttyUSB0', debug = true })
      assert.equals('/dev/ttyUSB0', Config.get_port())
      assert.is_true(Config.is_debug())
    end)

    it('should preserve ui config', function()
      Config.setup({ ui = { picker_layout = 'dropdown' } })
      assert.equals('dropdown', Config.config.ui.picker_layout)
    end)

    it('should use default ui config when not provided', function()
      Config.setup({})
      assert.equals('select', Config.config.ui.picker_layout)
    end)
  end)

  describe('get_port / set_port', function()
    it('should have default port as auto', function()
      assert.equals('auto', Config.get_port())
    end)

    it('should set port correctly', function()
      Config.set_port('/dev/ttyUSB0')
      assert.equals('/dev/ttyUSB0', Config.get_port())
    end)

    it('should handle various port formats', function()
      local ports = {
        '/dev/ttyUSB0',
        '/dev/ttyACM0',
        '/dev/tty.usbmodem1234',
        'COM3',
        'id:12345678',
        'auto',
      }
      for _, port in ipairs(ports) do
        Config.set_port(port)
        assert.equals(port, Config.get_port())
      end
    end)
  end)

  describe('is_debug', function()
    it('should return false when debug not set', function()
      Config.setup({})
      assert.is_false(Config.is_debug())
    end)

    it('should return false when debug is false', function()
      Config.setup({ debug = false })
      assert.is_false(Config.is_debug())
    end)

    it('should return true when debug is true', function()
      Config.setup({ debug = true })
      assert.is_true(Config.is_debug())
    end)

    it('should return false for nil debug', function()
      Config.setup({ debug = nil })
      assert.is_false(Config.is_debug())
    end)
  end)

  describe('is_port_configured', function()
    it('should report port as configured when set to specific port', function()
      Config.set_port('/dev/ttyACM0')
      assert.is_true(Config.is_port_configured())
    end)

    it('should report port as configured for auto', function()
      Config.set_port('auto')
      assert.is_true(Config.is_port_configured())
    end)

    it('should report port as not configured for empty string', function()
      Config.set_port('')
      assert.is_false(Config.is_port_configured())
    end)
  end)

  describe('state persistence', function()
    it('should reset state on setup', function()
      Config.set_port('/dev/ttyUSB0')

      Config.setup({})

      assert.equals('auto', Config.get_port())
    end)
  end)
end)
