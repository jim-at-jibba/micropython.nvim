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
      assert.equals('115200', Config.get_baud())
      assert.is_false(Config.is_debug())
    end)

    it('should use defaults with empty options', function()
      Config.setup({})
      assert.equals('auto', Config.get_port())
      assert.equals('115200', Config.get_baud())
      assert.is_false(Config.is_debug())
    end)

    it('should merge user options with defaults', function()
      Config.setup({ port = '/dev/ttyUSB0', baud = 9600, debug = true })
      assert.equals('/dev/ttyUSB0', Config.get_port())
      assert.equals('9600', Config.get_baud())
      assert.is_true(Config.is_debug())
    end)

    it('should convert numeric baud to string', function()
      Config.setup({ baud = 9600 })
      assert.equals('9600', Config.get_baud())
      assert.is_string(Config.get_baud())
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

  describe('get_baud / set_baud', function()
    it('should have default baud rate as 115200', function()
      assert.equals('115200', Config.get_baud())
    end)

    it('should set baud rate correctly', function()
      Config.set_baud('9600')
      assert.equals('9600', Config.get_baud())
    end)

    it('should handle various baud rates', function()
      local rates = { '1200', '2400', '4800', '9600', '19200', '38400', '57600', '115200' }
      for _, rate in ipairs(rates) do
        Config.set_baud(rate)
        assert.equals(rate, Config.get_baud())
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

  describe('get_connect_arg', function()
    it('should return empty string for auto port', function()
      Config.set_port('auto')
      assert.equals('', Config.get_connect_arg())
    end)

    it('should return empty string for empty port', function()
      Config.set_port('')
      assert.equals('', Config.get_connect_arg())
    end)

    it('should return connect arg for specific port', function()
      Config.set_port('/dev/ttyUSB0')
      assert.equals('connect /dev/ttyUSB0', Config.get_connect_arg())
    end)

    it('should return connect arg for serial id', function()
      Config.set_port('id:12345678')
      assert.equals('connect id:12345678', Config.get_connect_arg())
    end)
  end)

  describe('state persistence', function()
    it('should maintain state across multiple operations', function()
      Config.set_port('/dev/ttyUSB0')
      Config.set_baud('9600')

      assert.equals('/dev/ttyUSB0', Config.get_port())
      assert.equals('9600', Config.get_baud())

      Config.set_port('/dev/ttyACM0')
      assert.equals('/dev/ttyACM0', Config.get_port())
      assert.equals('9600', Config.get_baud())
    end)

    it('should reset state on setup', function()
      Config.set_port('/dev/ttyUSB0')
      Config.set_baud('9600')

      Config.setup({})

      assert.equals('auto', Config.get_port())
      assert.equals('115200', Config.get_baud())
    end)
  end)
end)
