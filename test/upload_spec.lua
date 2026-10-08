local helpers = require('test.helpers')

describe('micropython_nvim.upload', function()
  local Upload
  local Config
  local calls
  local restore_fn
  local restore_notify
  local notifications
  local project

  ---Create files (and their parent directories) under the project
  ---@param paths string[]
  local function make_files(paths)
    for _, path in ipairs(paths) do
      vim.fn.mkdir(vim.fs.dirname(project .. '/' .. path), 'p')
      vim.fn.writefile({ 'x = 1' }, project .. '/' .. path)
    end
  end

  ---The mpremote arguments of a job, after the connect arguments
  ---@param call table
  ---@return string[]
  local function mpremote_args(call)
    local argv = call.argv
    local start = 2
    if argv[1] == 'uv' then
      start = 4
    end
    if argv[start] == 'connect' then
      start = start + 2
    end
    return vim.list_slice(argv, start)
  end

  ---Split a '+'-chained argv into its commands
  ---@param args string[]
  ---@return string[][]
  local function commands(args)
    local result = { {} }
    for _, arg in ipairs(args) do
      if arg == '+' then
        table.insert(result, {})
      else
        table.insert(result[#result], arg)
      end
    end
    return result
  end

  ---Device paths copied by a chained command
  ---@param args string[]
  ---@return table<string, string> device path -> local path
  local function copies(args)
    local result = {}
    for _, command in ipairs(commands(args)) do
      if command[1] == 'cp' then
        result[command[3]:sub(2)] = command[2]
      end
    end
    return result
  end

  ---The python run by the chained `exec` command, if any
  ---@param args string[]
  ---@return string?
  local function exec_code(args)
    for _, command in ipairs(commands(args)) do
      if command[1] == 'exec' then
        return command[2]
      end
    end
  end

  ---Run python code with the given directory as the current directory
  ---@param code string
  ---@param dir string
  local function run_python(code, dir)
    local output = vim.fn.system({
      'python3',
      '-c',
      'import os, sys; os.chdir(sys.argv[1]); exec(sys.argv[2])',
      dir,
      code,
    })
    assert.equals(0, vim.v.shell_error, output)
  end

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Config.set_port('/dev/ttyUSB0')
    Upload = require('micropython_nvim.upload')

    project = vim.fn.tempname()
    vim.fn.mkdir(project, 'p')
    project = vim.fn.resolve(project)

    calls = {}
    restore_fn = helpers.mock_vim_fn({
      getcwd = function()
        return project
      end,
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
    vim.fn.delete(project, 'rf')
  end)

  describe('DEFAULT_IGNORE_LIST', function()
    it('should be a table', function()
      assert.is_table(Upload.DEFAULT_IGNORE_LIST)
    end)

    it('should contain .git', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.git'])
    end)

    it('should contain .micropython', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.micropython'])
    end)

    it('should not upload a leftover v2 .ampy file', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.ampy'])
    end)

    it('should contain __pycache__', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['__pycache__'])
    end)

    it('should contain pyproject.toml', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['pyproject.toml'])
    end)

    it('should contain uv.lock', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['uv.lock'])
    end)

    it('should contain .venv', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.venv'])
    end)

    it('should contain venv', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['venv'])
    end)

    it('should contain env', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['env'])
    end)

    it('should contain requirements.txt', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['requirements.txt'])
    end)

    it('should contain .vscode', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.vscode'])
    end)

    it('should contain .gitignore', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.gitignore'])
    end)

    it('should contain project.pymakr', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['project.pymakr'])
    end)

    it('should contain .python-version', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.python-version'])
    end)

    it('should contain .micropy/', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.micropy/'])
    end)

    it('should contain micropy.json', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['micropy.json'])
    end)

    it('should contain .idea', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['.idea'])
    end)

    it('should contain README.md', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['README.md'])
    end)

    it('should contain LICENSE', function()
      assert.is_true(Upload.DEFAULT_IGNORE_LIST['LICENSE'])
    end)

    it('should not contain main.py', function()
      assert.is_nil(Upload.DEFAULT_IGNORE_LIST['main.py'])
    end)

    it('should not contain lib/', function()
      assert.is_nil(Upload.DEFAULT_IGNORE_LIST['lib/'])
    end)
  end)

  describe('upload_all', function()
    -- The project layout reported in #11
    local ISSUE_11 = {
      'main.py',
      'microdot/__init__.py',
      'microdot/microdot.py',
      'web/server.py',
      'web/resources/example.py',
      'web/resources/templates/info.html',
    }

    it('should warn when port not configured', function()
      Config.set_port('')
      Upload.upload_all()
      assert.equals(0, #calls)
      assert.is_truthy(notifications[1].msg:find('No port configured', 1, true))
    end)

    it('should copy every file of the #11 layout to its relative path', function()
      make_files(ISSUE_11)

      Upload.upload_all()

      assert.equals(1, #calls)
      local copied = copies(mpremote_args(calls[1]))
      for _, path in ipairs(ISSUE_11) do
        assert.equals(project .. '/' .. path, copied[path], path)
      end
      assert.equals(#ISSUE_11, vim.tbl_count(copied))
    end)

    it('should not use fs mkdir, which fails on existing directories', function()
      make_files(ISSUE_11)
      Upload.upload_all()
      for _, command in ipairs(commands(mpremote_args(calls[1]))) do
        assert.is_false(command[1] == 'fs' and command[2] == 'mkdir', table.concat(command, ' '))
      end
    end)

    it('should create nested directories before copying into them', function()
      make_files(ISSUE_11)
      Upload.upload_all()
      local chain = commands(mpremote_args(calls[1]))
      assert.equals('exec', chain[1][1])
    end)

    it('should create the #11 directories on a fresh device and again on re-upload', function()
      if vim.fn.executable('python3') ~= 1 then
        pending('python3 not available')
        return
      end
      make_files(ISSUE_11)
      Upload.upload_all()
      local code = exec_code(mpremote_args(calls[1]))
      assert.is_not_nil(code)

      local device = vim.fn.tempname()
      vim.fn.mkdir(device, 'p')
      run_python(code, device)
      run_python(code, device)

      for _, dir in ipairs({ 'microdot', 'web', 'web/resources', 'web/resources/templates' }) do
        assert.equals(1, vim.fn.isdirectory(device .. '/' .. dir), dir)
      end
      vim.fn.delete(device, 'rf')
    end)

    it('should not force copies, so mpremote skips files whose hash is unchanged', function()
      make_files(ISSUE_11)
      Upload.upload_all()
      for _, command in ipairs(commands(mpremote_args(calls[1]))) do
        if command[1] == 'cp' then
          assert.is_false(vim.tbl_contains(command, '-f'))
          assert.is_false(vim.tbl_contains(command, '--force'))
        end
      end
    end)

    it('should skip default ignored names at any depth', function()
      make_files({ 'main.py', '.micropython', 'lib/__pycache__/a.mpy', '.venv/lib/x.py' })
      Upload.upload_all()
      assert.same({ 'main.py' }, vim.tbl_keys(copies(mpremote_args(calls[1]))))
    end)

    it('should skip names and paths given as arguments', function()
      make_files({ 'main.py', 'test.py', 'docs/a.md', 'web/resources/big.bin', 'web/server.py' })
      Upload.upload_all({ args = 'test.py docs/ web/resources' })
      assert.same(
        { 'main.py', 'web/server.py' },
        vim.fn.sort(vim.tbl_keys(copies(mpremote_args(calls[1]))))
      )
    end)

    it('should not run exec when every file is at the top level', function()
      make_files({ 'main.py', 'boot.py' })
      Upload.upload_all()
      assert.is_nil(exec_code(mpremote_args(calls[1])))
    end)

    it('should warn when there is nothing to upload', function()
      make_files({ 'README.md' })
      Upload.upload_all()
      assert.equals(0, #calls)
      assert.is_truthy(notifications[1].msg:find('No files to upload', 1, true))
    end)
  end)

  describe('upload_current', function()
    it('should warn when port not configured', function()
      Config.set_port('')
      Upload.upload_current()
      assert.equals(0, #calls)
      assert.is_truthy(notifications[1].msg:find('No port configured', 1, true))
    end)

    it('should keep the project-relative path and create its directories', function()
      make_files({ 'lib/drivers/led.py' })
      vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/lib/drivers/led.py'))

      Upload.upload_current()

      local args = mpremote_args(calls[1])
      assert.same({ ['lib/drivers/led.py'] = project .. '/lib/drivers/led.py' }, copies(args))
      local code = exec_code(args)
      assert.is_truthy(code:find("'lib'", 1, true))
      assert.is_truthy(code:find("'lib/drivers'", 1, true))
      vim.cmd('bwipeout!')
    end)

    it('should warn and not upload a buffer without a file', function()
      vim.cmd('enew')
      Upload.upload_current()
      assert.equals(0, #calls)
      assert.is_truthy(notifications[1].msg:find('no file', 1, true))
      vim.cmd('bwipeout!')
    end)

    it('should copy a top-level file without exec', function()
      make_files({ 'main.py' })
      vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/main.py'))

      Upload.upload_current()

      assert.same(
        { { 'cp', project .. '/main.py', ':main.py' } },
        commands(mpremote_args(calls[1]))
      )
      vim.cmd('bwipeout!')
    end)

    it('should copy a file outside the project to the device root', function()
      local outside = vim.fn.tempname() .. '.py'
      vim.fn.writefile({ '' }, outside)
      vim.cmd('edit ' .. vim.fn.fnameescape(outside))
      local path = vim.api.nvim_buf_get_name(0)

      Upload.upload_current()

      assert.same(
        { { 'cp', path, ':' .. vim.fs.basename(path) } },
        commands(mpremote_args(calls[1]))
      )
      vim.cmd('bwipeout!')
      vim.fn.delete(outside)
    end)
  end)

  describe('upload on save', function()
    ---@param path string project-relative
    local function save(path)
      vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/' .. path))
      vim.cmd('silent write')
      vim.cmd('bwipeout!')
    end

    after_each(function()
      pcall(vim.api.nvim_del_augroup_by_name, 'micropython_nvim_upload_on_save')
    end)

    it('should be off by default', function()
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'main.py' })
      save('main.py')
      assert.equals(0, #calls)
    end)

    it('should upload a saved project file to its relative path when enabled', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'lib/led.py' })

      save('lib/led.py')

      assert.equals(1, #calls)
      assert.same({ ['lib/led.py'] = project .. '/lib/led.py' }, copies(mpremote_args(calls[1])))
    end)

    it('should respect the ignore list', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'README.md', 'tests/__pycache__/x.py' })

      save('README.md')
      save('tests/__pycache__/x.py')

      assert.equals(0, #calls)
    end)

    it('should only upload in a MicroPython project', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ 'main.py' })

      save('main.py')

      assert.equals(0, #calls)
    end)

    it('should ignore files outside the project', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython' })
      local outside = vim.fn.tempname() .. '.py'
      vim.fn.writefile({ '' }, outside)

      vim.cmd('edit ' .. vim.fn.fnameescape(outside))
      vim.cmd('silent write')
      vim.cmd('bwipeout!')

      assert.equals(0, #calls)
      vim.fn.delete(outside)
    end)

    it('should queue saves while an upload runs and send them together afterwards', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'main.py', 'lib/a.py', 'lib/b.py' })

      save('main.py')
      save('lib/a.py')
      save('lib/b.py')
      save('lib/a.py')
      assert.equals(1, #calls)

      calls[1].opts.on_exit(1, 0)

      assert.equals(2, #calls)
      assert.same({
        ['lib/a.py'] = project .. '/lib/a.py',
        ['lib/b.py'] = project .. '/lib/b.py',
      }, copies(mpremote_args(calls[2])))

      calls[2].opts.on_exit(2, 0)
      save('main.py')
      assert.equals(3, #calls)
    end)

    it('should keep uploading queued saves after a failed upload', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'main.py', 'boot.py' })

      save('main.py')
      save('boot.py')
      calls[1].opts.on_exit(1, 1)

      assert.equals(2, #calls)
      assert.same({ ['boot.py'] = project .. '/boot.py' }, copies(mpremote_args(calls[2])))
    end)

    it('should stop uploading when set up again with it disabled', function()
      Config.setup({ upload_on_save = true, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      Config.setup({ upload_on_save = false, port = '/dev/ttyUSB0' })
      Upload.setup_upload_on_save()
      make_files({ '.micropython', 'main.py' })

      save('main.py')

      assert.equals(0, #calls)
    end)
  end)
end)
