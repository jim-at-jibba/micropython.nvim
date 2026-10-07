local helpers = require('test.helpers')
local fixtures = require('test.fixtures')

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

  describe('set_stubs', function()
    local original_cwd
    local installed
    local notifications
    local restore_notify

    ---Pick `choice` whenever stubs are chosen
    ---@param choice string?
    local function choose(choice)
      local Stubs = require('micropython_nvim.stubs')
      Stubs.choose = function(on_choice)
        on_choice(choice)
      end
      Stubs.install = function(requirement)
        installed = requirement
      end
    end

    before_each(function()
      original_cwd = vim.fn.getcwd()
      installed = nil
      notifications, restore_notify = helpers.mock_vim_notify()
    end)

    after_each(function()
      restore_notify()
      vim.fn.chdir(original_cwd)
    end)

    it('should switch the stubs in pyproject.toml and install them', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        choose('micropython-esp32-stubs==1.24.1.*')

        Setup.set_stubs()

        local pyproject = table.concat(vim.fn.readfile(dir .. '/pyproject.toml'), '\n')
        assert.is_truthy(pyproject:find('"micropython-esp32-stubs==1.24.1.*",', 1, true))
        assert.is_nil(pyproject:find('micropython-rp2-stubs', 1, true))
        assert.equals('micropython-esp32-stubs==1.24.1.*', installed)
      end)
    end)

    it('should switch the stubs in requirements.txt', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.requirements_txt, '\n'), dir .. '/requirements.txt')
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        assert.same(
          { 'mpremote', 'micropython-esp32-stubs', '' },
          vim.fn.readfile(dir .. '/requirements.txt')
        )
      end)
    end)

    it('should point an existing pyright config at the stubs', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        vim.fn.writefile(
          { '{', '  "reportMissingModuleSource": false', '}' },
          dir .. '/pyrightconfig.json'
        )
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        local config = vim.json.decode(table.concat(vim.fn.readfile(dir .. '/pyrightconfig.json')))
        assert.equals('typings', config.stubPath)
        assert.is_true(vim.tbl_contains(config.exclude, 'typings'))
        assert.is_false(config.reportMissingModuleSource)
      end)
    end)

    it('should keep the excludes an existing pyright config sets', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        vim.fn.writefile({ '{ "exclude": ["build"] }' }, dir .. '/pyrightconfig.json')
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        local config = vim.json.decode(table.concat(vim.fn.readfile(dir .. '/pyrightconfig.json')))
        assert.same({ stubPath = 'typings', exclude = { 'build' } }, config)
      end)
    end)

    it('should leave a pyright config that already sets the stub path', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        vim.fn.writefile({ '{ "stubPath": "stubs" }' }, dir .. '/pyrightconfig.json')
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        assert.same({ '{ "stubPath": "stubs" }' }, vim.fn.readfile(dir .. '/pyrightconfig.json'))
      end)
    end)

    it('should create a pyright config when the project has none', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        local config = vim.json.decode(table.concat(vim.fn.readfile(dir .. '/pyrightconfig.json')))
        assert.equals('typings', config.stubPath)
      end)
    end)

    it('should not create a pyright config when pyproject.toml configures pyright', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(
          vim.list_extend(vim.split(fixtures.pyproject_toml, '\n'), { '[tool.pyright]' }),
          dir .. '/pyproject.toml'
        )
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        assert.equals(0, vim.fn.filereadable(dir .. '/pyrightconfig.json'))
      end)
    end)

    it('should change nothing when the picker is cancelled', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')
        choose(nil)

        Setup.set_stubs()

        assert.same(
          vim.split(fixtures.pyproject_toml, '\n'),
          vim.fn.readfile(dir .. '/pyproject.toml')
        )
        assert.is_nil(installed)
      end)
    end)

    it('should ask for a project first when there is none', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        choose('micropython-esp32-stubs')

        Setup.set_stubs()

        assert.is_truthy(notifications[1].msg:find(':MP init', 1, true))
        assert.is_nil(installed)
      end)
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
