local helpers = require('test.helpers')

describe('micropython_nvim.setup', function()
  local Setup

  before_each(function()
    helpers.reset_modules()
    require('micropython_nvim.config').setup({})
    Setup = require('micropython_nvim.setup')
  end)

  describe('BAUD_RATES', function()
    it('should be a table', function()
      assert.is_table(Setup.BAUD_RATES)
    end)

    it('should have multiple options', function()
      assert.is_true(#Setup.BAUD_RATES > 0)
    end)

    it('should contain 115200', function()
      assert.is_true(vim.tbl_contains(Setup.BAUD_RATES, '115200'))
    end)

    it('should contain 9600', function()
      assert.is_true(vim.tbl_contains(Setup.BAUD_RATES, '19200'))
    end)

    it('should contain 1200', function()
      assert.is_true(vim.tbl_contains(Setup.BAUD_RATES, '1200'))
    end)

    it('should contain 57600', function()
      assert.is_true(vim.tbl_contains(Setup.BAUD_RATES, '57600'))
    end)

    it('should have all values as strings', function()
      for _, rate in ipairs(Setup.BAUD_RATES) do
        assert.is_string(rate)
      end
    end)

    it('should have all values as valid numbers', function()
      for _, rate in ipairs(Setup.BAUD_RATES) do
        assert.is_not_nil(tonumber(rate))
      end
    end)
  end)

  describe('STUB_OPTIONS', function()
    it('should be a table', function()
      assert.is_table(Setup.STUB_OPTIONS)
    end)

    it('should have multiple options', function()
      assert.is_true(#Setup.STUB_OPTIONS > 0)
    end)

    it('should contain rp2 stubs', function()
      assert.is_true(vim.tbl_contains(Setup.STUB_OPTIONS, 'micropython-rp2-stubs'))
    end)

    it('should contain esp32 stubs', function()
      assert.is_true(vim.tbl_contains(Setup.STUB_OPTIONS, 'micropython-esp32-stubs'))
    end)

    it('should contain esp8266 stubs', function()
      assert.is_true(vim.tbl_contains(Setup.STUB_OPTIONS, 'micropython-esp8266-stubs'))
    end)

    it('should contain stm32 stubs', function()
      assert.is_true(vim.tbl_contains(Setup.STUB_OPTIONS, 'micropython-stm32-stubs'))
    end)

    it('should have all values following naming convention', function()
      for _, stub in ipairs(Setup.STUB_OPTIONS) do
        assert.is_true(stub:match('^micropython%-.*%-stubs$') ~= nil)
      end
    end)
  end)

  describe('list_devices', function()
    it('should return a table', function()
      local devices = Setup.list_devices()
      assert.is_table(devices)
    end)
  end)
end)
