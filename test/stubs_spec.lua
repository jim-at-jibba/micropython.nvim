local helpers = require('test.helpers')

describe('micropython_nvim.stubs', function()
  local Stubs
  local Config

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
    Stubs = require('micropython_nvim.stubs')
  end)

  describe('PACKAGES', function()
    it('should list port and board stub packages', function()
      assert.is_true(vim.tbl_contains(Stubs.PACKAGES, 'micropython-rp2-stubs'))
      assert.is_true(vim.tbl_contains(Stubs.PACKAGES, 'micropython-rp2-rpi_pico_w-stubs'))
      assert.is_true(vim.tbl_contains(Stubs.PACKAGES, 'micropython-esp32-stubs'))
      for _, name in ipairs(Stubs.PACKAGES) do
        assert.is_truthy(name:match('^micropython%-[%w_%-]+%-stubs$'), name)
      end
    end)
  end)

  describe('parse_board', function()
    it('should read platform, build, machine and version', function()
      assert.same({
        platform = 'rp2',
        build = 'RPI_PICO_W',
        machine = 'Raspberry Pi Pico W with RP2040',
        version = '1.24.1',
      }, Stubs.parse_board(PICO_W_OUTPUT))
    end)

    it('should leave out a preview version and an empty build', function()
      local board = Stubs.parse_board('platform\tesp32\nbuild\t\nversion\t1.25.0\tpreview\n')
      assert.same({ platform = 'esp32' }, board)
    end)
  end)

  describe('packages_for', function()
    local function packages(platform, build)
      return Stubs.packages_for({ platform = platform, build = build })
    end

    it('should map a board build to its board and port packages', function()
      assert.same({
        'micropython-rp2-rpi_pico_w-stubs',
        'micropython-rp2-stubs',
      }, packages('rp2', 'RPI_PICO_W'))
    end)

    it('should drop the firmware variant from the build', function()
      assert.same({
        'micropython-esp32-esp32_generic_s3-stubs',
        'micropython-esp32-stubs',
      }, packages('esp32', 'ESP32_GENERIC_S3-SPIRAM_OCT'))
    end)

    it('should map platforms whose name differs from the port', function()
      assert.same(
        { 'micropython-stm32-pybv11-stubs', 'micropython-stm32-stubs' },
        packages('pyboard', 'PYBV11')
      )
      assert.same({ 'micropython-nrf-stubs' }, packages('nrf52'))
      assert.same({ 'micropython-unix-stubs' }, packages('linux'))
      assert.same({ 'micropython-windows-stubs' }, packages('win32'))
    end)

    it('should only offer the port package without a build', function()
      assert.same({ 'micropython-esp8266-stubs' }, packages('esp8266'))
    end)

    it('should offer nothing for an unknown platform', function()
      assert.same({}, packages('zephyr', 'SOMETHING'))
    end)
  end)

  describe('requirement', function()
    it('should pin the MicroPython version, allowing post releases', function()
      assert.equals(
        'micropython-rp2-stubs==1.24.1.*',
        Stubs.requirement('micropython-rp2-stubs', '1.24.1')
      )
    end)

    it('should leave the version open when unknown', function()
      assert.equals('micropython-rp2-stubs', Stubs.requirement('micropython-rp2-stubs'))
    end)
  end)

  describe('find_requirement', function()
    local original_cwd

    before_each(function()
      original_cwd = vim.fn.getcwd()
    end)

    after_each(function()
      vim.fn.chdir(original_cwd)
    end)

    it('should read the stubs from pyproject.toml', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile({
          '[tool.uv]',
          'dev-dependencies = [',
          '    "micropython-rp2-rpi_pico_w-stubs==1.24.1.*",',
          ']',
        }, dir .. '/pyproject.toml')
        assert.equals('micropython-rp2-rpi_pico_w-stubs==1.24.1.*', Stubs.find_requirement())
      end)
    end)

    it('should read the stubs from requirements.txt', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile({ 'mpremote', 'micropython-esp32-stubs' }, dir .. '/requirements.txt')
        assert.equals('micropython-esp32-stubs', Stubs.find_requirement())
      end)
    end)

    it('should not mistake the stdlib stubs for board stubs', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile({ '"micropython-stdlib-stubs",' }, dir .. '/pyproject.toml')
        assert.is_nil(Stubs.find_requirement())
      end)
    end)
  end)

  describe('with jobs', function()
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
        executable = function(name)
          return name == 'uv' and 1 or 0
        end,
      })
      notifications, restore_notify = helpers.mock_vim_notify()
    end)

    after_each(function()
      restore_fn()
      restore_notify()
    end)

    ---@param call table
    ---@param code integer
    ---@param stdout? string
    ---@param stderr? string
    local function finish(call, code, stdout, stderr)
      if call.opts.on_stdout then
        call.opts.on_stdout(1, vim.split(stdout or '', '\n'))
      end
      if call.opts.on_stderr then
        call.opts.on_stderr(1, vim.split(stderr or '', '\n'))
      end
      call.opts.on_exit(1, code)
    end

    ---PyPI JSON listing the given releases
    ---@param releases string[]
    ---@return string
    local function pypi(releases)
      local map = {}
      for _, release in ipairs(releases) do
        map[release] = {}
      end
      return vim.json.encode({ releases = map })
    end

    ---@param name string
    ---@return table?
    local function pypi_call(name)
      for _, call in ipairs(calls) do
        if
          call.argv[1] == 'curl' and call.argv[#call.argv]:find('/' .. name .. '/json', 1, true)
        then
          return call
        end
      end
    end

    describe('suggest', function()
      it('should detect the board on the device', function()
        Stubs.suggest(function() end)
        assert.is_truthy(vim.tbl_contains(calls[1].argv, 'exec'))
      end)

      it('should suggest the board package pinned to the firmware version', function()
        local result
        Stubs.suggest(function(suggestions, board)
          result = { suggestions = suggestions, board = board }
        end)
        finish(calls[1], 0, PICO_W_OUTPUT)
        finish(pypi_call('micropython-rp2-rpi_pico_w-stubs'), 0, pypi({ '1.24.1.post2', '1.25.0' }))
        finish(pypi_call('micropython-rp2-stubs'), 0, pypi({ '1.24.1.post1' }))

        assert.same({
          'micropython-rp2-rpi_pico_w-stubs==1.24.1.*',
          'micropython-rp2-stubs==1.24.1.*',
        }, result.suggestions)
        assert.equals('Raspberry Pi Pico W with RP2040', result.board.machine)
      end)

      it('should leave the version open when PyPI has no stubs for it', function()
        local result
        Stubs.suggest(function(suggestions)
          result = suggestions
        end)
        finish(calls[1], 0, PICO_W_OUTPUT)
        finish(pypi_call('micropython-rp2-rpi_pico_w-stubs'), 0, pypi({ '1.25.0.post1' }))
        finish(pypi_call('micropython-rp2-stubs'), 0, pypi({ '1.24.1.post1' }))

        assert.same(
          { 'micropython-rp2-rpi_pico_w-stubs', 'micropython-rp2-stubs==1.24.1.*' },
          result
        )
      end)

      it('should skip a board package PyPI does not have', function()
        local result
        Stubs.suggest(function(suggestions)
          result = suggestions
        end)
        finish(calls[1], 0, PICO_W_OUTPUT)
        finish(
          pypi_call('micropython-rp2-rpi_pico_w-stubs'),
          22,
          '',
          'The requested URL returned error: 404'
        )
        finish(pypi_call('micropython-rp2-stubs'), 0, pypi({ '1.24.1.post1' }))

        assert.same({ 'micropython-rp2-stubs==1.24.1.*' }, result)
      end)

      it('should suggest unpinned packages when PyPI cannot be reached', function()
        local result
        Stubs.suggest(function(suggestions)
          result = suggestions
        end)
        finish(calls[1], 0, PICO_W_OUTPUT)
        finish(pypi_call('micropython-rp2-rpi_pico_w-stubs'), 6, '', 'Could not resolve host')
        finish(pypi_call('micropython-rp2-stubs'), 6, '', 'Could not resolve host')

        assert.same({ 'micropython-rp2-rpi_pico_w-stubs', 'micropython-rp2-stubs' }, result)
      end)

      it('should suggest nothing when no device answers', function()
        local result
        Stubs.suggest(function(suggestions, board)
          result = { suggestions = suggestions, board = board }
        end)
        finish(calls[1], 1, '', 'mpremote: no device found')

        assert.same({}, result.suggestions)
        assert.is_nil(result.board)
        assert.equals(1, #calls)
      end)

      it('should not query a device when the port is empty', function()
        Config.set_port('')
        local result
        Stubs.suggest(function(suggestions)
          result = suggestions
        end)
        assert.same({}, result)
        assert.equals(0, #calls)
      end)
    end)

    describe('choose', function()
      local offered
      local prompt
      local picked

      before_each(function()
        offered, prompt, picked = nil, nil, false
        package.loaded['micropython_nvim.ui'] = {
          select = function(items, opts, on_choice)
            offered, prompt = items, opts.prompt
            on_choice(items[1])
          end,
        }
      end)

      it('should offer the detected stubs first, then every known package', function()
        Stubs.choose(function(choice)
          picked = choice
        end)
        finish(calls[1], 0, PICO_W_OUTPUT)
        finish(pypi_call('micropython-rp2-rpi_pico_w-stubs'), 0, pypi({ '1.24.1.post2' }))
        finish(pypi_call('micropython-rp2-stubs'), 0, pypi({ '1.24.1.post1' }))

        assert.equals('micropython-rp2-rpi_pico_w-stubs==1.24.1.*', offered[1])
        assert.equals('micropython-rp2-stubs==1.24.1.*', offered[2])
        assert.is_true(vim.tbl_contains(offered, 'micropython-esp32-stubs'))
        assert.is_false(vim.tbl_contains(offered, 'micropython-rp2-stubs'))
        assert.is_truthy(prompt:find('Raspberry Pi Pico W with RP2040', 1, true))
        assert.is_truthy(prompt:find('1.24.1', 1, true))
        assert.equals('micropython-rp2-rpi_pico_w-stubs==1.24.1.*', picked)
      end)

      it('should offer every known package when no device is connected', function()
        Stubs.choose(function(choice)
          picked = choice
        end)
        finish(calls[1], 1, '', 'mpremote: no device found')

        assert.same(Stubs.PACKAGES, offered)
        assert.is_truthy(prompt:find('No device detected', 1, true))
        assert.equals(Stubs.PACKAGES[1], picked)
      end)

      it('should pass nil when the picker is cancelled', function()
        package.loaded['micropython_nvim.ui'].select = function(_, _, on_choice)
          on_choice(nil)
        end
        Config.set_port('')
        picked = 'unset'
        Stubs.choose(function(choice)
          picked = choice
        end)
        assert.is_nil(picked)
      end)
    end)

    describe('install', function()
      local original_cwd

      before_each(function()
        original_cwd = vim.fn.getcwd()
      end)

      after_each(function()
        vim.fn.chdir(original_cwd)
      end)

      it('should install the stubs into typings with uv', function()
        helpers.with_temp_dir(function(dir)
          vim.fn.chdir(dir)
          Stubs.install('micropython-rp2-stubs==1.24.1.*')

          assert.same(
            { 'uv', 'pip', 'install', '--target', 'typings', 'micropython-rp2-stubs==1.24.1.*' },
            calls[1].argv
          )
          assert.equals(vim.fn.getcwd(), calls[1].opts.cwd)
          finish(calls[1], 0)
          assert.equals(vim.log.levels.INFO, notifications[#notifications].level)
        end)
      end)

      it('should replace stubs installed earlier', function()
        helpers.with_temp_dir(function(dir)
          vim.fn.chdir(dir)
          vim.fn.mkdir(dir .. '/typings/micropython_rp2_stubs-1.24.1.dist-info', 'p')
          vim.fn.writefile({}, dir .. '/typings/rp2.pyi')

          Stubs.install('micropython-esp32-stubs')

          assert.equals(0, vim.fn.filereadable(dir .. '/typings/rp2.pyi'))
        end)
      end)

      it('should leave a typings folder that holds no stubs package alone', function()
        helpers.with_temp_dir(function(dir)
          vim.fn.chdir(dir)
          vim.fn.mkdir(dir .. '/typings', 'p')
          vim.fn.writefile({}, dir .. '/typings/mine.pyi')

          Stubs.install('micropython-esp32-stubs')

          assert.equals(1, vim.fn.filereadable(dir .. '/typings/mine.pyi'))
        end)
      end)

      it('should report the install error', function()
        Stubs.install('micropython-nope-stubs')
        finish(calls[1], 1, '', 'No solution found when resolving dependencies')
        local last = notifications[#notifications]
        assert.equals(vim.log.levels.ERROR, last.level)
        assert.is_truthy(last.msg:find('No solution found', 1, true))
      end)

      it('should explain how to install the stubs without uv', function()
        restore_fn()
        restore_fn = helpers.mock_vim_fn({
          jobstart = function(argv, opts)
            table.insert(calls, { argv = argv, opts = opts })
            return #calls
          end,
          executable = function()
            return 0
          end,
        })
        Stubs.install('micropython-rp2-stubs')
        assert.equals(0, #calls)
        assert.is_truthy(notifications[1].msg:find('pip install --target typings', 1, true))
      end)
    end)
  end)
end)
