local helpers = require('test.helpers')

describe('micropython_nvim.health', function()
  local Health
  local Config
  local reports
  local restore_health
  local restore_snacks

  local DEVICE_LIST = '/dev/cu.usbmodem101 e6614c311b7e6f35 2e8a:0005 MicroPython Board in FS mode'

  ---Record vim.health calls instead of rendering them
  local function record_health()
    local original = {}
    reports = {}
    for _, kind in ipairs({ 'start', 'ok', 'warn', 'error', 'info' }) do
      original[kind] = vim.health[kind]
      vim.health[kind] = function(msg, advice)
        table.insert(reports, { kind = kind, msg = msg, advice = advice })
      end
    end
    return function()
      for kind, fn in pairs(original) do
        vim.health[kind] = fn
      end
    end
  end

  ---@param tools table<string, boolean> executables that exist
  ---@param opts? { files?: table<string, boolean>, devices?: string, mpremote_code?: integer }
  local function fake_system(tools, opts)
    opts = opts or {}
    local files = opts.files or {}
    return helpers.mock_vim_fn({
      executable = function(name)
        return tools[name] and 1 or 0
      end,
      filereadable = function(path)
        for suffix, exists in pairs(files) do
          if vim.endswith(path, suffix) and exists then
            return 1
          end
        end
        return 0
      end,
      system = function(argv)
        return argv[1] .. ' 9.9.9\n'
      end,
      jobstart = function(argv, job_opts)
        local is_list = vim.tbl_contains(argv, 'list')
        local code = opts.mpremote_code or 0
        local stdout = is_list and { opts.devices or '' } or { 'mpremote 1.24.1' }
        job_opts.on_stdout(1, stdout)
        job_opts.on_stderr(1, code == 0 and { '' } or { 'could not connect' })
        job_opts.on_exit(1, code)
        return 1
      end,
    })
  end

  ---@param kind string
  ---@param pattern string
  ---@return table|nil
  local function find_report(kind, pattern)
    for _, report in ipairs(reports) do
      if report.kind == kind and report.msg:find(pattern) then
        return report
      end
    end
    return nil
  end

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Health = require('micropython_nvim.health')
    restore_health = record_health()
    restore_snacks = helpers.hide_snacks()
  end)

  after_each(function()
    restore_health()
    restore_snacks()
  end)

  it('should report OK when mpremote, uv, mpflash and a device are available', function()
    local restore = fake_system(
      { mpremote = true, uv = true, mpflash = true },
      { files = { ['.micropython'] = true }, devices = DEVICE_LIST }
    )
    Health.check()
    restore()

    assert.is_not_nil(find_report('ok', 'mpremote 1%.24%.1'))
    assert.is_not_nil(find_report('ok', 'uv'))
    assert.is_not_nil(find_report('ok', 'mpflash'))
    assert.is_not_nil(find_report('ok', '%.micropython'))
    assert.is_not_nil(find_report('ok', 'usbmodem101'))
    assert.is_nil(find_report('error', '.'))
  end)

  it('should error with an install hint when mpremote is missing', function()
    local restore = fake_system({})
    Health.check()
    restore()

    local report = find_report('error', 'mpremote')
    assert.is_not_nil(report)
    assert.is_truthy(table.concat(report.advice, ' '):find('pip install mpremote', 1, true))
  end)

  it('should suggest uv sync when mpremote fails inside a uv project', function()
    local restore = fake_system(
      { uv = true },
      { files = { ['pyproject.toml'] = true }, mpremote_code = 1 }
    )
    Health.check()
    restore()

    local report = find_report('error', 'mpremote')
    assert.is_not_nil(report)
    assert.is_truthy(table.concat(report.advice, ' '):find('uv sync', 1, true))
  end)

  it('should warn with an install link when uv is missing', function()
    local restore = fake_system({ mpremote = true })
    Health.check()
    restore()

    local report = find_report('warn', 'uv')
    assert.is_not_nil(report)
    assert.is_truthy(table.concat(report.advice, ' '):find('astral', 1, true))
  end)

  it('should note the built-in terminal fallback when snacks.nvim is absent', function()
    local restore = fake_system({ mpremote = true })
    Health.check()
    restore()

    assert.is_not_nil(find_report('info', 'snacks'))
  end)

  it('should report snacks.nvim when it is installed', function()
    restore_snacks()
    restore_snacks = helpers.stub_snacks()
    local restore = fake_system({ mpremote = true })
    Health.check()
    restore()

    assert.is_not_nil(find_report('ok', 'snacks'))
  end)

  it('should mention mpflash as optional when it is missing', function()
    local restore = fake_system({ mpremote = true })
    Health.check()
    restore()

    local report = find_report('info', 'mpflash')
    assert.is_not_nil(report)
    assert.is_truthy(report.msg:find('install mpflash', 1, true))
  end)

  it('should suggest :MP init when there is no project config', function()
    local restore = fake_system({ mpremote = true })
    Health.check()
    restore()

    local report = find_report('info', 'config')
    assert.is_not_nil(report)
    assert.is_truthy(report.msg:find(':MP init', 1, true))
  end)

  it('should not treat a v2 .ampy file as project config', function()
    local restore = fake_system({ mpremote = true }, { files = { ['.ampy'] = true } })
    Health.check()
    restore()

    assert.is_nil(find_report('warn', '%.ampy'))
    assert.is_not_nil(find_report('info', 'No project config'))
  end)

  it('should warn when no device is connected', function()
    local restore = fake_system({ mpremote = true }, { devices = '' })
    Health.check()
    restore()

    assert.is_not_nil(find_report('warn', 'No MicroPython device'))
  end)

  it('should warn when the configured port is not connected', function()
    Config.set_port('/dev/ttyUSB9')
    local restore = fake_system({ mpremote = true }, { devices = DEVICE_LIST })
    Health.check()
    restore()

    local report = find_report('warn', '/dev/ttyUSB9')
    assert.is_not_nil(report)
    assert.is_truthy(table.concat(report.advice, ' '):find(':MP set_port', 1, true))
  end)

  it('should accept a configured id:<serial> port that is connected', function()
    Config.set_port('id:e6614c311b7e6f35')
    local restore = fake_system({ mpremote = true }, { devices = DEVICE_LIST })
    Health.check()
    restore()

    assert.is_not_nil(find_report('ok', 'id:e6614c311b7e6f35'))
  end)

  it('should skip the device check when mpremote is missing', function()
    local restore = fake_system({})
    Health.check()
    restore()

    assert.is_nil(find_report('ok', 'usbmodem'))
    assert.is_nil(find_report('warn', 'No MicroPython device'))
  end)
end)
