local helpers = require('test.helpers')

describe('micropython_nvim.mpremote', function()
  local Mpremote
  local Config

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Mpremote = require('micropython_nvim.mpremote')
  end)

  ---Replace vim.fn.jobstart with a fake that records the call
  ---@param job_id? integer
  ---@return table call, function restore
  local function fake_jobstart(job_id)
    local call = {}
    local restore = helpers.mock_vim_fn({
      jobstart = function(argv, opts)
        call.argv = argv
        call.opts = opts
        return job_id or 1
      end,
    })
    return call, restore
  end

  describe('argv', function()
    it('should start with mpremote outside a uv project', function()
      local restore = helpers.mock_vim_fn({
        executable = function()
          return 0
        end,
      })
      local argv = Mpremote.argv({ 'ls' })
      restore()
      assert.same({ 'mpremote', 'ls' }, argv)
    end)

    it('should use uv run inside a uv project', function()
      local restore = helpers.mock_vim_fn({
        executable = function()
          return 1
        end,
        filereadable = function()
          return 1
        end,
      })
      local argv = Mpremote.argv({ 'ls' })
      restore()
      assert.same({ 'uv', 'run', 'mpremote', 'ls' }, argv)
    end)

    it('should add the configured port', function()
      Config.set_port('/dev/ttyUSB0')
      local argv = Mpremote.argv({ 'ls' })
      assert.same({ 'connect', '/dev/ttyUSB0', 'ls' }, vim.list_slice(argv, #argv - 2))
    end)

    it('should not add a connect argument for auto', function()
      Config.set_port('auto')
      assert.is_false(vim.tbl_contains(Mpremote.argv({ 'ls' }), 'connect'))
    end)

    it('should skip the port when connect is false', function()
      Config.set_port('/dev/ttyUSB0')
      local argv = Mpremote.argv({ 'connect', 'list' }, { connect = false })
      assert.same({ 'connect', 'list' }, vim.list_slice(argv, #argv - 1))
      assert.is_false(vim.tbl_contains(argv, '/dev/ttyUSB0'))
    end)

    it('should keep paths with spaces, quotes and $ as single arguments', function()
      local path = [[/tmp/my "odd" $HOME 'file'.py]]
      local argv = Mpremote.argv({ 'cp', path, ':main.py' })
      assert.equals(path, argv[#argv - 1])
    end)
  end)

  describe('error_output', function()
    it('should prefer stderr, then stdout', function()
      assert.equals('e', Mpremote.error_output({ code = 1, stdout = 'o', stderr = 'e' }))
      assert.equals('o', Mpremote.error_output({ code = 1, stdout = 'o', stderr = '' }))
    end)
  end)

  describe('command', function()
    it('should shell-escape every argument', function()
      Config.set_port('/dev/ttyUSB0')
      local argv = Mpremote.argv({ 'run', 'a b.py' })
      local expected = table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
      assert.equals(expected, Mpremote.command({ 'run', 'a b.py' }))
    end)

    it('should survive a round trip through the shell', function()
      if vim.fn.has('win32') == 1 then
        return
      end
      local path = [[/tmp/my "odd" $HOME 'file' `x`.py]]
      local cmd = Mpremote.command({ path }, { connect = false })
      local output = vim.fn.system({ 'sh', '-c', "printf '%s\\n' " .. cmd })
      local lines = vim.split(output, '\n', { trimempty = true })
      assert.equals(path, lines[#lines])
    end)
  end)

  describe('run', function()
    it('should start the job with an argv list, not a shell string', function()
      local call, restore = fake_jobstart()
      Mpremote.run({ 'cp', 'a b.py', ':a b.py' })
      restore()
      assert.is_table(call.argv)
      assert.same({ 'cp', 'a b.py', ':a b.py' }, vim.list_slice(call.argv, #call.argv - 2))
    end)

    it('should pass stdout, stderr and exit code to on_exit', function()
      local call, restore = fake_jobstart()
      local result
      Mpremote.run({ 'fs', 'ls', ':' }, {
        on_exit = function(r)
          result = r
        end,
      })
      restore()

      call.opts.on_stdout(1, { 'ls :', '         139 main.py', '' })
      call.opts.on_stderr(1, { '' })
      call.opts.on_exit(1, 0)

      assert.same({ code = 0, stdout = 'ls :\n         139 main.py', stderr = '' }, result)
    end)

    it('should notify start and success when named', function()
      local call, restore = fake_jobstart()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'soft_reset' }, { name = 'Soft reset' })
      call.opts.on_stdout(1, { '' })
      call.opts.on_stderr(1, { '' })
      call.opts.on_exit(1, 0)
      restore()
      restore_notify()

      assert.equals('Soft reset started', notifications[1].msg)
      assert.equals('Soft reset completed successfully', notifications[2].msg)
      assert.equals(vim.log.levels.INFO, notifications[2].level)
    end)

    it('should show mpremote stderr when the command fails', function()
      local call, restore = fake_jobstart()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'fs', 'mkdir', ':lib' }, { name = 'Upload all' })
      call.opts.on_stdout(1, { '' })
      call.opts.on_stderr(1, { 'mpremote: mkdir: lib: File exists', '' })
      call.opts.on_exit(1, 1)
      restore()
      restore_notify()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.equals('Upload all failed:\nmpremote: mkdir: lib: File exists', last.msg)
    end)

    it('should fall back to stdout when stderr is empty', function()
      local call, restore = fake_jobstart()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'exec', 'x' }, { name = 'Exec' })
      call.opts.on_stdout(1, { 'Traceback (most recent call last):', 'NameError: x', '' })
      call.opts.on_stderr(1, { '' })
      call.opts.on_exit(1, 1)
      restore()
      restore_notify()

      local last = notifications[#notifications]
      assert.equals('Exec failed:\nTraceback (most recent call last):\nNameError: x', last.msg)
    end)

    it('should mention the exit code when there is no output', function()
      local call, restore = fake_jobstart()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'reset' }, { name = 'Hard reset' })
      call.opts.on_stdout(1, { '' })
      call.opts.on_stderr(1, { '' })
      call.opts.on_exit(1, 3)
      restore()
      restore_notify()

      assert.equals('Hard reset failed (exit code 3)', notifications[#notifications].msg)
    end)

    it('should not notify when unnamed', function()
      local call, restore = fake_jobstart()
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'connect', 'list' }, { connect = false })
      call.opts.on_stdout(1, { '' })
      call.opts.on_stderr(1, { 'boom', '' })
      call.opts.on_exit(1, 1)
      restore()
      restore_notify()

      assert.equals(0, #notifications)
    end)

    it('should report a missing mpremote and still call on_exit', function()
      local _, restore = fake_jobstart(-1)
      local notifications, restore_notify = helpers.mock_vim_notify()
      local result
      local job_id = Mpremote.run({ 'reset' }, {
        name = 'Hard reset',
        on_exit = function(r)
          result = r
        end,
      })
      restore()
      restore_notify()

      assert.is_nil(job_id)
      assert.equals(-1, result.code)
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
      assert.is_truthy(notifications[1].msg:find('mpremote not found', 1, true))
    end)

    it('should suggest uv sync when uv cannot be started', function()
      local restore = helpers.mock_vim_fn({
        jobstart = function()
          return -1
        end,
        executable = function()
          return 1
        end,
        filereadable = function()
          return 1
        end,
      })
      local notifications, restore_notify = helpers.mock_vim_notify()
      Mpremote.run({ 'reset' }, { name = 'Hard reset' })
      restore()
      restore_notify()

      assert.is_truthy(notifications[1].msg:find('uv sync', 1, true))
    end)
  end)
end)
