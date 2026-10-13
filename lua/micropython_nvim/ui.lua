local M = {}

---@param items string[]
---@param opts { prompt: string }
---@param on_choice fun(choice: string|nil)
function M.select(items, opts, on_choice)
  local Config = require('micropython_nvim.config')
  local snacks = require('micropython_nvim.utils').get_snacks()

  if snacks and snacks.picker then
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

---Ask a yes/no question through the picker
---@param question string
---@param on_answer fun(yes: boolean) true only for an explicit Yes; No and cancel give false
function M.confirm(question, on_answer)
  M.select({ 'Yes', 'No' }, { prompt = question }, function(choice)
    on_answer(choice == 'Yes')
  end)
end

return M
