# AGENTS.md

## Commands
- Format: `stylua .`
- Format check: `stylua --check .`
- Lint: `luarocks install luacheck && luacheck .`
- Test all: `vusted ./test`
- Test single: `vusted ./test/plugin_spec.lua`

## Architecture

### Directory Structure

```
lua/
  micropython_nvim/    # Internal modules
    config.lua         # Configuration defaults and state
    run.lua            # Run/upload code to device
    setup.lua          # Configure port, baud, stubs
    repl.lua           # REPL access
    project.lua        # Project initialization
    utils.lua          # File I/O, config, helpers
  micropython_nvim.lua # Main entry point, public API
plugin/
  micropython_nvim.lua # Vim commands, lazy-loads plugin
test/
  plugin_spec.lua      # vusted test suite
doc/
  micropython.nvim.txt # Help documentation
```

### Module Pattern

```lua
-- Every module follows this structure
local M = {}

-- Private state
local state = {}

-- Private functions (local, underscore prefix)
local function _helper() end

-- Public methods
function M.public_func() end

return M
```

## Style Guide

### Naming

| Type | Convention | Example |
|------|------------|---------|
| Functions | snake_case | `get_port`, `upload_current` |
| Private funcs | underscore prefix | `local function _helper()` |
| Variables | snake_case | `ampy_port`, `file_path` |
| Constants | UPPER_CASE | `M.BAUD_RATES`, `M.DEFAULT_IGNORE_LIST` |
| Module table | `M` | `local M = {}` |
| Requires | PascalCase | `local Config = require(...)` |

### Type Annotations (LuaLS/EmmyLua)

Required on all public functions and classes:

```lua
---@class MicroPython.Config
---@field port? string Device port
---@field baud? number Baud rate
---@field debug? boolean Enable debug logging

---@param opts? MicroPython.Config
function M.setup(opts) end

---@return string
function M.get_port() end
```

### Error Handling

```lua
-- pcall for external calls
local ok, handle = pcall(io.popen, command)
if not ok or not handle then
  vim.notify("Command failed", vim.log.levels.WARN, { title = "micropython.nvim" })
  return {}
end

-- Validate user input in callbacks
vim.ui.select(options, { prompt = "Select:" }, function(choice)
  if not choice then
    return
  end
  -- proceed with choice
end)
```

### Code Style
- Formatter: stylua (100 char line width, 2 space indent, AutoPreferSingle quotes)
- Use `local M = {}` module pattern, return `M` at end
- Use `vim.ui.select` for user interaction
- Use `vim.notify` with `vim.log.levels` and `{ title = "micropython.nvim" }`
- Template strings using `[[...]]` for multi-line content

## Configuration

### Config Module Pattern

```lua
-- lua/micropython_nvim/config.lua
local defaults = {
  port = "/dev/ttyUSB0",
  baud = 115200,
  debug = false,
}

---@param opts? MicroPython.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end
```

### User Setup

```lua
require("micropython_nvim").setup({
  port = "/dev/ttyACM0",
  baud = 115200,
  debug = true,
})
```

## Testing

### Framework

vusted

### Patterns

```lua
describe("feature", function()
  before_each(function()
    -- Reset state
  end)

  it("does thing", function()
    assert.same(expected, actual)
  end)
end)
```

## Key Patterns

### 1. Facade for Public API

```lua
-- lua/micropython_nvim.lua exposes clean API, delegates to internal modules
local M = {}

function M.setup(opts)
  require("micropython_nvim.config").setup(opts)
  require("micropython_nvim.utils").read_ampy_config()
end

function M.run()
  require("micropython_nvim.run").run()
end

return M
```

### 2. Lazy Module Loading

All public API methods use lazy requires:

```lua
function M.run()
  require("micropython_nvim.run").run()
end
```

### 3. Commands in Plugin File

```lua
-- plugin/micropython_nvim.lua
vim.api.nvim_create_user_command("MPRun", function()
  require("micropython_nvim").run()
end, { desc = "Run current buffer on MicroPython device" })
```

### 4. Async Operations

```lua
local function _async_job(command, command_name)
  vim.fn.jobstart(command, {
    on_exit = function(_, exit_status, _)
      if exit_status == 0 then
        vim.notify(command_name .. " completed", vim.log.levels.INFO, { title = "micropython.nvim" })
      end
    end,
  })
end
```

## Common Tasks

### Add new feature module

1. Create `lua/micropython_nvim/feature.lua`
2. Add type annotations with `---@`
3. Export from `lua/micropython_nvim.lua` if public
4. Add command in `plugin/micropython_nvim.lua`
5. Add tests in `test/plugin_spec.lua`

### Add configuration option

1. Add to defaults in `config.lua`
2. Add `---@field` annotation to `MicroPython.Config`
3. Document in README

### Add user command

```lua
-- plugin/micropython_nvim.lua
vim.api.nvim_create_user_command("MPNewCommand", function(opts)
  require("micropython_nvim").feature(opts.args)
end, { nargs = "?", desc = "Description" })
```

## Conventions
- Config state: Use `config.lua` module instead of `_G` table
- Command assembly: Use `string.format()` for ampy/rshell commands
- Terminal usage: Use `Snacks.terminal(command)` for floating terminals
- Async operations: Use `vim.fn.jobstart()` with `on_exit` callback
- File operations: Use `vim.fn` functions for file I/O in user-facing code, `io.*` for internals
- Project root: All operations assume Neovim opened at project root
- Config sync: Update both config module state and `.ampy` file

## Safety
- Always validate user input in `vim.ui.select` callbacks (check for `nil`)
- Use `2>&1` in terminal commands to capture errors
- Verify file readability with `vim.fn.filereadable()` before operations
- Handle `nil` returns from file operations gracefully
- Use `pcall` for external command execution with graceful degradation
