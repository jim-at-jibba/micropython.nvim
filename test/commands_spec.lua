local helpers = require('test.helpers')

describe('micropython_nvim.commands', function()
  local Commands

  before_each(function()
    helpers.reset_modules()
    require('micropython_nvim.config').setup({})
    Commands = require('micropython_nvim.commands')
  end)

  ---Replace a facade function with a recorder
  ---@param name string
  ---@return table calls, function restore
  local function spy_facade(name)
    local facade = require('micropython_nvim')
    local original = facade[name]
    local calls = {}
    facade[name] = function(...)
      table.insert(calls, { ... })
    end
    return calls, function()
      facade[name] = original
    end
  end

  describe('subcommands', function()
    it('should make a new entry dispatchable and completable', function()
      local received
      Commands.subcommands.flash = {
        desc = 'Flash firmware',
        impl = function(args)
          received = args
        end,
      }

      Commands.dispatch({ 'flash', 'esp32' })

      assert.same({ 'esp32' }, received)
      assert.is_true(vim.tbl_contains(Commands.complete('fl', 'MP fl', 5), 'flash'))
    end)
  end)

  describe('dispatch', function()
    it('should call the matching facade function', function()
      local calls, restore = spy_facade('repl')
      Commands.dispatch({ 'repl' })
      restore()
      assert.equals(1, #calls)
    end)

    it('should pass remaining arguments to upload_all as its ignore list', function()
      local calls, restore = spy_facade('upload_all')
      Commands.dispatch({ 'upload_all', 'test.py', 'docs' })
      restore()
      assert.same({ { args = 'test.py docs' } }, calls[1])
    end)

    it('should report an unknown subcommand', function()
      local notifications, restore = helpers.mock_vim_notify()
      Commands.dispatch({ 'nope' })
      restore()
      assert.equals(1, #notifications)
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
      assert.is_truthy(notifications[1].msg:find('nope', 1, true))
    end)

    it('should offer a picker of subcommands when called without arguments', function()
      local calls, restore_facade = spy_facade('run')
      local UI = require('micropython_nvim.ui')
      local original_select = UI.select
      local offered
      UI.select = function(items, _, on_choice)
        offered = items
        on_choice('run')
      end

      Commands.dispatch({})

      UI.select = original_select
      restore_facade()
      assert.same(Commands.names(), offered)
      assert.equals(1, #calls)
    end)
  end)

  describe('complete', function()
    it('should list every subcommand for an empty argument', function()
      assert.same(Commands.names(), Commands.complete('', 'MP ', 3))
    end)

    it('should filter subcommands by prefix', function()
      assert.same({ 'erase', 'erase_all' }, Commands.complete('era', 'MP era', 6))
    end)

    it('should include every existing feature', function()
      local names = Commands.names()
      for _, name in ipairs({
        'run',
        'run_main',
        'upload',
        'upload_all',
        'repl',
        'send',
        'send_buffer',
        'interrupt',
        'info',
        'mip',
        'flash',
        'sync',
        'reset',
        'hard_reset',
        'list_files',
        'files',
        'erase',
        'erase_all',
        'init',
        'install',
        'set_port',
        'set_stubs',
        'list_devices',
        'health',
      }) do
        assert.is_true(vim.tbl_contains(names, name), name)
      end
    end)

    it('should not offer a baud rate setting', function()
      assert.is_nil(Commands.subcommands.set_baud)
    end)

    it('should not complete subcommand names after the subcommand', function()
      assert.same({}, Commands.complete('', 'MP repl ', 8))
    end)

    it("should delegate argument completion to the subcommand's completer", function()
      Commands.subcommands.flash = {
        desc = 'Flash firmware',
        impl = function() end,
        complete = function(arglead)
          return vim.tbl_filter(function(board)
            return vim.startswith(board, arglead)
          end, { 'esp32', 'rp2' })
        end,
      }
      assert.same({ 'esp32' }, Commands.complete('e', 'MP flash e', 10))
    end)
  end)

  describe('user commands', function()
    before_each(function()
      vim.cmd('runtime plugin/micropython_nvim.lua')
    end)

    it('should define :MP with completion', function()
      local command = vim.api.nvim_get_commands({})['MP']
      assert.is_not_nil(command)
      assert.equals('*', command.nargs)
      assert.same(Commands.names(), vim.fn.getcompletion('MP ', 'cmdline'))
    end)

    it('should register :MP as the only command', function()
      local names = vim.tbl_filter(function(name)
        return vim.startswith(name, 'MP')
      end, vim.tbl_keys(vim.api.nvim_get_commands({})))
      assert.same({ 'MP' }, names)
    end)

    it('should route :MP <subcommand> through dispatch', function()
      local calls, restore = spy_facade('soft_reset')
      vim.cmd('MP reset')
      restore()
      assert.equals(1, #calls)
    end)

    it('should route :MP upload_all arguments through dispatch', function()
      local calls, restore = spy_facade('upload_all')
      vim.cmd('MP upload_all test.py')
      restore()
      assert.same({ { args = 'test.py' } }, calls[1])
    end)
  end)
end)
