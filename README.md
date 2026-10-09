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

micropython_nvim makes it easier and more enjoyable to work on MicroPython projects in Neovim. It
uses [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html), the official
MicroPython remote control tool.

Documentation: <https://micropython-nvim.jamesbest.uk>

The documentation site has the full command reference, configuration, troubleshooting, a
playbook of everyday situations, and
[migrating from v2](https://micropython-nvim.jamesbest.uk/migrating-from-v2/).

## Features

- **Run** local Python files on your micro-controller
- **Upload** files to the device, keeping the project's folders, or on every save
- **Mount** your local directory for live development without uploading
- **REPL** in a persistent split: send the current line, a selection or the whole buffer, and
  stop running code
- **File browser**: browse, edit, delete, download and create files and folders on the device
- **Device management**: list connected devices, reset, show device info and set its clock
- **Packages**: install micropython-lib and GitHub packages on the device with `mip`
- **Firmware**: install or update MicroPython on the board with
  [mpflash](https://github.com/Josverl/mpflash)
- **Project initialization** with type stubs matched to the connected board, set up for pyright

## Requirements

- [Neovim >= 0.9](https://github.com/neovim/neovim/releases/tag/v0.9.0)
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html)
- [uv](https://docs.astral.sh/uv/) (for dependency management, Unix-only)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for nicer terminals and pickers.
  Without it the plugin uses Neovim's built-in terminal and `vim.ui.select`.
- Optional: [mpflash](https://github.com/Josverl/mpflash) for flashing firmware with `:MP flash`

Install uv, then mpremote (or `pip install mpremote`):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install mpremote
```

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
    "jim-at-jibba/micropython.nvim",
    dependencies = { "folke/snacks.nvim" }, -- optional
    config = function()
        require("micropython_nvim").setup()
    end,
}
```

</details>

<details>
<summary>packer</summary>

```lua
use {
    "jim-at-jibba/micropython.nvim",
    requires = { "folke/snacks.nvim" }, -- optional
    config = function()
        require("micropython_nvim").setup()
    end,
}
```

</details>

Call `setup()` even if you don't change any options: it reads the project's `.micropython` file
when Neovim starts. See
[Configuration](https://micropython-nvim.jamesbest.uk/configuration/) for the options.

Run `:checkhealth micropython_nvim` (or `:MP health`) to check your setup.

## Quickstart

1. Plug in your device, make a folder for the project and open Neovim in it. The plugin assumes
   Neovim is opened at the project's root.
2. Run `:MP init`. It suggests type stubs for the connected board and creates `main.py`,
   `pyproject.toml`, `.micropython` and `pyrightconfig.json`. Answer yes to `uv sync`.
3. Open `main.py` and run `:MP run`. On a Pico, the LED blinks.
4. Add a keymap:

```lua
vim.keymap.set("n", "<leader>mr", require("micropython_nvim").run, { desc = "MicroPython: run file" })
```

Every command lives under `:MP`: type `:MP <Tab>` to see them, or `:MP` on its own for a picker.
[Getting started](https://micropython-nvim.jamesbest.uk/getting-started/) walks through this in
more detail, and the [Commands](https://micropython-nvim.jamesbest.uk/commands/) reference covers
each one.

Upgrading from v2? The `:MPxxx` commands are now `:MP <subcommand>`. See
[Migrating from v2](https://micropython-nvim.jamesbest.uk/migrating-from-v2/).

## Examples

See the [examples](./examples/) directory for complete project examples:

- [led_button](./examples/led_button) - Multi-file project with LED and button modules

## Inspiration and Thanks

- [nvim-platformio.lua](https://github.com/anurag3301/nvim-platformio.lua)
