local helpers = require('test.helpers')

describe('micropython_nvim.files', function()
  local Files
  local Config
  local calls
  local restore_fn
  local restore_notify
  local notifications
  local project
  local confirm_answer

  ---The mpremote arguments of a job, after the connect arguments
  ---@param call table
  ---@return string[]
  local function mpremote_args(call)
    local argv = call.argv
    local start = argv[1] == 'uv' and 4 or 2
    if argv[start] == 'connect' then
      start = start + 2
    end
    return vim.list_slice(argv, start)
  end

  ---Finish the most recent job (or the given one) with stdout and an exit code
  ---@param stdout? string
  ---@param code? integer
  ---@param call? table
  local function finish(stdout, code, call)
    call = call or calls[#calls]
    call.opts.on_stdout(nil, vim.split(stdout or '', '\n'))
    call.opts.on_stderr(nil, { code and code ~= 0 and 'device error' or '' })
    call.opts.on_exit(nil, code or 0)
  end

  local LISTING = table.concat({
    'F\t139\tboot.py',
    'D\t0\tlib',
    'F\t1200\tlib/led.py',
    'D\t0\tlib/sub',
    'F\t5\tlib/sub/a.py',
    'F\t2048\tlib.py',
    'S\t2097152\t1048576',
  }, '\n')

  ---Open the browser and answer its listing job
  local function open_browser(listing)
    Files.open()
    finish(listing or LISTING)
    return vim.api.nvim_get_current_buf()
  end

  ---Move the cursor in the browser to the line showing the given text
  ---@param text string
  local function cursor_to(text)
    for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if line:find(text, 1, true) then
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
        return
      end
    end
    error('no line with ' .. text)
  end

  ---Press a browser key
  ---@param lhs string
  local function press(lhs)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if map.lhs == lhs then
        map.callback()
        return
      end
    end
    error('no mapping for ' .. lhs)
  end

  before_each(function()
    helpers.reset_modules()
    Config = require('micropython_nvim.config')
    Config.setup({})
    Config.set_port('/dev/ttyUSB0')
    Files = require('micropython_nvim.files')
    Files.setup_autocmds()

    project = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(project, 'p')
    confirm_answer = 1

    calls = {}
    restore_fn = helpers.mock_vim_fn({
      getcwd = function()
        return project
      end,
      jobstart = function(argv, opts)
        table.insert(calls, { argv = argv, opts = opts })
        return #calls
      end,
      confirm = function()
        return confirm_answer
      end,
    })
    notifications, restore_notify = helpers.mock_vim_notify()
  end)

  after_each(function()
    restore_fn()
    restore_notify()
    vim.cmd('silent! %bwipeout!')
    vim.fn.delete(project, 'rf')
  end)

  describe('parse_listing', function()
    it('should parse files, directories and free space', function()
      local listing = Files.parse_listing(LISTING)
      assert.same({ path = 'boot.py', dir = false, size = 139 }, listing.entries[1])
      assert.same({ path = 'lib', dir = true, size = 0 }, listing.entries[2])
      assert.equals(2097152, listing.total)
      assert.equals(1048576, listing.free)
    end)

    it('should order children directly after their directory', function()
      local paths = vim.tbl_map(function(entry)
        return entry.path
      end, Files.parse_listing(LISTING).entries)
      assert.same({ 'boot.py', 'lib', 'lib/led.py', 'lib/sub', 'lib/sub/a.py', 'lib.py' }, paths)
    end)

    it('should keep paths with tabs and spaces whole', function()
      local listing = Files.parse_listing('F\t3\tmy file\twith tab.py')
      assert.equals('my file\twith tab.py', listing.entries[1].path)
    end)

    it('should ignore unrelated output and a missing free space line', function()
      local listing = Files.parse_listing('hello\nF\t1\ta.py\n')
      assert.equals(1, #listing.entries)
      assert.is_nil(listing.free)
    end)
  end)

  describe('listing code', function()
    it('should walk a directory tree and report free space', function()
      if vim.fn.executable('python3') ~= 1 then
        pending('python3 not available')
        return
      end
      vim.fn.mkdir(project .. '/lib/sub', 'p')
      vim.fn.writefile({ 'abc' }, project .. '/lib/sub/a.py')
      vim.fn.writefile({}, project .. '/boot.py')

      Files.open()
      local args = mpremote_args(calls[1])
      assert.equals('exec', args[1])

      -- CPython lacks os.ilistdir; emulate MicroPython's
      local shim = table.concat({
        'import os, sys',
        'os.chdir(sys.argv[1])',
        'os.ilistdir = lambda p=".": [(e.name, 0x4000 if e.is_dir() else 0x8000, 0,'
          .. ' e.stat().st_size) for e in os.scandir(p)]',
        'exec(sys.argv[2])',
      }, '\n')
      local output = vim.fn.system({ 'python3', '-c', shim, project, args[2] })
      assert.equals(0, vim.v.shell_error, output)

      local listing = Files.parse_listing(output)
      local by_path = {}
      for _, entry in ipairs(listing.entries) do
        by_path[entry.path] = entry
      end
      assert.is_true(by_path['lib'].dir)
      assert.is_true(by_path['lib/sub'].dir)
      assert.same({ path = 'lib/sub/a.py', dir = false, size = 4 }, by_path['lib/sub/a.py'])
      assert.same({ path = 'boot.py', dir = false, size = 0 }, by_path['boot.py'])
      assert.is_true(listing.total > 0)
    end)
  end)

  describe('open', function()
    it('should warn and do nothing without a port', function()
      Config.set_port('')
      Files.open()
      assert.equals(0, #calls)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)

    it('should show a loading buffer without blocking', function()
      Files.open()
      assert.equals(1, #calls)
      local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      assert.is_truthy(text:find('Loading', 1, true))
    end)

    it('should show the device tree with sizes and free space', function()
      local buf = open_browser()
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
      assert.is_truthy(text:find('1.0 MB free of 2.0 MB', 1, true))
      assert.is_truthy(text:find('boot.py%s+139 B'))
      assert.is_truthy(text:find('\nlib/\n', 1, true))
      assert.is_truthy(text:find('\n  led.py%s+1.2 KB'))
      assert.is_truthy(text:find('\n    a.py%s+5 B'))
      assert.is_false(vim.bo[buf].modifiable)
    end)

    it('should report a failed listing', function()
      Files.open()
      finish('', 1)
      local errors = vim.tbl_filter(function(n)
        return n.level == vim.log.levels.ERROR
      end, notifications)
      assert.equals(1, #errors)
      assert.is_truthy(errors[1].msg:find('device error', 1, true))
    end)

    it('should reuse the browser buffer when opened again', function()
      local first = open_browser()
      local second = open_browser()
      assert.equals(first, second)
    end)
  end)

  describe('browser actions', function()
    it('should open a file into an mp:// buffer', function()
      open_browser()
      cursor_to('led.py')
      press('<CR>')
      assert.equals('mp://lib/led.py', vim.api.nvim_buf_get_name(0))
    end)

    it('should not open a directory', function()
      local buf = open_browser()
      cursor_to('sub/')
      press('<CR>')
      assert.equals(buf, vim.api.nvim_get_current_buf())
    end)

    it('should delete a file after confirmation and refresh', function()
      open_browser()
      cursor_to('led.py')
      press('d')
      assert.same({ 'fs', 'rm', ':lib/led.py' }, mpremote_args(calls[#calls]))
      finish('')
      assert.equals('exec', mpremote_args(calls[#calls])[1])
    end)

    it('should delete a directory recursively', function()
      open_browser()
      cursor_to('sub/')
      press('d')
      assert.same({ 'fs', 'rm', '-r', ':lib/sub' }, mpremote_args(calls[#calls]))
    end)

    it('should not delete when not confirmed', function()
      open_browser()
      local count = #calls
      cursor_to('led.py')
      confirm_answer = 2
      press('d')
      assert.equals(count, #calls)
    end)

    it('should download a file into the project', function()
      open_browser()
      cursor_to('a.py')
      press('D')
      assert.same(
        { 'cp', ':lib/sub/a.py', project .. '/lib/sub/a.py' },
        mpremote_args(calls[#calls])
      )
      assert.equals(1, vim.fn.isdirectory(project .. '/lib/sub'))
    end)

    it('should ask before overwriting a local file on download', function()
      vim.fn.writefile({ 'local' }, project .. '/boot.py')
      open_browser()
      local count = #calls
      cursor_to('boot.py')
      confirm_answer = 2
      press('D')
      assert.equals(count, #calls)
    end)

    it('should create a directory inside the selected directory and refresh', function()
      open_browser()
      cursor_to('led.py')
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm('new')
      end
      press('a')
      vim.ui.input = original_input
      assert.same({ 'fs', 'mkdir', ':lib/new' }, mpremote_args(calls[#calls]))
      finish('')
      assert.equals('exec', mpremote_args(calls[#calls])[1])
    end)

    it('should create a directory at the device root from the header', function()
      open_browser()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm('')
      end
      local count = #calls
      press('a')
      vim.ui.input = function(_, on_confirm)
        on_confirm('top')
      end
      press('a')
      vim.ui.input = original_input
      assert.equals(count + 1, #calls)
      assert.same({ 'fs', 'mkdir', ':top' }, mpremote_args(calls[#calls]))
    end)

    it('should upload the previous local file into the selected directory', function()
      local local_file = project .. '/main.py'
      vim.fn.writefile({ 'print(1)' }, local_file)
      vim.cmd('edit ' .. vim.fn.fnameescape(local_file))
      open_browser()
      cursor_to('sub/')
      press('u')
      assert.same({ 'cp', local_file, ':lib/sub/main.py' }, mpremote_args(calls[#calls]))
      finish('')
      assert.equals('exec', mpremote_args(calls[#calls])[1])
    end)

    it('should warn when there is no local file to upload', function()
      open_browser()
      local count = #calls
      press('u')
      assert.equals(count, #calls)
      assert.equals(vim.log.levels.WARN, notifications[#notifications].level)
    end)

    it('should refresh the listing', function()
      open_browser()
      press('R')
      assert.equals('exec', mpremote_args(calls[#calls])[1])
    end)
  end)

  describe('mp:// buffers', function()
    ---Answer a `cp :path <tmp>` job by writing the device contents to tmp
    ---@param lines string[]
    local function answer_read(lines)
      local args = mpremote_args(calls[#calls])
      assert.equals('cp', args[1])
      vim.fn.writefile(lines, args[3])
      finish('')
    end

    it('should read the device file without blocking', function()
      vim.cmd('edit mp://lib/led.py')
      local args = mpremote_args(calls[#calls])
      assert.equals('cp', args[1])
      assert.equals(':lib/led.py', args[2])
      answer_read({ 'import machine', 'led = 1' })
      assert.same({ 'import machine', 'led = 1' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.is_false(vim.bo.modified)
      assert.equals('acwrite', vim.bo.buftype)
      assert.equals('python', vim.bo.filetype)
    end)

    it('should write the buffer back to the device', function()
      vim.cmd('edit mp://lib/led.py')
      answer_read({ 'led = 1' })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'led = 2', 'print(led)' })
      vim.cmd('write')

      local args = mpremote_args(calls[#calls])
      assert.equals('cp', args[1])
      assert.equals(':lib/led.py', args[3])
      assert.same({ 'led = 2', 'print(led)' }, vim.fn.readfile(args[2]))
      assert.is_true(vim.bo.modified)

      finish('')
      assert.is_false(vim.bo.modified)
    end)

    it('should keep the buffer modified when the write fails', function()
      vim.cmd('edit mp://lib/led.py')
      answer_read({ 'led = 1' })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'led = 2' })
      vim.cmd('write')
      finish('', 1)
      assert.is_true(vim.bo.modified)
      assert.equals(vim.log.levels.ERROR, notifications[#notifications].level)
    end)

    it('should report a failed read', function()
      vim.cmd('edit mp://missing.py')
      finish('', 1)
      assert.equals(vim.log.levels.ERROR, notifications[#notifications].level)
      assert.is_truthy(notifications[#notifications].msg:find('missing.py', 1, true))
    end)
  end)
end)
