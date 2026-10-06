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

  describe('device queries', function()
    local calls
    local restore_fn

    before_each(function()
      calls = {}
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(argv, opts)
          table.insert(calls, { argv = argv, opts = opts })
          return #calls
        end,
        glob = function()
          return {}
        end,
      })
    end)

    after_each(function()
      restore_fn()
    end)

    ---@param call table
    ---@param stdout string[]
    ---@param code? integer
    local function finish(call, stdout, code)
      call.opts.on_stdout(1, stdout)
      call.opts.on_stderr(1, { '' })
      call.opts.on_exit(1, code or 0)
    end

    local connect_list_output = {
      '/dev/cu.usbmodem1101 e6614c311b7e5a2b 2e8a:0005 MicroPython Board in FS mode',
      '/dev/cu.Bluetooth-Incoming-Port None 0000:0000 None None',
      '',
    }

    it('list_devices should run connect list without a port and parse the output', function()
      require('micropython_nvim.config').set_port('/dev/ttyUSB0')
      local devices
      Setup.list_devices(function(d)
        devices = d
      end)

      local argv = calls[1].argv
      assert.same({ 'connect', 'list' }, vim.list_slice(argv, #argv - 1))
      assert.is_false(vim.tbl_contains(argv, '/dev/ttyUSB0'))
      assert.is_nil(devices)

      finish(calls[1], connect_list_output)
      assert.equals(2, #devices)
      assert.same({
        port = '/dev/cu.usbmodem1101',
        serial = 'e6614c311b7e5a2b',
        manufacturer = '2e8a:0005 MicroPython Board in FS mode',
      }, devices[1])
    end)

    it('list_devices should return no devices when mpremote fails', function()
      local devices
      Setup.list_devices(function(d)
        devices = d
      end)
      finish(calls[1], { '' }, 1)
      assert.same({}, devices)
    end)

    it('show_devices should show the mpremote error when listing fails', function()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Setup.show_devices()
      calls[1].opts.on_stdout(1, { '' })
      calls[1].opts.on_stderr(1, { 'error: Failed to spawn: `mpremote`', '' })
      calls[1].opts.on_exit(1, 2)
      restore_notify()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.equals('Failed to list devices:\nerror: Failed to spawn: `mpremote`', last.msg)
    end)

    it('set_port should offer auto plus the listed ports after mpremote answers', function()
      local offered
      package.loaded['micropython_nvim.ui'] = {
        select = function(items, _, cb)
          offered = items
          cb(nil)
        end,
      }
      package.loaded['micropython_nvim.setup'] = nil
      Setup = require('micropython_nvim.setup')

      Setup.set_port()
      assert.is_nil(offered)

      finish(calls[1], connect_list_output)
      assert.same({ 'auto', '/dev/cu.usbmodem1101', '/dev/cu.Bluetooth-Incoming-Port' }, offered)
    end)
  end)
end)
