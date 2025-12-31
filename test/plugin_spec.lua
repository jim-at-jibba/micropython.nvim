describe('micropython_nvim', function()
  local Config = require('micropython_nvim.config')
  local Utils = require('micropython_nvim.utils')

  before_each(function()
    Config.setup({})
  end)

  describe('config', function()
    it('should have default port as auto', function()
      assert.equals('auto', Config.get_port())
    end)

    it('should have default baud rate as 115200', function()
      assert.equals('115200', Config.get_baud())
    end)

    it('should set port correctly', function()
      Config.set_port('/dev/ttyUSB0')
      assert.equals('/dev/ttyUSB0', Config.get_port())
    end)

    it('should set baud rate correctly', function()
      Config.set_baud('9600')
      assert.equals('9600', Config.get_baud())
    end)

    it('should return empty connect arg for auto port', function()
      Config.set_port('auto')
      assert.equals('', Config.get_connect_arg())
    end)

    it('should return connect arg for specific port', function()
      Config.set_port('/dev/ttyUSB0')
      assert.equals('connect /dev/ttyUSB0', Config.get_connect_arg())
    end)

    it('should report port as configured when set', function()
      Config.set_port('/dev/ttyACM0')
      assert.is_true(Config.is_port_configured())
    end)

    it('should report port as configured for auto', function()
      Config.set_port('auto')
      assert.is_true(Config.is_port_configured())
    end)
  end)

  describe('utils', function()
    it('should return correct config path', function()
      local path = Utils.get_config_path()
      assert.is_true(path:match('%.micropython$') ~= nil)
    end)

    it('should return correct ampy path for backwards compatibility', function()
      local path = Utils.get_ampy_path()
      assert.is_true(path:match('%.ampy$') ~= nil)
    end)
  end)

  describe('run', function()
    local Run = require('micropython_nvim.run')

    it('should have default ignore list', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.git'])
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.micropython'])
      assert.is_true(Run.DEFAULT_IGNORE_LIST['__pycache__'])
      assert.is_true(Run.DEFAULT_IGNORE_LIST['pyproject.toml'])
      assert.is_true(Run.DEFAULT_IGNORE_LIST['uv.lock'])
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.venv'])
    end)

    it('should include .ampy in ignore list for backwards compat', function()
      assert.is_true(Run.DEFAULT_IGNORE_LIST['.ampy'])
    end)
  end)

  describe('setup', function()
    local Setup = require('micropython_nvim.setup')

    it('should have baud rate options', function()
      assert.is_true(#Setup.BAUD_RATES > 0)
      assert.is_true(vim.tbl_contains(Setup.BAUD_RATES, '115200'))
    end)

    it('should have stub options', function()
      assert.is_true(#Setup.STUB_OPTIONS > 0)
    end)
  end)

  describe('project', function()
    local Project = require('micropython_nvim.project')

    it('should have templates', function()
      assert.is_not_nil(Project.TEMPLATES.micropython_config)
      assert.is_not_nil(Project.TEMPLATES.main)
      assert.is_not_nil(Project.TEMPLATES.gitignore)
      assert.is_not_nil(Project.TEMPLATES.pyright_config)
    end)

    it('should have board options', function()
      assert.is_true(#Project.BOARDS > 0)
    end)

    it('should have rp2 as default board', function()
      assert.equals('rp2', Project.DEFAULT_BOARD)
    end)

    it('should have correct stub packages for boards', function()
      for _, board in ipairs(Project.BOARDS) do
        assert.is_not_nil(board.stub)
        assert.is_true(board.stub:match('micropython%-.*%-stubs') ~= nil)
      end
    end)
  end)
end)
