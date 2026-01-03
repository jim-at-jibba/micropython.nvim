local helpers = require('test.helpers')

describe('micropython_nvim.ui', function()
  local UI
  local original_require

  before_each(function()
    helpers.reset_modules()
    require('micropython_nvim.config').setup({})
    UI = require('micropython_nvim.ui')
  end)

  describe('select', function()
    it('should be a function', function()
      assert.is_function(UI.select)
    end)

    describe('with snacks.picker available', function()
      it('should call snacks.picker.pick', function()
        local picker_called = false
        local picker_opts = nil

        package.loaded['snacks'] = {
          picker = {
            pick = function(opts)
              picker_called = true
              picker_opts = opts
            end,
          },
        }

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'option1', 'option2' }, { prompt = 'Test prompt:' }, function() end)

        assert.is_true(picker_called)
        assert.is_not_nil(picker_opts)
        assert.equals('select', picker_opts.source)
        assert.equals('Test prompt:', picker_opts.prompt)

        package.loaded['snacks'] = nil
      end)

      it('should pass items in correct format', function()
        local picker_opts = nil

        package.loaded['snacks'] = {
          picker = {
            pick = function(opts)
              picker_opts = opts
            end,
          },
        }

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'a', 'b', 'c' }, { prompt = 'Pick:' }, function() end)

        assert.equals(3, #picker_opts.items)
        assert.equals('a', picker_opts.items[1].text)
        assert.equals('b', picker_opts.items[2].text)
        assert.equals('c', picker_opts.items[3].text)

        package.loaded['snacks'] = nil
      end)

      it('should use configured picker layout', function()
        local picker_opts = nil

        package.loaded['snacks'] = {
          picker = {
            pick = function(opts)
              picker_opts = opts
            end,
          },
        }

        helpers.reset_modules()
        require('micropython_nvim.config').setup({ ui = { picker_layout = 'dropdown' } })
        UI = require('micropython_nvim.ui')

        UI.select({ 'option1' }, { prompt = 'Test:' }, function() end)

        assert.equals('dropdown', picker_opts.layout)

        package.loaded['snacks'] = nil
      end)

      it('should call on_choice with selected item text on confirm', function()
        local choice_result = nil

        package.loaded['snacks'] = {
          picker = {
            pick = function(opts)
              local mock_picker = { close = function() end }
              opts.confirm(mock_picker, { text = 'selected_option' })
            end,
          },
        }

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'option1', 'selected_option' }, { prompt = 'Pick:' }, function(choice)
          choice_result = choice
        end)

        assert.equals('selected_option', choice_result)

        package.loaded['snacks'] = nil
      end)

      it('should call on_choice with nil when no item selected', function()
        local choice_result = 'not_nil'

        package.loaded['snacks'] = {
          picker = {
            pick = function(opts)
              local mock_picker = { close = function() end }
              opts.confirm(mock_picker, nil)
            end,
          },
        }

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'option1' }, { prompt = 'Pick:' }, function(choice)
          choice_result = choice
        end)

        assert.is_nil(choice_result)

        package.loaded['snacks'] = nil
      end)
    end)

    describe('without snacks.picker (fallback)', function()
      it('should call vim.ui.select', function()
        package.loaded['snacks'] = nil

        local ui_select_called = false
        local ui_select_items = nil
        local ui_select_opts = nil
        local original_ui_select = vim.ui.select

        vim.ui.select = function(items, opts, on_choice)
          ui_select_called = true
          ui_select_items = items
          ui_select_opts = opts
        end

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'a', 'b' }, { prompt = 'Fallback test:' }, function() end)

        vim.ui.select = original_ui_select

        assert.is_true(ui_select_called)
        assert.same({ 'a', 'b' }, ui_select_items)
        assert.equals('Fallback test:', ui_select_opts.prompt)
      end)

      it('should pass on_choice callback to vim.ui.select', function()
        package.loaded['snacks'] = nil

        local callback_received = nil
        local original_ui_select = vim.ui.select

        vim.ui.select = function(items, opts, on_choice)
          on_choice('selected')
        end

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'option' }, { prompt = 'Test:' }, function(choice)
          callback_received = choice
        end)

        vim.ui.select = original_ui_select

        assert.equals('selected', callback_received)
      end)
    end)

    describe('with snacks but no picker', function()
      it('should fallback to vim.ui.select', function()
        package.loaded['snacks'] = {}

        local ui_select_called = false
        local original_ui_select = vim.ui.select

        vim.ui.select = function(items, opts, on_choice)
          ui_select_called = true
        end

        helpers.reset_modules()
        require('micropython_nvim.config').setup({})
        UI = require('micropython_nvim.ui')

        UI.select({ 'option' }, { prompt = 'Test:' }, function() end)

        vim.ui.select = original_ui_select

        assert.is_true(ui_select_called)

        package.loaded['snacks'] = nil
      end)
    end)
  end)
end)
