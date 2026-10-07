local helpers = require('test.helpers')
local fixtures = require('test.fixtures')

describe('micropython_nvim.project', function()
  local Project

  before_each(function()
    helpers.reset_modules()
    require('micropython_nvim.config').setup({})
    Project = require('micropython_nvim.project')
  end)

  describe('init', function()
    local original_cwd
    local installed
    local answers
    local jobs
    local restore_fn
    local restore_notify

    ---Pick `choice` whenever stubs are chosen
    ---@param choice string?
    local function choose(choice)
      local Stubs = require('micropython_nvim.stubs')
      Stubs.choose = function(on_choice)
        on_choice(choice)
      end
      Stubs.install = function(requirement)
        installed = requirement
      end
    end

    ---@param dir string
    ---@param name string
    ---@return string
    local function read(dir, name)
      return table.concat(vim.fn.readfile(dir .. '/' .. name), '\n')
    end

    before_each(function()
      original_cwd = vim.fn.getcwd()
      installed = nil
      answers = {}
      jobs = {}
      package.loaded['micropython_nvim.ui'] = {
        select = function(_, opts, on_choice)
          on_choice(answers[opts.prompt:match('^%S+')])
        end,
      }
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(cmd, opts)
          table.insert(jobs, { cmd = cmd, opts = opts })
          return #jobs
        end,
        executable = function(name)
          return name == 'uv' and 1 or 0
        end,
      })
      local _
      _, restore_notify = helpers.mock_vim_notify()
      package.loaded['micropython_nvim.project'] = nil
      Project = require('micropython_nvim.project')
    end)

    after_each(function()
      restore_fn()
      restore_notify()
      vim.fn.chdir(original_cwd)
    end)

    it('should create the project with the chosen stubs', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        choose('micropython-rp2-rpi_pico_w-stubs==1.24.1.*')

        Project.init()

        assert.is_truthy(
          read(dir, 'pyproject.toml'):find('"micropython-rp2-rpi_pico_w-stubs==1.24.1.*",', 1, true)
        )
        local pyright = vim.json.decode(read(dir, 'pyrightconfig.json'))
        assert.equals('typings', pyright.stubPath)
        assert.is_truthy(read(dir, '.gitignore'):find('typings/', 1, true))
        assert.equals(1, vim.fn.filereadable(dir .. '/main.py'))
      end)
    end)

    it('should create nothing when no stubs are chosen', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        choose(nil)

        Project.init()

        assert.same({}, vim.fn.readdir(dir))
      end)
    end)

    it('should install the stubs into typings after uv sync', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        answers.Run = 'Yes'
        choose('micropython-esp32-stubs')

        Project.init()

        assert.equals('uv sync', jobs[1].cmd)
        assert.is_nil(installed)
        jobs[1].opts.on_exit(1, 0)
        vim.wait(100, function()
          return installed ~= nil
        end)
        assert.equals('micropython-esp32-stubs', installed)
      end)
    end)

    it('should not install the stubs when uv sync fails', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        answers.Run = 'Yes'
        choose('micropython-esp32-stubs')

        Project.init()
        jobs[1].opts.on_exit(1, 1)
        vim.wait(50)

        assert.is_nil(installed)
      end)
    end)
  end)

  describe('install', function()
    local original_cwd
    local installed
    local jobs
    local restore_fn
    local restore_notify

    before_each(function()
      original_cwd = vim.fn.getcwd()
      installed = nil
      jobs = {}
      restore_fn = helpers.mock_vim_fn({
        jobstart = function(cmd, opts)
          table.insert(jobs, { cmd = cmd, opts = opts })
          return #jobs
        end,
        executable = function(name)
          return name == 'uv' and 1 or 0
        end,
      })
      local _
      _, restore_notify = helpers.mock_vim_notify()
      require('micropython_nvim.stubs').install = function(requirement)
        installed = requirement
      end
    end)

    after_each(function()
      restore_fn()
      restore_notify()
      vim.fn.chdir(original_cwd)
    end)

    it('should sync dependencies, then install the declared stubs into typings', function()
      helpers.with_temp_dir(function(dir)
        vim.fn.chdir(dir)
        vim.fn.writefile(vim.split(fixtures.pyproject_toml, '\n'), dir .. '/pyproject.toml')

        Project.install()
        jobs[1].opts.on_exit(1, 0)
        vim.wait(100, function()
          return installed ~= nil
        end)

        assert.equals('micropython-rp2-stubs', installed)
      end)
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

      it('should point pyright at the stubs in typings', function()
        local config = vim.json.decode(Project.TEMPLATES.pyright_config)
        assert.equals('typings', config.stubPath)
        assert.is_true(vim.tbl_contains(config.exclude, 'typings'))
      end)

      it('should disable reportMissingModuleSource', function()
        assert.is_true(Project.TEMPLATES.pyright_config:find('reportMissingModuleSource') ~= nil)
        assert.is_true(Project.TEMPLATES.pyright_config:find('false') ~= nil)
      end)
    end)
  end)
end)
