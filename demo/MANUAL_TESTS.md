# micropython.nvim v3 manual test suite

Hands-on tests for every v3 feature, run against real hardware before `v3` is merged into `main`.

- **Primary device:** a Raspberry Pi Pico (Pico, Pico W, Pico 2 or Pico 2 W) running official
  MicroPython. Every test applies to it.
- **Second device:** a Pimoroni Badger 2350. Its custom firmware changes how some features behave;
  those differences have their own section, [G. Badger 2350](#g-badger-2350), and are noted inline.

Each test lists its steps and what you should see. Tick the box for each device you ran it on, and
write anything unexpected under **Notes**. Copy failures into the [results](#results) table at the
end.

## Contents

- [0. Setup](#0-setup)
- [A. Install and health](#a-install-and-health)
- [C. Commands and pickers](#c-commands-and-pickers)
- [P. Connection and ports](#p-connection-and-ports)
- [I. Device info](#i-device-info)
- [R. Running code](#r-running-code)
- [U. Uploading](#u-uploading)
- [S. Upload on save](#s-upload-on-save)
- [B. File browser and mp:// buffers](#b-file-browser-and-mp-buffers)
- [L. REPL](#l-repl)
- [Y. Sync (mount)](#y-sync-mount)
- [X. Reset](#x-reset)
- [M. Packages (mip)](#m-packages-mip)
- [T. Project init and stubs](#t-project-init-and-stubs)
- [F. Firmware flashing](#f-firmware-flashing)
- [E. Erasing](#e-erasing)
- [Z. Errors and edge cases](#z-errors-and-edge-cases)
- [V. Migrating from v2](#v-migrating-from-v2)
- [N. Without snacks.nvim](#n-without-snacksnvim)
- [G. Badger 2350](#g-badger-2350)
- [Recovery](#recovery)
- [Results](#results)

---

## 0. Setup

### 0.1 Tools

Record the versions you test with:

| Tool | Command | Version |
|------|---------|---------|
| Neovim (>= 0.9) | `nvim --version` | |
| uv | `uv --version` | |
| mpremote | `uv run mpremote --version` (in `demo/project`, after 0.3) | |
| mpflash (for section F) | `mpflash --version` (install: `uv tool install mpflash`) | |
| snacks.nvim | installed? | |
| micropython.nvim | `git -C <repo> log --oneline -1` | |

### 0.2 Load the plugin from this checkout

Check out `v3` (or the branch under test), then point your plugin manager at the checkout, for
example with lazy.nvim:

```lua
{
    dir = "~/code/other/micropython.nvim",
    dependencies = { "folke/snacks.nvim" }, -- optional, see section N
    config = function()
        require("micropython_nvim").setup()
    end,
}
```

`setup()` reads `.micropython` from the directory Neovim was started in, so always start Neovim
from the folder a test names.

### 0.3 Demo project

```sh
cd demo/project
uv sync          # installs mpremote into .venv; the plugin runs it with `uv run mpremote`
nvim .
```

The project:

| Path | Used for |
|------|----------|
| `main.py` | Demo app: greeting, then blinks the LED (Pico) or case lights (Badger) every second |
| `lib/greeting.py`, `lib/device.py` | Modules `main.py` imports; tests project-relative uploads |
| `assets/notes.txt`, `assets/pixels.bin` | A text file and a binary file for the file browser |
| `scratch/hello.py` | Prints board facts and exits |
| `scratch/count.py` | Counts for 60 s; for stopping running code |
| `scratch/boom.py` | Raises `ValueError` on purpose |
| `scratch/repl_send.py` | Snippets T1 to T5 for the REPL tests |

### 0.4 Devices

- **Pico:** flash the latest stable MicroPython for your board from
  [micropython.org/download](https://micropython.org/download/?vendor=Raspberry%20Pi) (hold BOOTSEL
  while plugging in, drag the `.uf2` onto the drive). Start with an empty filesystem if you can:
  `uv run mpremote fs rm -r :` (this deletes every file on it).
- **Badger 2350:** update to the latest Pimoroni firmware first; see [Recovery](#recovery). Keep
  it on USB. Don't double-tap RESET during the tests: that switches it to USB disk mode and its
  serial port disappears.
- Connect **one device at a time** unless a test says otherwise. With port `auto`, mpremote uses
  the first USB serial device it finds.

Note your board (Pico, Pico W, Pico 2, Pico 2 W) here: ____________

---

## A. Install and health

### A1. Health check

1. In `demo/project`, with the device connected, run `:checkhealth micropython_nvim`.

**Expected:**

- `Neovim >= 0.9` OK.
- mpremote OK, with its version (from the project's `.venv` via uv).
- uv OK with version.
- snacks.nvim: OK if installed, otherwise info saying the built-in fallbacks are used.
- mpflash: OK with version, or info `mpflash not found (optional, for :MP flash)` with an install
  hint.
- Project: `Project config found: .../demo/project/.micropython`.
- Device: `Port auto; devices found: <port>`.

- [ ] Pico  - [ ] Badger
- Notes:

### A2. `:MP health`

1. Run `:MP health`.

**Expected:** the same report as A1.

- [ ] Pico
- Notes:

### A3. Health without a device

1. Unplug the device. Run `:checkhealth micropython_nvim`.
2. Plug it back in.

**Expected:** a warning `No MicroPython device found`. No error or hang.

- [ ] Pico
- Notes:

### A4. Health outside a project

1. `cd /tmp && nvim`, then `:checkhealth micropython_nvim`.

**Expected:** info saying there's no project config in `/tmp`, suggesting `:MP init`.

- [ ] Pico
- Notes:

---

## C. Commands and pickers

### C1. Only `:MP` exists

1. Type `:MP` and press `<Tab>` after `:MP` (with a trailing space).
2. Run `:MPRun`.

**Expected:**

1. Completion lists the subcommands: `erase`, `erase_all`, `files`, `flash`, `hard_reset`,
   `health`, `info`, `init`, `install`, `interrupt`, `list_devices`, `list_files`, `mip`, `repl`,
   `reset`, `run`, `run_main`, `send`, `send_buffer`, `set_port`, `set_stubs`, `sync`, `upload`,
   `upload_all`. There is no `set_baud`.
2. `E492: Not an editor command: MPRun`.

- [ ] Pico
- Notes:

### C2. Picker

1. Run `:MP` with no arguments.
2. Pick `info`.
3. Run `:MP` again and cancel with `<Esc>`.

**Expected:** a picker titled `MicroPython:` listing the subcommands. Picking `info` runs it.
Cancelling does nothing.

- [ ] Pico
- Notes:

### C3. Unknown subcommand and stray range

1. Run `:MP nope`.
2. Run `:1,3MP info`.

**Expected:**

1. Error: `Unknown subcommand "nope". Available: ...`.
2. Error: `"info" does not take a line range`.

- [ ] Pico
- Notes:

### C4. Argument completion

1. Type `:MP mip ` and press `<Tab>`.
2. Type `:MP flash ` and press `<Tab>`.

**Expected:**

1. Common micropython-lib packages (`aioble`, `logging`, `requests`, ...).
2. `stable` and `preview`.

- [ ] Pico
- Notes:

### C5. Statusline

1. Run `:lua print(require('micropython_nvim').statusline())`.
2. Run `:lua print(require('micropython_nvim').exists())`.

**Expected:**

1. ` auto`, or ` P:<port>` for a fixed port. There is no `BR:` (baud) part.
2. `true` in `demo/project`.

- [ ] Pico
- Notes:

---

## P. Connection and ports

### P1. List devices

1. Run `:MP list_devices`.

**Expected:** a notification `Available MicroPython devices:` with one line per device, as
`<port> (<serial>) - <vid:pid and name>`.

- Pico: `2e8a:0005 MicroPython Board in FS mode`.
- Badger: `2e8a:1100 Pimoroni Badger 2350 MicroPython`.

Note the serial number for P3: ____________

- [ ] Pico  - [ ] Badger
- Notes:

### P2. Set a fixed port

1. Run `:MP set_port`.
2. Pick your device's port (not `auto`).
3. Check `.micropython`.
4. Run `:MP info`.

**Expected:** the picker lists `auto` and the connected ports. The notification says
`Port set to: <port>`. `.micropython` now has `PORT=<port>`. `:MP info` works.

- [ ] Pico
- Notes:

### P3. Port by serial number

1. Edit `.micropython` to `PORT=id:<serial from P1>` and save.
2. Restart Neovim in `demo/project`.
3. Run `:MP info`.

**Expected:** `Config loaded from .../.micropython` on start. `:MP info` works. The statusline shows
` P:id:<serial>`.

- [ ] Pico
- Notes:

### P4. Back to auto

1. Run `:MP set_port` and pick `auto`.

**Expected:** `.micropython` has `PORT=auto`. Commands still work. **Leave it on `auto` for the
rest of the suite.**

- [ ] Pico
- Notes:

### P5. Wrong port

1. Edit `.micropython` to `PORT=/dev/does-not-exist`, then restart Neovim.
2. Run `:MP info`, then `:MP run` on `scratch/hello.py`.
3. Set the port back to `auto` (edit the file, restart).

**Expected:** each command fails with a readable mpremote error, such as
`failed to access /dev/does-not-exist`. Nothing hangs.

- [ ] Pico
- Notes:

---

## I. Device info

### I1. Info window

1. Run `:MP info`.

**Expected:** a window showing:

- Port.
- Firmware version (the MicroPython version).
- Board: the `os.uname().machine` string, such as `Raspberry Pi Pico W with RP2040`, or
  `Pimoroni Badger 2350 with RP2350` on the Badger.
- Storage used and free, plausible for the board. On the Badger, `/` is a 1 MiB LittleFS.
- The device clock.

- [ ] Pico  - [ ] Badger
- Notes:

### I2. Set the clock

1. In the info window press `s`.
2. Run `:MP info` again.

**Expected:** a notification that the clock was set. The clock now matches this computer to within
a few seconds. `q` and `<Esc>` close the window.

- [ ] Pico  - [ ] Badger
- Notes:

---

## R. Running code

### R1. Run a file

1. Open `scratch/hello.py` and run `:MP run`.

**Expected:** a terminal shows `hello from scratch/hello.py`, the platform (`rp2`), board and
version, then `Please Press ENTER to continue`. Enter closes it.

- [ ] Pico  - [ ] Badger
- Notes:

### R2. Errors are shown

1. Open `scratch/boom.py` and run `:MP run`.

**Expected:** the traceback with `ValueError: boom: this error is expected` appears in the
terminal. It isn't hidden or swallowed.

- [ ] Pico  - [ ] Badger
- Notes:

### R3. Stop running code from the terminal

1. Open `scratch/count.py` and run `:MP run`.
2. After a few counts, press `Ctrl-C` in the terminal (terminal mode).
3. Run `:MP run` on `scratch/hello.py`.

**Expected:** counting stops. The next command works; mpremote interrupts anything still running.

- [ ] Pico  - [ ] Badger
- Notes:

### R4. `:MP run_main` before uploading `lib/`

1. Start with `lib/` not on the device: on a fresh device, or run `:MP erase` and pick `lib/`.
2. Run `:MP run_main`.

**Expected:** the terminal shows `ImportError: no module named 'lib.device'` (or similar).
`run_main` runs your local `main.py`, but its imports come from the device. This is expected.

- [ ] Pico
- Notes:

### R5. `:MP run_main` after uploading

1. Run `:MP upload_all` and wait for it to finish.
2. Run `:MP run_main`, from any buffer.

**Expected:**

- The terminal prints `Hello, micropython.nvim!`, the board name, then `tick on` and `tick off`
  every second.
- Pico: the on-board LED blinks.
- Badger: the greeting is drawn on the screen and the case lights blink.

Stop it with `Ctrl-C`.

- [ ] Pico  - [ ] Badger
- Notes:

### R6. `:MP run_main` with no `main.py`

1. `cd demo/legacy_v2/baud_config && nvim hello.py`.
2. Run `:MP run_main`.

**Expected:** a warning `No main.py in .../baud_config. Open Neovim at the project root.` and no
terminal.

- [ ] Pico
- Notes:

### R7. Unsaved buffer

1. Open `scratch/hello.py` and change the first print to `print("unsaved edit")`. Don't save.
2. Run `:MP run`.
3. Undo the change.

**Expected:** record what runs. `:MP run` passes the file on disk, so the saved version runs.

- [ ] Pico
- Notes:

---

## U. Uploading

### U1. Upload the current buffer, keeping its path

1. Open `lib/greeting.py`.
2. Run `:MP upload`.
3. Run `:MP list_files`.

**Expected:** a notification that the upload started and then succeeded. The tree shows
`lib/greeting.py` inside `lib/`, not `greeting.py` at the root.

- [ ] Pico  - [ ] Badger
- Notes:

### U2. Upload the whole project

1. Run `:MP upload_all`.
2. Run `:MP list_files`.

**Expected:**

- On the device: `main.py`, `lib/` (with `__init__.py`, `device.py`, `greeting.py`), `assets/`
  (with `notes.txt`, `pixels.bin`) and `scratch/`.
- Not on the device: `README.md`, `pyproject.toml`, `uv.lock`, `.micropython`, `.gitignore`,
  `.venv/`.

- [ ] Pico  - [ ] Badger
- Notes:

### U2a. Editor files stay off the device (known issue)

1. Run `:MP install` in `demo/project`, which puts the stubs in `typings/`.
2. Run `:MP upload_all scratch`, then `:MP list_files`.

**Expected:** `typings/` and `pyrightconfig.json` are not uploaded.

**Known issue when this suite was written:** neither is on the default ignore list, so both are
uploaded. `typings/` holds hundreds of `.pyi` files and can fill the device. Expect this test to
fail until that's fixed. Until then, add `typings pyrightconfig.json` to every `:MP upload_all`.
If they were uploaded, remove them with `:MP erase` (pick `typings/`, then
`pyrightconfig.json`).

- [ ] Pico
- Notes:

### U3. Unchanged files are skipped

1. Run `:MP upload_all` again.
2. Change `MESSAGE` in `lib/greeting.py` to `"Hi"`, save, and run `:MP upload_all`.
3. Run `:MP run_main`, then stop it with `Ctrl-C`.

**Expected:**

- Step 1: still reports `Upload all (N files)`, but finishes much faster than U2. mpremote skips
  files whose content already matches the device copy.
- Step 2: also fast; only `lib/greeting.py` is actually copied.
- Step 3: prints `Hi, micropython.nvim!`.

Set `MESSAGE` back to `"Hello"` and upload it.

- [ ] Pico
- Notes:

### U4. Ignore arguments

1. Delete `scratch/` from the device: `:MP erase`, pick `scratch/`.
2. Run `:MP upload_all scratch assets/pixels.bin`.
3. Run `:MP list_files`.

**Expected:** `scratch/` and `assets/pixels.bin` are not uploaded. Everything else is up to date.
Then run `:MP upload_all` with no arguments to restore them.

- [ ] Pico
- Notes:

---

## S. Upload on save

### S1. Turn it on

1. Run `:lua require('micropython_nvim').setup({ upload_on_save = true })`.
2. Open `lib/greeting.py`, add a comment, and `:w`.

**Expected:** a notification that `lib/greeting.py` was uploaded. It lands at `:lib/greeting.py`.

- [ ] Pico  - [ ] Badger
- Notes:

### S2. Saves while uploading are queued

1. Save `lib/greeting.py`, then within a second save `lib/device.py` and `main.py`.

**Expected:** the files are uploaded in one or two batches, with no errors about the port being
busy.

- [ ] Pico
- Notes:

### S3. Ignored and outside files are not uploaded

1. Edit and save `README.md`.
2. `:e /tmp/outside.py`, write `print(1)`, and `:w`.

**Expected:** no upload for either.

- [ ] Pico
- Notes:

### S4. Not a MicroPython project

1. `cd demo/legacy_v2/ampy_only && nvim hello.py`.
2. Run `:lua require('micropython_nvim').setup({ upload_on_save = true })`.
3. Save `hello.py`.

**Expected:** no upload. This folder has no `.micropython`.

- [ ] Pico
- Notes:

Turn upload on save off again (restart Neovim) before continuing.

---

## B. File browser and mp:// buffers

### B1. Browse

1. Run `:MP files`.

**Expected:** a tree of the device filesystem with file sizes, and the free space in the header.
Neovim stays responsive while it loads.

- [ ] Pico  - [ ] Badger
- Notes:

### B2. Open, edit and write a device file

1. In the browser, move to `lib/greeting.py` and press `<CR>`.
2. Change `MESSAGE` to `"Edited on device"` and `:w`.
3. Run `:MP run_main`.

**Expected:**

- An `mp://lib/greeting.py` buffer with the device's copy.
- `:w` writes it to the device.
- `run_main` prints `Edited on device, micropython.nvim!`. Your local `lib/greeting.py` is
  unchanged.

Restore it with `:MP upload` from the local file.

- [ ] Pico  - [ ] Badger
- Notes:

### B3. Open by path

1. Run `:e mp://assets/notes.txt`, add a line, `:w`.
2. `:bd`, then `:e mp://assets/notes.txt` again.

**Expected:** your added line is there.

- [ ] Pico
- Notes:

### B4. Binary file

1. Run `:e mp://assets/pixels.bin`.

**Expected:** `assets/pixels.bin looks like a binary file and cannot be edited`. The buffer is
read-only, so `:w` can never write it.

- [ ] Pico
- Notes:

### B5. Missing file

1. Run `:e mp://does/not/exist.py` and try `:w`.

**Expected:** `Failed to read does/not/exist.py from the device:` with mpremote's error. The buffer
is read-only, so `:w` doesn't create an empty file.

- [ ] Pico
- Notes:

### B6. Browser actions

In `:MP files`:

1. On `assets/`, press `a` and create `newdir`.
2. Open `scratch/hello.py` in a normal buffer, run `:MP files`, move to `assets/newdir/`, press `u`.
3. On `assets/newdir/hello.py` press `D`.
4. On `assets/newdir/` press `d`, and confirm.
5. Press `R`, then `q`.

**Expected:**

1. `assets/newdir/` appears.
2. `hello.py` is uploaded into it.
3. It's downloaded into the project at `assets/newdir/hello.py`. Delete that local copy afterwards.
4. Asks first, then removes the folder and its contents.
5. `R` refreshes and `q` closes.

- [ ] Pico  - [ ] Badger
- Notes:

### B7. List files

1. Run `:MP list_files`.

**Expected:** a terminal showing `mpremote tree` output, then the Enter prompt.

- [ ] Pico  - [ ] Badger
- Notes:

---

## L. REPL

Open `scratch/repl_send.py` for these tests.

### L1. Open

1. Run `:MP repl`.
2. Run `:MP repl` again from the code window.

**Expected:** a persistent split with the MicroPython `>>>` prompt. The second `:MP repl` focuses
the same split; it doesn't open another.

- [ ] Pico  - [ ] Badger
- Notes:

### L2. Send a line (T1, T2)

1. In the code window, put the cursor on `answer = 21 * 2` and run `:MP send`.
2. Run `:MP send` on `print(answer)`.

**Expected:** `42` is printed in the REPL.

- [ ] Pico  - [ ] Badger
- Notes:

### L3. Send a selection with a block (T3)

1. Select from `def shout` to `shout("sent from neovim")` with `V`.
2. Run `:'<,'>MP send`.

**Expected:** `SENT`, `FROM` and `NEOVIM`, one per line. Several lines are sent in paste mode, so
the blank line inside the function doesn't end it early. The return value isn't echoed in paste
mode.

- [ ] Pico  - [ ] Badger
- Notes:

### L4. Indented selection is dedented (T4)

1. Select only the two lines inside `if True:`.
2. Run `:'<,'>MP send`.

**Expected:** `dedented 0`, `dedented 1` and `dedented 2`. No `IndentationError`.

- [ ] Pico
- Notes:

### L5. Send the buffer (T5)

1. Run `:MP send_buffer`.

**Expected:** the whole file runs in paste mode: `SENT`, `FROM`, `NEOVIM`, `dedented 0` to `2`,
then `buffer done`.

- [ ] Pico
- Notes:

### L6. Interrupt

1. In the REPL, type `while True: pass` and press Enter twice.
2. From the code window run `:MP interrupt`.

**Expected:** `KeyboardInterrupt`, and the `>>>` prompt comes back.

- [ ] Pico  - [ ] Badger
- Notes:

### L7. Run through the open REPL

1. With the REPL open, open `scratch/count.py` and run `:MP run`.
2. After a few counts run `:MP interrupt`.
3. Run `:MP run_main`, then `:MP interrupt` again.

**Expected:** both run inside the REPL split; no second terminal opens and there's no port busy
error. `:MP interrupt` stops each one.

- [ ] Pico  - [ ] Badger
- Notes:

### L8. Other commands while the REPL holds the port

1. With the REPL open, run `:MP list_files`, then `:MP info`.

**Expected:** record the behaviour. The README says to close the REPL first, so a port busy error
is acceptable. A hang, or a broken REPL afterwards, is not.

- [ ] Pico
- Notes:

### L9. Close and reopen

1. Close the REPL window (`:q` in it), then run `:MP repl` again.

**Expected:** a fresh REPL that works.

- [ ] Pico
- Notes:

Close the REPL before continuing.

---

## Y. Sync (mount)

### Y1. Mount and import

1. Run `:MP sync`.
2. At the prompt, type `from lib.greeting import greeting; greeting("sync")`.

**Expected:** a terminal showing the local directory mounted at `/remote` and a REPL. The command
prints `'Hello, sync!'`.

- [ ] Pico  - [ ] Badger
- Notes:

### Y2. Local edits without uploading

1. In another window change `MESSAGE` to `"Mounted"` and save. Leave upload on save off.
2. In the sync terminal press `Ctrl-D` (soft reset; the mount is kept), then repeat the Y1 import.
3. Run `import main`, then press `Ctrl-C`.

**Expected:**

- Step 2: `'Mounted, sync!'`.
- Step 3: the demo app starts from the mounted files.

Set `MESSAGE` back to `"Hello"`. Exit with `Ctrl-]` (or `Ctrl-x`).

- [ ] Pico  - [ ] Badger
- Notes:

---

## X. Reset

### X1. Soft reset

1. Run `:MP reset`.

**Expected:** a notification that the soft reset started and then succeeded. No terminal.

- [ ] Pico  - [ ] Badger
- Notes:

### X2. Hard reset

1. Run `:MP hard_reset`.
2. Wait a few seconds, then run `:MP info`.

**Expected:** the device reboots and `:MP info` works again.

- Pico: `main.py` from U2 starts running on boot and the LED blinks. `:MP info` still works,
  because mpremote interrupts it.
- Badger: the launcher shows again; see G2.

- [ ] Pico  - [ ] Badger
- Notes:

---

## M. Packages (mip)

### M1. Install from micropython-lib

1. Run `:MP mip logging`.
2. Run `:MP list_files`.
3. In `:MP repl`, run `import logging; logging.getLogger().warning("ok")`.

**Expected:** a background notification that `logging` is being installed, then success.
`lib/logging.mpy` (or `lib/logging/`) is on the device. The import works.

- [ ] Pico  - [ ] Badger
- Notes:

### M2. Picker

1. Run `:MP mip` with no package and pick `base64`.

**Expected:** a picker of common packages. Picking `base64` installs it.

- [ ] Pico
- Notes:

### M3. Install into a folder

1. Run `:MP mip datetime lib/vendor`.

**Expected:** installed under `lib/vendor/` on the device.

- [ ] Pico
- Notes:

### M4. Bad package

1. Run `:MP mip this-package-does-not-exist`.

**Expected:** an error notification with mpremote's message (a package-not-found error).

- [ ] Pico
- Notes:

---

## T. Project init and stubs

Use a scratch folder, so the demo project isn't overwritten.

### T1. Init with the device connected

1. `mkdir -p /tmp/mp-init && cd /tmp/mp-init && nvim`.
2. Run `:MP init`.

**Expected:**

- `Detecting the board for stubs...`, then a picker titled
  `Stubs for <board>, MicroPython <version>:`.
- The first items, pinned to the device's version when PyPI has it:

| Board | Expected first suggestions |
|-------|----------------------------|
| Pico | `micropython-rp2-rpi_pico-stubs==<ver>.*`, `micropython-rp2-stubs==<ver>.*` |
| Pico W | `micropython-rp2-rpi_pico_w-stubs==<ver>.*`, then the port package |
| Pico 2 | `micropython-rp2-rpi_pico2-stubs==<ver>.*`, then the port package |
| Pico 2 W | `micropython-rp2-rpi_pico2_w-stubs==<ver>.*`, then the port package |
| Badger 2350 | Only `micropython-rp2-stubs==1.29.0.*`, because PyPI has no Badger board package (see G5) |

- Below the suggestions, the full package list.
- Pick the first item. You get `pyproject.toml` (stubs under `dev-dependencies`),
  `pyrightconfig.json` (`"stubPath": "typings"`), `main.py`, `.micropython` (`PORT=auto`, no
  `BAUD`) and `.gitignore`, then an offer to run `uv sync`. Accept it.
- After `uv sync`, the stubs are installed into `typings/`.

- [ ] Pico  - [ ] Badger
- Notes:

### T2. Stubs work in pyright

1. In `/tmp/mp-init/main.py` add `import time` and `time.sleep_ms(10)`.
2. Hover `Pin` and `sleep_ms` (needs pyright or basedpyright configured).

**Expected:** no errors on `machine`, `Pin` or `time.sleep_ms`. Hover shows MicroPython
signatures, not CPython ones.

- [ ] Pico
- Notes:

### T3. Init again

1. In `/tmp/mp-init` run `:MP init` and answer `No`.

**Expected:** `Files exist (...). Overwrite?`. `No` gives `Project init cancelled` and leaves the
files unchanged.

- [ ] Pico
- Notes:

### T4. `:MP install`

1. Delete `/tmp/mp-init/typings` and `.venv`.
2. Run `:MP install`.

**Expected:** `uv sync` runs, then the stubs reinstall into `typings/`.

- [ ] Pico
- Notes:

### T5. Switch stubs

1. In `demo/project` run `:MP set_stubs` and pick the first suggestion.

**Expected:**

- The stubs line in `pyproject.toml` is replaced with the pick, and nothing else in the file
  changes.
- `pyrightconfig.json` keeps its `stubPath`.
- `Installed <requirement>`.

Restore `pyproject.toml` with `git checkout demo/project/pyproject.toml` afterwards.

- [ ] Pico
- Notes:

### T6. Stubs without a device

1. Unplug the device. In `/tmp/mp-init` run `:MP set_stubs`.

**Expected:** a picker titled `No device detected. Select stubs:` with the full list. No error.

- [ ] Pico
- Notes:

---

## F. Firmware flashing

Needs mpflash (`uv tool install mpflash`). These tests change the firmware on the **Pico**. Your
files are kept. For the Badger, see G6 instead.

### F1. Check what mpflash sees

1. In a shell, run `mpflash list`.

**Expected:** your Pico, with its board ID (`RPI_PICO`, `RPI_PICO_W`, `RPI_PICO2`, `RPI_PICO2_W`)
and version.

- [ ] Pico
- Notes:

### F2. Picker, then cancel

1. Run `:MP flash`.
2. Cancel the picker with `<Esc>`.

**Expected:**

- `Detecting the board to flash...`, then a picker titled
  `Flash <board> (now MicroPython <version>) with:`.
- Items: `stable`, `preview`, then up to ten releases, newest first.
- Cancelling does nothing.

- [ ] Pico
- Notes:

### F3. Downgrade

1. Run `:MP flash` and pick a release older than the current one (for example `1.28.0`).
2. When it finishes, press Enter.
3. Run `:MP info` and `:MP list_files`.

**Expected:**

- A terminal shows mpflash downloading the firmware, putting the Pico into its bootloader, copying
  the UF2 and restarting it.
- `:MP info` reports the older version.
- Your files are still there.

- [ ] Pico
- Notes:

### F4. Stubs follow the firmware

1. Run `:MP set_stubs`. Check the suggestions, then cancel.

**Expected:** suggestions pinned to the older version, such as `==1.28.0.*`.

- [ ] Pico
- Notes:

### F5. Flash with the REPL open, to a version given as an argument

1. Run `:MP repl`.
2. Run `:MP flash stable`.

**Expected:** the REPL closes first. There's no picker; it flashes the latest release. Afterwards
`:MP info` shows the latest version again.

- [ ] Pico
- Notes:

### F6. Without mpflash

1. In Neovim, hide mpflash:
   `:let $PATH = substitute($PATH, escape(fnamemodify(exepath('mpflash'), ':h'), '\.') . ':', '', '')`
2. Run `:MP flash`.
3. Restart Neovim.

**Expected:** error `mpflash not found. Install with: uv tool install mpflash (or: pip install
mpflash)`. If uv lives in the same folder, other commands may fail until you restart; that's fine.

- [ ] Pico
- Notes:

### F7. Too many arguments

1. Run `:MP flash 1.24.1 extra`.

**Expected:** `Usage: :MP flash [stable|preview|<version>]`.

- [ ] Pico
- Notes:

---

## E. Erasing

### E1. Erase one file

1. Run `:MP erase` and pick `main.py`.
2. Run `:MP list_files`.

**Expected:** a picker of the device's top-level files and folders only (folders end in `/`). The
file is deleted with a background notification. To delete a nested file, use `d` in `:MP files`.

- [ ] Pico  - [ ] Badger
- Notes:

### E2. Erase a folder

1. Run `:MP erase` and pick `scratch/`.

**Expected:** the folder and its contents are deleted.

- [ ] Pico
- Notes:

### E3. Erase everything (Pico)

1. Run `:MP erase_all`.
2. Run `:MP list_files`.

**Expected:** a terminal showing mpremote removing every file. The device is empty afterwards.
For the Badger, see G7.

- [ ] Pico
- Notes:

---

## Z. Errors and edge cases

### Z1. Port held by another program

1. In a shell in `demo/project`, run `uv run mpremote repl` and leave it open.
2. In Neovim run `:MP info`, then `:MP upload` on a file.
3. Close the shell's REPL with `Ctrl-]`.

**Expected:** each command fails with mpremote's error (port busy or could not open). Nothing hangs.

- [ ] Pico
- Notes:

### Z2. Unplug during an upload

1. Start `:MP upload_all` after changing a few files, and unplug the device straight away.
2. Plug it back in and run `:MP upload_all`.

**Expected:** a failure notification that includes mpremote's error. The next upload completes
normally.

- [ ] Pico
- Notes:

### Z3. No device at all

1. Unplug everything. Run `:MP run`, `:MP files`, `:MP info` and `:MP list_devices`.

**Expected:** each gives a readable error, or `No MicroPython devices found`. Nothing hangs, and
Neovim stays usable.

- [ ] Pico
- Notes:

### Z4. Two devices

1. Connect the Pico and the Badger.
2. Run `:MP list_devices`.
3. Run `:MP info` with port `auto`.
4. Run `:MP set_port`, pick the other one, and run `:MP info`.

**Expected:** both are listed. `auto` uses the first one mpremote finds; record which.
`set_port` switches to the other.

- [ ] Pico + Badger
- Notes:

---

## V. Migrating from v2

### V1. `.ampy` is no longer read

1. `cd demo/legacy_v2/ampy_only && nvim hello.py`.

**Expected:**

- No `.ampy config is deprecated` warning.
- `:lua print(require('micropython_nvim').exists())` prints `false`.
- `:checkhealth micropython_nvim` shows `No project config ...`, with no `.ampy` warning.
- `:MP run` uses port `auto` (not `AMPY_PORT`), so it works with the device connected.

- [ ] Pico
- Notes:

### V2. `BAUD` in `.micropython` is ignored

1. `cd demo/legacy_v2/baud_config && nvim hello.py`.
2. Run `:MP run`.

**Expected:** `Config loaded from .../.micropython` and no errors. Prints
`hello from a v2 project with BAUD`.

- [ ] Pico
- Notes:

### V3. `baud` in `setup()` is harmless

1. Run `:lua require('micropython_nvim').setup({ baud = 9600 })`, then `:MP info`.

**Expected:** no error. `:MP info` works.

- [ ] Pico
- Notes:

### V4. Old commands

1. Try `:MPUploadAll`, `:MPSetBaud` and `:MPInit`.

**Expected:** each gives `E492: Not an editor command`.

- [ ] Pico
- Notes:

---

## N. Without snacks.nvim

Start Neovim with only this plugin:

```sh
cd demo/project
nvim -u NONE --cmd "set rtp^=$HOME/code/other/micropython.nvim" \
  -c "runtime plugin/micropython_nvim.lua" -c "lua require('micropython_nvim').setup()"
```

### N1. Built-in terminal

1. Run `:MP run` on `scratch/hello.py`.

**Expected:** a floating Neovim terminal. `<Esc><Esc>` leaves terminal mode, and `q` closes it in
normal mode.

- [ ] Pico
- Notes:

### N2. Failing command keeps the terminal open

1. Run `:MP run` on `scratch/boom.py`.

**Expected:** the traceback stays visible until you close it.

- [ ] Pico
- Notes:

### N3. `vim.ui.select` pickers

1. Run `:MP`, then `:MP set_port`, then `:MP erase` (and cancel it).

**Expected:** the built-in `vim.ui.select` lists. Cancelling does nothing.

- [ ] Pico
- Notes:

### N4. REPL and browser without snacks

1. Run `:MP repl` and send a line.
2. Run `:MP files` and open a file.

**Expected:** both work as in L and B.

- [ ] Pico
- Notes:

---

## G. Badger 2350

The Badger runs Pimoroni's Badgeware firmware: MicroPython 1.29 with a launcher and apps frozen in.
Know these before testing:

- The launcher's `main.py` is frozen into the firmware. MicroPython runs a frozen `main.py`
  before one on the filesystem, so **an uploaded `main.py` never runs at boot**. The launcher
  always starts. Run the demo with `:MP run_main` instead.
- `/` is a 1 MiB LittleFS for your files. The launcher keeps its settings in `/state/`.
- The apps live in `/system`, a FAT partition that MicroPython mounts read-only.
- Official MicroPython has no Badger build, so mpflash can't install its firmware. Restoring
  Pimoroni firmware is done by hand; see [Recovery](#recovery).
- Double-tapping RESET enters USB disk mode, and the serial port disappears. Press RESET once to
  leave it.
- If the port disappears mid-test, the badge may be asleep. Press a front button or RESET.

### G1. Connect while the launcher runs

1. Press RESET so the launcher menu shows.
2. Run `:MP info`.

**Expected:** info appears. mpremote interrupts the launcher. If it hangs or errors, record the
exact message.

- [ ] Badger
- Notes:

### G2. Launcher after a reset

1. After U2 has put `main.py` on the badge, press RESET (or run `:MP hard_reset`).

**Expected:** the launcher menu appears, not the demo app. This is expected: the frozen
`main.py` wins.

- [ ] Badger
- Notes:

### G3. Read-only `/system`

1. In `:MP files`, open `system/` and confirm the apps are listed under `system/apps/`.
2. Open `system/main.py` with `<CR>`, add a comment, and `:w`.

**Expected:**

- The browser shows `system/` with the apps.
- The write fails with a read-only error (`EROFS` or similar), and the device file is unchanged.
- Close the buffer without saving (`:bd!`).

- [ ] Badger
- Notes:

### G4. The demo on the screen

1. Run `:MP run_main` after `:MP upload_all`.

**Expected:** the e-paper screen shows `Hello, micropython.nvim!` and
`Pimoroni Badger 2350 with RP2350`. The case lights blink every second, and the terminal prints the
ticks. Press `Ctrl-C`, then RESET to get the launcher back.

If the drawing fails with an error from `screen` or `badge`, that's a problem in the demo code (the
Badgeware API may have changed), not the plugin. Record it.

- [ ] Badger
- Notes:

### G5. Stub suggestion

1. In `/tmp/mp-init`, run `:MP set_stubs` (or `:MP init`).

**Expected:**

- The picker title shows the Badger and MicroPython 1.29.0, or a preview version.
- The only suggestion is `micropython-rp2-stubs==1.29.0.*`. Board packages such as
  `micropython-rp2-badger-stubs` aren't on PyPI, so none is offered.
- Write down the build the board reports:
  `:lua require('micropython_nvim.device').detect(function(b) print(vim.inspect(b)) end)` →
  ____________

Badgeware's builtins (`screen`, `badge`, `color`) have no stubs, so pyright flags them in your own
Badger apps. The demo's `lib/device.py` avoids this by using `getattr(builtins, ...)`.

- [ ] Badger
- Notes:

### G6. Flashing stops safely

1. In a shell, run `mpflash list` and write down the board ID it reports: ____________
   - **If it reports an official board ID** (such as `RPI_PICO2_W`), **stop here and skip step
     3**. Flashing would replace Badgeware with plain MicroPython; see [Recovery](#recovery).
2. Run `:MP flash`. The picker title should name the Badger and its version. Cancel with `<Esc>`.
3. Only if step 1 showed an unknown board (such as `badger`): run `:MP flash stable`.

**Expected:**

- Step 2: the picker, and nothing happens on cancel.
- Step 3: mpflash reports that it has no firmware for this board, and the badge is unchanged.
  Press RESET and the launcher still works.
- Record mpflash's exact output.

- [ ] Badger
- Notes:

### G7. Erase everything (Badger)

**This deletes your files on `/` and the launcher's settings in `/state/`.** The apps in `/system`
should survive.

1. Run `:MP erase_all`.
2. Run `:MP list_files`.
3. Press RESET.

**Expected:**

- Your files on `/` are gone.
- mpremote may stop with a read-only error when it reaches `/system`. Record what happens.
- After RESET the launcher starts with its default settings, and all apps are still there.
- If the launcher is broken, restore the firmware; see [Recovery](#recovery).

- [ ] Badger
- Notes:

### G8. Disk mode

1. Double-tap RESET. A `Badger2350` drive appears.
2. Run `:MP info`.
3. Press RESET once.

**Expected:** `:MP info` fails with a readable error (no device or port), with no hang. After
RESET, commands work again.

- [ ] Badger
- Notes:

---

## Recovery

**Pico:**

1. Hold BOOTSEL while plugging in. An `RPI-RP2` drive appears (`RP2350` on a Pico 2).
2. Drag the `.uf2` for your board onto it, from
   [micropython.org/download](https://micropython.org/download/?vendor=Raspberry%20Pi).

**Badger 2350:**

1. Download the latest firmware from
   [github.com/pimoroni/badger2350/releases](https://github.com/pimoroni/badger2350/releases/latest):
   - `badger-vX.Y.Z-micropython.uf2` replaces only the firmware and keeps your files.
   - `badger-vX.Y.Z-micropython-with-filesystem.uf2` also resets the apps and files to the defaults.
2. Hold BOOT (rear, far left), tap RESET, then release BOOT. An `RP2350` drive appears.
3. Drag the `.uf2` onto it. The badge restarts into the launcher.

---

## Results

| Test | Device | Result | Notes / issue |
|------|--------|--------|---------------|
| | | | |

When a test fails, open an issue with:

- The test ID.
- The device and firmware version (from `:MP info`).
- The steps you took.
- What you expected and what you saw.
- The output of `:messages`, and of `:checkhealth micropython_nvim` if relevant.
