#  micropython_nvim

<!-- panvimdoc-ignore-start -->

<img width="1080" alt="image" src="./assets/cmd.png">

Theme: [duskfox](https://github.com/EdenEast/nightfox.nvim)

<details>
<summary>Showcase</summary>

<img width="1080" alt="image" src="./assets/port.png">
<img width="1080" alt="image" src="./assets/run.png">
<img width="1080" alt="image" src="./assets/status.png">

</details>

<!-- panvimdoc-ignore-end -->

## Introduction

micropython_nvim is a plugin that aims to make it easier and more enjoyable to work on MicroPython projects in Neovim. It uses [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html), the official MicroPython remote control tool.

See the [quickstart](#quickstart) section to get started.

N.B. If you open an existing project that has a `.micropython` configuration file in the root directory, the plugin will automatically configure the port and baud rate for you.

**IMPORTANT** This plugin assumes you are opening Neovim at the root of the project. Some commands will not behave in the expected way if you choose not to do this.

## Goals

- Run and upload python files directly to your micro-controller from Neovim
- Easy multi-file project support with recursive directory upload
- Live development with filesystem mounting
- General file management on device
- Easy management of port, baudrate, and other settings
- Easy project environment setup
- Built-in REPL access

## Features

- **Run** local python files on your micro-controller
- **Upload** local python files to your micro-controller (including recursive directory upload)
- **Sync** mount local directory for live development without uploading
- **REPL** access via mpremote
- **File management** - list, delete files on device
- **Device management** - list connected devices, reset
- **Project initialization**

## Requirements

- [Neovim >= 0.9](https://github.com/neovim/neovim/releases/tag/v0.9.0)
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html)
- [uv](https://docs.astral.sh/uv/) (for dependency management, Unix-only)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for nicer terminals and pickers. Without it the plugin uses Neovim's built-in terminal and `vim.ui.select`.
- Optional: [mpflash](https://github.com/Josverl/mpflash) for flashing firmware

Run `:checkhealth micropython_nvim` (or `:MP health`) to check your setup.

## Installation

### Prerequisites

Install uv (Unix/macOS):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Install mpremote (will be installed automatically by `uv sync`, or manually):

```bash
uv tool install mpremote
# or
pip install mpremote
```

### Plugin Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
    "jim-at-jibba/micropython.nvim",
    dependencies = { "folke/snacks.nvim" }, -- optional
}
```

</details>

<details>
<summary>packer</summary>

```lua
use {
    "jim-at-jibba/micropython.nvim",
    requires = { "folke/snacks.nvim" }, -- optional
}
```

</details>

## Quickstart

1. [Install](#installation) micropython_nvim using your preferred package manager
2. Add a keybind to `run` function:

```lua
vim.keymap.set("n", "<leader>mr", require("micropython_nvim").run)
```

3. Follow the [project setup](#project-setup) steps to create the necessary files for a new project.

**Next steps**

- Add a [statusline component](#statusline)
- See the [examples](./examples/) directory for multi-file project examples

## Usage

All commands live under a single `:MP` command with tab completion: type `:MP <Tab>` to see them. Running `:MP` on its own opens a picker.

### Core Commands

| Command | Description |
|---------|-------------|
| `:MP run` | Run current buffer on the micro-controller |
| `:MP run_main` | Run main.py on the device |
| `:MP upload` | Upload current buffer to the micro-controller |
| `:MP upload_all` | Upload all project files (recursive) |
| `:MP repl` | Open MicroPython REPL |

### Development Commands

| Command | Description |
|---------|-------------|
| `:MP sync` | Mount local directory on device for live development |
| `:MP reset` | Soft reset the device |
| `:MP hard_reset` | Hard reset the device |

### File Management

| Command | Description |
|---------|-------------|
| `:MP list_files` | List files on device |
| `:MP erase` | Delete single file or folder from device |
| `:MP erase_all` | Delete all files from device |

### Setup Commands

| Command | Description |
|---------|-------------|
| `:MP init` | Initialize MicroPython project (creates pyproject.toml, selects board) |
| `:MP install` | Install project dependencies with uv |
| `:MP set_port` | Set the device port |
| `:MP set_baud` | Set the baud rate (optional, mpremote auto-detects) |
| `:MP set_stubs` | Set MicroPython stubs for your board |
| `:MP list_devices` | List connected MicroPython devices |
| `:MP health` | Run `:checkhealth micropython_nvim` |

### Legacy Commands

The previous `:MPxxx` commands still work as aliases:

| Legacy | Use instead |
|--------|-------------|
| `:MPRun` / `:MPRunMain` | `:MP run` / `:MP run_main` |
| `:MPUpload` / `:MPUploadAll` | `:MP upload` / `:MP upload_all` |
| `:MPRepl` / `:MPSync` | `:MP repl` / `:MP sync` |
| `:MPReset` / `:MPHardReset` | `:MP reset` / `:MP hard_reset` |
| `:MPListFiles` / `:MPListDevices` | `:MP list_files` / `:MP list_devices` |
| `:MPEraseOne` / `:MPEraseAll` | `:MP erase` / `:MP erase_all` |
| `:MPInit` / `:MPInstall` | `:MP init` / `:MP install` |
| `:MPSetPort` / `:MPSetBaud` / `:MPSetStubs` | `:MP set_port` / `:MP set_baud` / `:MP set_stubs` |

### Health Check

`:checkhealth micropython_nvim` reports on mpremote, uv, mpflash, snacks.nvim, the project config and whether a device is connected, with install hints for anything missing.

### Terminal Keymaps

Commands that open a terminal (`:MP run`, `:MP repl`, etc.) use the snacks.nvim terminal when it is installed, and a floating built-in Neovim terminal otherwise:

| Key | Mode | Action |
|-----|------|--------|
| `<Esc><Esc>` | Terminal | Exit to normal mode |
| `q` | Normal | Close terminal |

### Upload Ignore List

`:MP upload_all` accepts file or folder names to ignore: `:MP upload_all test.py unused`

Default ignore list:

```lua
{
  '.git', 'pyproject.toml', 'uv.lock', '.ampy', '.micropython', '.vscode',
  '.gitignore', 'project.pymakr', 'env', 'venv', '.venv', '__pycache__',
  '.python-version', '.micropy/', 'micropy.json', '.idea',
  'README.md', 'LICENSE', 'requirements.txt'
}
```

## Project Setup

Steps to initialize a project:

1. Create a new directory for your project
2. Open Neovim in the project directory
3. Run `:MP init` - this will:
   - Prompt you to select your target board (RP2, ESP32, etc.)
   - Create `pyproject.toml` with dependencies and stubs
   - Create `main.py` - starter blink program
   - Create `.micropython` - device configuration
   - Create `pyrightconfig.json` - LSP configuration
   - Create `.gitignore`
   - Optionally run `uv sync` to install dependencies

4. If you skipped the install prompt, run `:MP install` to install dependencies
5. Run `:MP set_port` to set the port (or use `auto` for auto-detection)

### Supported Boards

| Board | Stub Package |
|-------|--------------|
| Raspberry Pi Pico (RP2) | `micropython-rp2-stubs` |
| ESP32 | `micropython-esp32-stubs` |
| ESP8266 | `micropython-esp8266-stubs` |
| STM32 / Pyboard | `micropython-stm32-stubs` |
| SAMD (Wio Terminal) | `micropython-samd-stubs` |

### Configuration File

The `.micropython` file stores project configuration:

```
PORT=auto
BAUD=115200
```

Port options:
- `auto` - Auto-detect first USB serial port
- `/dev/ttyUSB0` - Specific port path
- `id:<serial>` - Connect by USB serial number

### Multi-File Projects

For projects with multiple files and directories, see the [examples/led_button](./examples/led_button) directory.

Key features for multi-file projects:
- `:MP upload_all` recursively uploads directories
- `:MP sync` mounts local directory for live development
- `:MP run_main` runs main.py after upload

### Live Development with `:MP sync`

The `:MP sync` command mounts your local project directory on the device as `/remote`. This allows you to:

1. Edit files locally
2. Changes are immediately available on device (no upload needed)
3. Import modules from your local directory
4. Rapidly iterate without waiting for uploads

```
:MP sync        " Mount current directory
:MP repl        " Open REPL
>>> import main  " Run your code
```

## Statusline

A statusline component shows the current port configuration.

### Lualine Component

```lua
require("lualine").setup({
    sections = {
        lualine_b = {
            {
              require("micropython_nvim").statusline,
              cond = package.loaded["micropython_nvim"] and require("micropython_nvim").exists,
            },
        }
    }
})
```

<!-- panvimdoc-ignore-start -->
<img width="1080" alt="image" src="./assets/status.png">
<!-- panvimdoc-ignore-end -->

## Migration from ampy

This plugin now uses mpremote instead of ampy. If you have existing projects with `.ampy` configuration files:

1. The plugin will still read `.ampy` files but will show a deprecation warning
2. Run `:MP init` to create a new `.micropython` configuration
3. Your `.ampy` file can be safely deleted after migration

Key differences:
- No need for rshell - mpremote has built-in REPL
- Auto-detection of devices with `PORT=auto`
- Recursive directory upload with `:MP upload_all`
- Live development with `:MP sync` (filesystem mounting)

## Examples

See the [examples](./examples/) directory for complete project examples:

- [led_button](./examples/led_button) - Multi-file project with LED and button modules

## Inspiration and Thanks

- [nvim-platformio.lua](https://github.com/anurag3301/nvim-platformio.lua)
