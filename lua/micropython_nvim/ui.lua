local M = {}

---@param items string[]
---@param opts { prompt: string }
---@param on_choice fun(choice: string|nil)
function M.select(items, opts, on_choice)
  local Config = require('micropython_nvim.config')
  local ok, snacks = pcall(require, 'snacks')

  if ok and snacks.picker then
    local picker_items = {}
    for _, item in ipairs(items) do
      table.insert(picker_items, { text = item })
    end

    snacks.picker.pick({
      source = 'select',
      items = picker_items,
      format = 'text',
      prompt = opts.prompt,
      layout = Config.config.ui and Config.config.ui.picker_layout or 'select',
      confirm = function(picker, item)
        picker:close()
        if item then
          on_choice(item.text)
        else
          on_choice(nil)
        end
      end,
    })
  else
    vim.ui.select(items, {
      prompt = opts.prompt,
    }, on_choice)
  end
end

return M
