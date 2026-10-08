# micropython.nvim

Working on MicroPython boards from Neovim: putting code on a device, running it, and talking to
it.

## Language

### Devices

**Device**:
A board running MicroPython, connected over USB serial.
_Avoid_: board (when you mean the connected thing), target, chip

**Port**:
The serial path a **Device** is reached on, such as `/dev/ttyACM0`, or `auto` to use the first
one found.
_Avoid_: connection, address

**Firmware**:
The MicroPython build installed on a **Device**, replaced by **Flashing**.

**Flashing**:
Replacing a **Device**'s **Firmware**. Leaves the files on the device alone only if the
firmware does.

**Custom firmware**:
**Firmware** not built by the MicroPython project, such as Pimoroni's Badger 2350 build, which
may freeze code in and make parts of the filesystem read-only.

### Project and files

**Project**:
The local directory Neovim is opened in, holding the code meant for a **Device** and its
`.micropython` settings.

**Upload**:
Copying **Project** files onto the **Device**'s filesystem, keeping their project-relative
paths. Skips anything on the **Ignore list**.
_Avoid_: sync, deploy, push

**Ignore list**:
Names and project paths that are never **Uploaded**: a default set (editor and tooling files,
**Stubs**) plus the user's own.

**Mount**:
Making the **Project** directory visible on the **Device** without copying it, for as long as
the mount session runs. Nothing is left on the device afterwards.
_Avoid_: sync (it copies nothing)

**Device file**:
A file stored on the **Device**'s filesystem, as opposed to a **Project** file. Opened for
editing as an `mp://<path>` buffer.

**Erase**:
Deleting **Device files**. Never touches the **Project**.

### Running code

**Run**:
Executing code on the **Device** from the **Project** without **Uploading** it first.

**REPL**:
The interactive MicroPython prompt on the **Device**. While it's open it holds the **Port**, so
other commands go through it or wait.

**Send**:
Pasting lines, a selection or a whole buffer into the open **REPL**.

**Interrupt**:
Stopping code running on the **Device** (Ctrl-C) without resetting it.

**Soft reset**:
Restarting the MicroPython interpreter, clearing its state; the **Device** stays connected.
_Avoid_: reset (on its own, ambiguous)

**Hard reset**:
Restarting the whole **Device**, as if it were unplugged and plugged back in.

### Editor support

**Stubs**:
Type-only Python packages describing a **Device**'s MicroPython modules, installed into the
**Project** so the language server can complete and check code. Never **Uploaded**.

**mip**:
MicroPython's package installer; installs libraries straight onto the **Device**.

## Relationships

- A **Project** targets one **Device** at a time through one **Port**
- **Upload** and **Mount** both make **Project** code available to a **Device**: **Upload** copies
  it and it survives a **Hard reset**; **Mount** lasts only for the session
- **Stubs** live in the **Project** for the editor; libraries installed with **mip** live on the
  **Device** for the code

## Example dialogue

> **Dev:** "I want my changes on the board every time I save."
> **Domain expert:** "Turn on upload on save: each save **Uploads** that file. If you'd rather not
> copy anything while you iterate, **Mount** the **Project** instead, but nothing stays on the
> **Device** once the mount ends."

## Flagged ambiguities

- `:MP sync` was named after "sync" but **Mounts**; it's being renamed `:MP mount`, with `sync`
  kept as a deprecated alias. `uv sync` (installing Python dependencies) is unrelated.
- "Reset" alone is ambiguous: always say **Soft reset** or **Hard reset**.
