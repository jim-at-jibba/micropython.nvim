"""
Multi-file MicroPython example demonstrating modular project structure.

This example shows how to organize a MicroPython project with multiple
files and a lib/ directory for reusable modules.

Usage with micropython.nvim:
  1. Open Neovim in this directory
  2. Run :MPInit to create config (or copy .micropython from parent)
  3. Run :MPSetPort to select your device
  4. Run :MPUploadAll to upload all files to device
  5. Run :MPRunMain to execute main.py on device

For live development:
  - Run :MPSync to mount this directory on device
  - Changes to local files are immediately available on device
"""

from lib.led import LED
from lib.button import Button
from time import sleep


def main():
    led = LED("LED")
    button = Button(15)

    print("LED Button Demo")
    print("Press the button to toggle LED")
    print("LED will also blink every 2 seconds")

    blink_counter = 0

    while True:
        if button.is_pressed():
            led.toggle()
            print(f"Button pressed! LED is now {'ON' if led.is_on() else 'OFF'}")
            sleep(0.3)

        blink_counter += 1
        if blink_counter >= 20:
            led.blink(count=1, interval=0.1)
            blink_counter = 0

        sleep(0.1)


if __name__ == "__main__":
    main()
