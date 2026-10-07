# AGENTS.md

## Commands
- Format: `stylua .`
- Format check: `stylua --check .`
- Lint: `luacheck .`
- Test all: `vusted ./test`
- Test single: `vusted ./test/plugin_spec.lua`

## Architecture

### Directory Structure

```
lua/
  micropython_nvim/    # Internal modules
    commands.lua       # :MP subcommand registry, dispatch and completion
    config.lua         # Configuration defaults and state
    health.lua         # :checkhealth micropython_nvim
    mpremote.lua       # Shared mpremote runner (argv, async jobs, terminal commands)
    run.lua            # Run code, reset, erase and list files on the device
    device.lua         # Board detection, device info (firmware, board, storage, clock) and mip installs
    upload.lua         # Upload files (keeping project paths) and upload on save
    files.lua          # Device file browser and mp://<path> buffers
    setup.lua          # Configure port, stubs
    stubs.lua          # Stub suggestions (PyPI-checked), typings install, pyright config
    flash.lua          # Firmware flashing with mpflash: version picker, serial port resolution
    repl.lua           # Persistent REPL split: send line/selection/buffer, interrupt
    terminal.lua       # Terminal: snacks.nvim if installed, else built-in float
    ui.lua             # Picker: snacks.nvim if installed, else vim.ui.select
    project.lua        # Project initialization
    utils.lua          # File I/O, config, helpers
  micropython_nvim.lua # Main entry point, public API
plugin/
  micropython_nvim.lua # :MP command and mp:// buffer autocmds
test/
  *_spec.lua           # vusted test suites, one per module
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
| Variables | snake_case | `device_port`, `file_path` |
| Constants | UPPER_CASE | `M.MAX_VERSIONS`, `M.DEFAULT_IGNORE_LIST` |
| Module table | `M` | `local M = {}` |
| Requires | PascalCase | `local Config = require(...)` |

### Type Annotations (LuaLS/EmmyLua)

Required on all public functions and classes:

```lua
---@class MicroPython.Config
---@field port? string Device port
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
- Use `require('micropython_nvim.ui').select` for user interaction (snacks picker or `vim.ui.select`)
- Use `vim.notify` with `vim.log.levels` and `{ title = "micropython.nvim" }`
- Template strings using `[[...]]` for multi-line content

## Configuration

### Config Module Pattern

```lua
-- lua/micropython_nvim/config.lua
local defaults = {
  port = "auto",
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
  require("micropython_nvim.utils").read_config()
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

### 3. Subcommands in One Registry

```lua
-- lua/micropython_nvim/commands.lua: every :MP subcommand lives in M.subcommands
run = { desc = 'Run current buffer on the device', impl = _facade('run') },
```

### 4. Async Operations

```lua
-- Background: argv-based, no shell; notifies start/success/failure (with stderr) when named
Mpremote.run({ 'cp', file_path, ':' .. filename }, { name = 'Upload ' .. filename })

-- With a result callback
Mpremote.run({ 'fs', 'ls', ':' }, {
  on_exit = function(result) -- { code, stdout, stderr }
  end,
})
```

## Common Tasks

### Add new feature module

1. Create `lua/micropython_nvim/feature.lua`
2. Add type annotations with `---@`
3. Export from `lua/micropython_nvim.lua` if public
4. Add a subcommand to `M.subcommands` in `commands.lua`
5. Add tests in `test/<feature>_spec.lua`

### Add configuration option

1. Add to defaults in `config.lua`
2. Add `---@field` annotation to `MicroPython.Config`
3. Document in README

### Add a :MP subcommand

```lua
-- lua/micropython_nvim/commands.lua, in M.subcommands
feature = {
  desc = 'Description',
  impl = function(args)
    require('micropython_nvim').feature(args)
  end,
  complete = function(arglead) return {} end, -- optional argument completion
},
```

`:MP` is the only user command; do not add `:MPxxx` commands.

## Conventions
- Config state: Use `config.lua` module instead of `_G` table
- Command assembly: Build mpremote argv with `Mpremote.argv()`; use `Mpremote.command()` for shell-escaped terminal strings
- Terminal usage: Use `Terminal.open(command)` (never call `Snacks.terminal` directly); `Terminal.start` for a terminal in a window you manage, like the REPL split
- Async operations: Use `Mpremote.run(args, { name, on_exit })`
- File operations: Use `vim.fn` functions for file I/O in user-facing code, `io.*` for internals
- Project root: All operations assume Neovim opened at project root
- Config sync: Update both config module state and `.micropython` file

## Safety
- Always validate user input in `UI.select` callbacks (check for `nil`)
- Use `2>&1` in terminal commands to capture errors
- Verify file readability with `vim.fn.filereadable()` before operations
- Handle `nil` returns from file operations gracefully
- Use `pcall` for external command execution with graceful degradation

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on jim-at-jibba/micropython.nvim via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
