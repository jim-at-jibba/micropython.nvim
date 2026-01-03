local M = {}

function M.reset_modules()
  package.loaded['micropython_nvim'] = nil
  package.loaded['micropython_nvim.config'] = nil
  package.loaded['micropython_nvim.utils'] = nil
  package.loaded['micropython_nvim.run'] = nil
  package.loaded['micropython_nvim.setup'] = nil
  package.loaded['micropython_nvim.project'] = nil
  package.loaded['micropython_nvim.repl'] = nil
  package.loaded['micropython_nvim.ui'] = nil
end

function M.mock_vim_fn(overrides)
  local original_fn = vim.fn
  local proxy = setmetatable({}, {
    __index = function(_, key)
      if overrides[key] then
        return overrides[key]
      end
      return original_fn[key]
    end,
  })
  vim.fn = proxy
  return function()
    vim.fn = original_fn
  end
end

function M.mock_vim_notify()
  local notifications = {}
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end
  return notifications, function()
    vim.notify = original_notify
  end
end

function M.stub_snacks(picker_callback)
  local original_snacks = rawget(_G, 'Snacks')
  local mock_snacks = {
    terminal = function() end,
    picker = {
      pick = function(opts)
        if picker_callback then
          picker_callback(opts)
        end
      end,
    },
  }
  rawset(_G, 'Snacks', mock_snacks)
  return function()
    if original_snacks then
      rawset(_G, 'Snacks', original_snacks)
    else
      rawset(_G, 'Snacks', nil)
    end
  end
end

function M.with_temp_file(content, fn)
  local tmpname = os.tmpname()
  local file = io.open(tmpname, 'w')
  if file then
    file:write(content)
    file:close()
  end

  local ok, err = pcall(fn, tmpname)

  os.remove(tmpname)

  if not ok then
    error(err)
  end
end

function M.with_temp_dir(fn)
  local tmpdir = os.tmpname()
  os.remove(tmpdir)
  vim.fn.mkdir(tmpdir, 'p')

  local ok, err = pcall(fn, tmpdir)

  vim.fn.delete(tmpdir, 'rf')

  if not ok then
    error(err)
  end
end

return M
