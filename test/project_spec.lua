local helpers = require('test.helpers')

describe('micropython_nvim.project', function()
  local Project

  before_each(function()
    helpers.reset_modules()
    require('micropython_nvim.config').setup({})
    Project = require('micropython_nvim.project')
  end)

  describe('BOARDS', function()
    it('should be a table', function()
      assert.is_table(Project.BOARDS)
    end)

    it('should have multiple boards', function()
      assert.is_true(#Project.BOARDS > 0)
    end)

    it('should have id for each board', function()
      for _, board in ipairs(Project.BOARDS) do
        assert.is_string(board.id)
        assert.is_true(#board.id > 0)
      end
    end)

    it('should have name for each board', function()
      for _, board in ipairs(Project.BOARDS) do
        assert.is_string(board.name)
        assert.is_true(#board.name > 0)
      end
    end)

    it('should have stub for each board', function()
      for _, board in ipairs(Project.BOARDS) do
        assert.is_string(board.stub)
        assert.is_true(board.stub:match('micropython%-.*%-stubs') ~= nil)
      end
    end)

    it('should have rp2 board', function()
      local found = false
      for _, board in ipairs(Project.BOARDS) do
        if board.id == 'rp2' then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it('should have esp32 board', function()
      local found = false
      for _, board in ipairs(Project.BOARDS) do
        if board.id == 'esp32' then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it('should have esp8266 board', function()
      local found = false
      for _, board in ipairs(Project.BOARDS) do
        if board.id == 'esp8266' then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe('DEFAULT_BOARD', function()
    it('should be rp2', function()
      assert.equals('rp2', Project.DEFAULT_BOARD)
    end)

    it('should exist in BOARDS', function()
      local found = false
      for _, board in ipairs(Project.BOARDS) do
        if board.id == Project.DEFAULT_BOARD then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe('TEMPLATES', function()
    it('should be a table', function()
      assert.is_table(Project.TEMPLATES)
    end)

    describe('micropython_config', function()
      it('should exist', function()
        assert.is_string(Project.TEMPLATES.micropython_config)
      end)

      it('should contain PORT', function()
        assert.is_true(Project.TEMPLATES.micropython_config:find('PORT') ~= nil)
      end)

      it('should contain BAUD', function()
        assert.is_true(Project.TEMPLATES.micropython_config:find('BAUD') ~= nil)
      end)

      it('should have auto as default port', function()
        assert.is_true(Project.TEMPLATES.micropython_config:find('PORT=auto') ~= nil)
      end)
    end)

    describe('main', function()
      it('should exist', function()
        assert.is_string(Project.TEMPLATES.main)
      end)

      it('should import from machine', function()
        assert.is_true(Project.TEMPLATES.main:find('from machine import') ~= nil)
      end)

      it('should have LED example', function()
        assert.is_true(Project.TEMPLATES.main:find('LED') ~= nil)
      end)

      it('should have while loop', function()
        assert.is_true(Project.TEMPLATES.main:find('while True') ~= nil)
      end)
    end)

    describe('gitignore', function()
      it('should exist', function()
        assert.is_string(Project.TEMPLATES.gitignore)
      end)

      it('should contain .venv/', function()
        assert.is_true(Project.TEMPLATES.gitignore:find('.venv/') ~= nil)
      end)

      it('should contain __pycache__/', function()
        assert.is_true(Project.TEMPLATES.gitignore:find('__pycache__/') ~= nil)
      end)
    end)

    describe('pyright_config', function()
      it('should exist', function()
        assert.is_string(Project.TEMPLATES.pyright_config)
      end)

      it('should be valid JSON structure', function()
        assert.is_true(Project.TEMPLATES.pyright_config:find('{') ~= nil)
        assert.is_true(Project.TEMPLATES.pyright_config:find('}') ~= nil)
      end)

      it('should disable reportMissingModuleSource', function()
        assert.is_true(Project.TEMPLATES.pyright_config:find('reportMissingModuleSource') ~= nil)
        assert.is_true(Project.TEMPLATES.pyright_config:find('false') ~= nil)
      end)
    end)
  end)
end)
