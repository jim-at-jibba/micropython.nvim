local helpers = require('test.helpers')

describe('micropython_nvim.device', function()
  local Device
  local Config

  local INFO_OUTPUT = table.concat({
    'firmware\tv1.24.1 on 2024-11-29',
    'board\tRaspberry Pi Pico W with RP2040',
    'storage\t868352\t847872',
    'time\t2021-01-01 00:00:12',
  }, '\n')

  local PICO_W_OUTPUT = table.concat({
    'platform\trp2',
    'build\tRPI_PICO_W',
    'machine\tRaspberry Pi Pico W with RP2040',
    'version\t1.24.1\t',
  }, '\r\n')

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Config.set_port('/dev/ttyUSB0')
    Device = require('micropython_nvim.device')
  end)

  describe('parse_info', function()
    it('should read firmware, board, storage and time', function()
      assert.same({
        firmware = 'v1.24.1 on 2024-11-29',
        board = 'Raspberry Pi Pico W with RP2040',
        storage = { total = 868352, free = 847872 },
        time = '2021-01-01 00:00:12',
      }, Device.parse_info(INFO_OUTPUT))
    end)

    it('should skip storage it cannot read', function()
      assert.same({}, Device.parse_info('storage\tnope\t1'))
    end)

    it('should ignore other output and missing fields', function()
      assert.same(
        { board = 'ESP32 module with ESP32' },
        Device.parse_info('noise\r\nboard\tESP32 module with ESP32\r\n')
      )
    end)
  end)

  describe('parse_board', function()
    it('should read platform, build, machine and version', function()
      assert.same({
        platform = 'rp2',
        build = 'RPI_PICO_W',
        machine = 'Raspberry Pi Pico W with RP2040',
        version = '1.24.1',
      }, Device.parse_board(PICO_W_OUTPUT))
    end)

    it('should leave out a preview version and an empty build', function()
      local board = Device.parse_board('platform\tesp32\nbuild\t\nversion\t1.25.0\tpreview\n')
      assert.same({ platform = 'esp32' }, board)
    end)
  end)

  describe('format_info', function()
    it('should show used and free storage in readable units', function()
      local lines = Device.format_info(Device.parse_info(INFO_OUTPUT))
      assert.same({
        'Firmware:     MicroPython v1.24.1 on 2024-11-29',
        'Board:        Raspberry Pi Pico W with RP2040',
        'Storage:      20.0 KiB used of 848.0 KiB (828.0 KiB free)',
        'Device time:  2021-01-01 00:00:12',
      }, lines)
    end)

    it('should say when a field is unknown', function()
      local lines = Device.format_info({})
      assert.equals('Firmware:     unknown', lines[1])
      assert.equals('Storage:      unknown', lines[3])
    end)
  end)

  describe('mip_args', function()
    it('should install a micropython-lib package', function()
      assert.same({ 'mip', 'install', 'aioble' }, Device.mip_args('aioble'))
    end)

    it('should install a github package', function()
      assert.same({ 'mip', 'install', 'github:org/repo' }, Device.mip_args('github:org/repo'))
    end)

    it('should install into a target directory', function()
      assert.same(
        { 'mip', 'install', '--target', 'lib/ext', 'aioble' },
        Device.mip_args('aioble', 'lib/ext')
      )
    end)
  end)

  describe('mip_complete', function()
    it('should complete micropython-lib packages by prefix', function()
      local matches = Device.mip_complete('umqtt')
      assert.same({ 'umqtt.robust', 'umqtt.simple' }, matches)
    end)

    it('should not complete the target directory', function()
      assert.same({}, Device.mip_complete('', 2))
    end)

    it('should offer the github: and gitlab: sources', function()
      assert.same({ 'github:', 'gitlab:' }, Device.mip_complete('git'))
    end)
  end)

  describe('device commands', function()
    local calls
    local notifications
    local restore_fn
    local restore_notify

    before_each(function()
      calls = {}
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(argv, opts)
          table.insert(calls, { argv = argv, opts = opts })
          return #calls
        end,
      })
      notifications, restore_notify = helpers.mock_vim_notify()
    end)

    after_each(function()
      restore_fn()
      restore_notify()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative ~= '' then
          vim.api.nvim_win_close(win, true)
        end
      end
      vim.cmd('silent! only')
      vim.cmd('enew!')
    end)

    ---Finish a background mpremote call
    ---@param call table
    ---@param code integer
    ---@param stdout string
    ---@param stderr? string
    local function finish(call, code, stdout, stderr)
      call.opts.on_stdout(1, vim.split(stdout, '\n'))
      call.opts.on_stderr(1, vim.split(stderr or '', '\n'))
      call.opts.on_exit(1, code)
    end

    ---@param call table
    ---@return string[] the arguments after the connect prefix
    local function args_of(call)
      return vim.list_slice(call.argv, 4)
    end

    ---@return integer?
    local function float_window()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative ~= '' then
          return win
        end
      end
    end

    describe('info', function()
      it('should warn when the port is not configured', function()
        Config.set_port('')
        Device.info()
        assert.equals(0, #calls)
        assert.is_truthy(notifications[1].msg:find('No port configured'))
      end)

      it('should query the device in the background', function()
        Device.info()
        assert.equals(1, #calls)
        assert.same({ 'connect', '/dev/ttyUSB0', 'exec' }, vim.list_slice(calls[1].argv, 2, 4))
        assert.is_nil(float_window())
      end)

      it('should show the device info in a window', function()
        Device.info()
        finish(calls[1], 0, INFO_OUTPUT)

        local win = float_window()
        assert.is_not_nil(win)
        local text = table.concat(
          vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false),
          '\n'
        )
        assert.is_truthy(text:find('Raspberry Pi Pico W', 1, true))
        assert.is_truthy(text:find('/dev/ttyUSB0', 1, true))
        assert.is_truthy(text:find('set the device clock', 1, true))
      end)

      it('should report the mpremote error', function()
        Device.info()
        finish(calls[1], 1, '', 'mpremote: failed to access /dev/ttyUSB0')

        assert.is_nil(float_window())
        local last = notifications[#notifications]
        assert.equals(vim.log.levels.ERROR, last.level)
        assert.is_truthy(last.msg:find('failed to access', 1, true))
      end)

      it('should set the device clock from the host with s', function()
        Device.info()
        finish(calls[1], 0, INFO_OUTPUT)
        local win = float_window()
        vim.api.nvim_set_current_win(win)

        vim.api.nvim_feedkeys('s', 'x', false)

        assert.same({ 'rtc', '--set' }, args_of(calls[2]))
        assert.is_nil(float_window())
      end)

      it('should close the window with q', function()
        Device.info()
        finish(calls[1], 0, INFO_OUTPUT)
        vim.api.nvim_set_current_win(float_window())

        vim.api.nvim_feedkeys('q', 'x', false)

        assert.is_nil(float_window())
        assert.equals(1, #calls)
      end)
    end)

    describe('mip', function()
      it('should warn when the port is not configured', function()
        Config.set_port('')
        Device.mip({ 'aioble' })
        assert.equals(0, #calls)
      end)

      it('should install a package in the background and report success', function()
        Device.mip({ 'aioble' })
        assert.same({ 'mip', 'install', 'aioble' }, args_of(calls[1]))

        finish(calls[1], 0, 'Install aioble\nDone')
        local last = notifications[#notifications]
        assert.equals(vim.log.levels.INFO, last.level)
        assert.is_truthy(last.msg:find('aioble', 1, true))
      end)

      it('should pass a target directory', function()
        Device.mip({ 'github:org/repo', 'lib/ext' })
        assert.same(
          { 'mip', 'install', '--target', 'lib/ext', 'github:org/repo' },
          args_of(calls[1])
        )
      end)

      it('should report the mpremote error', function()
        Device.mip({ 'nope' })
        finish(calls[1], 1, 'Install nope\nPackage not found: nope')
        local last = notifications[#notifications]
        assert.equals(vim.log.levels.ERROR, last.level)
        assert.is_truthy(last.msg:find('Package not found', 1, true))
      end)

      it('should refuse more than a package and a target', function()
        Device.mip({ 'a', 'b', 'c' })
        assert.equals(0, #calls)
        assert.is_truthy(notifications[1].msg:find('Usage', 1, true))
      end)

      it('should offer a picker of packages when none is given', function()
        local offered
        package.loaded['micropython_nvim.ui'] = {
          select = function(items, _, on_choice)
            offered = items
            on_choice('umqtt.simple')
          end,
        }

        Device.mip({})

        assert.is_true(vim.tbl_contains(offered, 'aioble'))
        assert.same({ 'mip', 'install', 'umqtt.simple' }, args_of(calls[1]))
      end)
    end)
  end)

  describe('commands', function()
    before_each(function()
      vim.cmd('runtime plugin/micropython_nvim.lua')
    end)

    it('should complete :MP mip packages', function()
      assert.same({ 'aioble', 'aiohttp', 'aiorepl' }, vim.fn.getcompletion('MP mip aio', 'cmdline'))
    end)

    it('should not complete packages in the target slot', function()
      assert.same({}, vim.fn.getcompletion('MP mip aioble ', 'cmdline'))
    end)
  end)
end)
