# Demo and manual tests

A demo MicroPython project and a written manual test suite for micropython.nvim v3. Use them to
check every feature on real hardware before a release.

| Path | What it is |
|------|------------|
| [MANUAL_TESTS.md](./MANUAL_TESTS.md) | The test suite: setup, one section per feature, recovery steps and a results table |
| [project/](./project) | The demo project. Open Neovim here for most tests |
| [legacy_v2/](./legacy_v2) | Two small v2-style projects (`.ampy`, and `BAUD=` in `.micropython`) for the migration tests |

## Devices

- **Raspberry Pi Pico (any model) with official MicroPython:** the primary test device. Every test
  applies to it, including changing firmware with `:MP flash`.
- **Pimoroni Badger 2350:** a second device that tests the plugin against custom firmware. Its
  launcher is frozen into the firmware, apps live on a read-only partition, and there's no
  official MicroPython build for it. Section G of the suite covers what that changes.

The demo app (`project/main.py`) runs on both. On a Pico it blinks the on-board LED; on the Badger
it draws a greeting on the e-paper screen and blinks the case lights.

## Quick start

```sh
cd demo/project
uv sync
nvim .
```

Then follow [MANUAL_TESTS.md](./MANUAL_TESTS.md), starting with section 0.
