"""micropython.nvim demo app: shows a greeting, then blinks until stopped.

Works on a Raspberry Pi Pico (on-board LED) and a Pimoroni Badger 2350 (e-paper screen and case
lights). It imports lib/, so upload the project first (:MP upload_all), then :MP run_main.
Stop it with Ctrl-C in the terminal, or :MP interrupt in the REPL.
"""

from time import sleep

from lib.device import NAME, light, show
from lib.greeting import greeting

show([greeting("micropython.nvim"), NAME])

on = False
while True:
    on = not on
    light(on)
    print("tick", "on" if on else "off")
    sleep(1)
