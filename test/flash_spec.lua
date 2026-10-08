local helpers = require('test.helpers')

describe('micropython_nvim.flash', function()
  local Flash
  local Config

  local TAGS = table.concat({
    'aaa\trefs/tags/v1.9.4',
    'bbb\trefs/tags/v1.24.0',
    'ccc\trefs/tags/v1.24.1',
    'ddd\trefs/tags/v1.25.0-preview',
    'eee\trefs/tags/v1.25.0',
    'fff\trefs/tags/v1.19',
  }, '\n')

  local PICO_W_OUTPUT = table.concat({
    'platform\trp2',
    'build\tRPI_PICO_W',
    'machine\tRaspberry Pi Pico W with RP2040',
    'version\t1.24.1\t',
  }, '\n')

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Config.set_port('/dev/ttyUSB0')
    Flash = require('micropython_nvim.flash')
  end)

  describe('parse_versions', function()
    it('should list releases newest first, without previews', function()
      assert.same({ '1.25.0', '1.24.1', '1.24.0', '1.9.4' }, Flash.parse_versions(TAGS))
    end)

    it('should keep only the most recent releases', function()
      local lines = {}
      for minor = 1, 20 do
        table.insert(lines, 'x\trefs/tags/v1.' .. minor .. '.0')
      end
      local versions = Flash.parse_versions(table.concat(lines, '\n'))
      assert.equals(Flash.MAX_VERSIONS, #versions)
      assert.equals('1.20.0', versions[1])
    end)
  end)

  describe('argv', function()
    it('should flash a version to a serial port', function()
      assert.same(
        { 'mpflash', 'flash', '--version', 'stable', '--serial', '/dev/ttyUSB0' },
        Flash.argv({ 'mpflash' }, 'stable', { serial = '/dev/ttyUSB0', detected = true })
      )
    end)

    it('should let mpflash ask for the board when none was detected', function()
      assert.same(
        { 'uv', 'run', 'mpflash', 'flash', '--version', '1.24.1', '--board', '?' },
        Flash.argv({ 'uv', 'run', 'mpflash' }, '1.24.1', { detected = false })
      )
    end)
  end)

  describe('mpflash', function()
    it('should prefer mpflash on PATH, then the uv project venv', function()
      helpers.with_temp_dir(function(dir)
        local restore = helpers.mock_vim_fn({
          getcwd = function()
            return dir
          end,
          executable = function(name)
            return (name == 'uv' or name == dir .. '/.venv/bin/mpflash') and 1 or 0
          end,
        })
        assert.is_nil(Flash.mpflash())
        vim.fn.writefile({ '[project]' }, dir .. '/pyproject.toml')
        local found = Flash.mpflash()
        restore()
        assert.same({ 'uv', 'run', 'mpflash' }, found)
      end)
    end)
  end)

  describe('flash', function()
    local jobs
    local notifications
    local restore_fn
    local restore_notify
    local opened
    local picked
    local has_mpflash

    ---@param argv string[]
    ---@return string
    local function kind(argv)
      if argv[1] == 'git' then
        return 'tags'
      end
      if vim.tbl_contains(argv, 'exec') then
        return 'detect'
      end
      if vim.tbl_contains(argv, 'list') then
        return 'list'
      end
      return argv[1]
    end

    ---@param name string
    ---@param code integer
    ---@param stdout string
    local function finish(name, code, stdout)
      for _, job in ipairs(jobs) do
        if kind(job.argv) == name and not job.done then
          job.done = true
          job.opts.on_stdout(1, vim.split(stdout, '\n'))
          job.opts.on_stderr(1, { '' })
          job.opts.on_exit(1, code)
          return
        end
      end
      error('no running ' .. name .. ' job')
    end

    ---@return string[]
    local function kinds()
      return vim.tbl_map(function(job)
        return kind(job.argv)
      end, jobs)
    end

    before_each(function()
      jobs, opened, picked = {}, {}, nil
      has_mpflash = true
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(argv, opts)
          table.insert(jobs, { argv = argv, opts = opts })
          return #jobs
        end,
        executable = function(name)
          if name == 'mpflash' then
            return has_mpflash and 1 or 0
          end
          return 0
        end,
      })
      notifications, restore_notify = helpers.mock_vim_notify()
      package.loaded['micropython_nvim.terminal'] = {
        open = function(command)
          table.insert(opened, command)
        end,
      }
      package.loaded['micropython_nvim.ui'] = {
        select = function(items, opts, on_choice)
          picked = { items = items, prompt = opts.prompt }
          on_choice(items[1])
        end,
      }
    end)

    after_each(function()
      restore_fn()
      restore_notify()
    end)

    it('should explain how to install mpflash when it is missing', function()
      has_mpflash = false
      Flash.flash({})

      assert.equals(0, #jobs)
      assert.equals(0, #opened)
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
      assert.is_truthy(notifications[1].msg:find('mpflash not found', 1, true))
      assert.is_truthy(notifications[1].msg:find(Flash.INSTALL_HINT, 1, true))
    end)

    it('should detect the board and offer versions, latest stable first', function()
      Flash.flash({})
      assert.same({ 'detect', 'tags' }, kinds())

      finish('detect', 0, PICO_W_OUTPUT)
      assert.is_nil(picked)
      finish('tags', 0, TAGS)

      assert.same({ 'stable', 'preview', '1.25.0', '1.24.1', '1.24.0', '1.9.4' }, picked.items)
      assert.is_truthy(picked.prompt:find('Raspberry Pi Pico W with RP2040', 1, true))
      assert.is_truthy(picked.prompt:find('1.24.1', 1, true))
    end)

    it('should flash the chosen version in a terminal', function()
      Flash.flash({})
      finish('detect', 0, PICO_W_OUTPUT)
      finish('tags', 0, TAGS)

      assert.equals(1, #opened)
      local command = opened[1]
      assert.is_truthy(command:find("'mpflash' 'flash' '--version' 'stable'", 1, true))
      assert.is_truthy(command:find("'--serial' '/dev/ttyUSB0'", 1, true))
      assert.is_falsy(command:find('--board', 1, true))
      assert.is_truthy(command:find('2>&1', 1, true))
    end)

    it('should still offer stable and preview when releases cannot be fetched', function()
      Flash.flash({})
      finish('detect', 0, PICO_W_OUTPUT)
      finish('tags', 128, '')
      assert.same({ 'stable', 'preview' }, picked.items)
    end)

    it('should flash a version given as an argument without a picker', function()
      Flash.flash({ '1.24.1' })
      assert.same({ 'detect' }, kinds())
      finish('detect', 0, PICO_W_OUTPUT)

      assert.is_nil(picked)
      assert.is_truthy(opened[1]:find("'--version' '1.24.1'", 1, true))
    end)

    it('should do nothing when the picker is cancelled', function()
      package.loaded['micropython_nvim.ui'].select = function(_, _, on_choice)
        on_choice(nil)
      end
      Flash.flash({})
      finish('detect', 0, PICO_W_OUTPUT)
      finish('tags', 0, TAGS)
      assert.equals(0, #opened)
    end)

    it('should let mpflash ask for the board when MicroPython does not answer', function()
      Flash.flash({ 'stable' })
      finish('detect', 1, '')

      assert.is_truthy(opened[1]:find("'--board' '?'", 1, true))
      assert.is_truthy(opened[1]:find("'--serial' '/dev/ttyUSB0'", 1, true))
    end)

    it('should resolve an auto port to the connected device', function()
      Config.set_port('auto')
      Flash.flash({ 'stable' })
      assert.same({ 'detect', 'list' }, kinds())

      finish('detect', 0, PICO_W_OUTPUT)
      finish(
        'list',
        0,
        '/dev/cu.Bluetooth None 0000:0000 None None\n'
          .. '/dev/cu.usbmodem101 e6614c311b7e6f35 2e8a:0005 MicroPython Board'
      )

      assert.is_truthy(opened[1]:find("'--serial' '/dev/cu.usbmodem101'", 1, true))
    end)

    it('should resolve an id: port to the device with that serial number', function()
      Config.set_port('id:e6614c311b7e6f35')
      Flash.flash({ 'stable' })
      finish('detect', 0, PICO_W_OUTPUT)
      finish(
        'list',
        0,
        '/dev/cu.usbmodem1 0000 2e8a:0005 Other\n/dev/cu.usbmodem2 e6614c311b7e6f35 2e8a:0005 Pico'
      )

      assert.is_truthy(opened[1]:find("'--serial' '/dev/cu.usbmodem2'", 1, true))
    end)

    it('should not flash every board when the port cannot be resolved', function()
      Config.set_port('auto')
      Flash.flash({ 'stable' })
      finish('detect', 0, PICO_W_OUTPUT)
      finish('list', 0, '')

      assert.equals(0, #opened)
      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.is_truthy(last.msg:find(':MP set_port', 1, true))
      assert.is_truthy(last.msg:find('BOOTSEL', 1, true))
    end)

    it('should close the REPL so mpflash can use the serial port', function()
      local closed = false
      package.loaded['micropython_nvim.repl'] = {
        is_running = function()
          return true
        end,
        close = function()
          closed = true
        end,
      }
      Flash.flash({ 'stable' })
      assert.is_true(closed)
      assert.equals(0, #jobs)

      vim.wait(2000, function()
        return #jobs > 0
      end)
      assert.same({ 'detect' }, kinds())
    end)
  end)

  describe('commands', function()
    before_each(function()
      vim.cmd('runtime plugin/micropython_nvim.lua')
    end)

    it('should complete :MP flash versions', function()
      assert.same({ 'preview' }, vim.fn.getcompletion('MP flash pre', 'cmdline'))
      assert.same({ 'stable' }, vim.fn.getcompletion('MP flash s', 'cmdline'))
    end)
  end)
end)
