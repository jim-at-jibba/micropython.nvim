"""Board helpers, so the demo runs on a Raspberry Pi Pico or a Pimoroni Badger 2350.

The Badger's firmware puts `badge` and `screen` into builtins at boot; a Pico has neither.
"""

import builtins
import os

badge = getattr(builtins, "badge", None)
screen = getattr(builtins, "screen", None)

IS_BADGER = badge is not None
NAME = os.uname().machine


def show(lines):
    """Print lines, and on a Badger also draw them on the e-paper screen."""
    for line in lines:
        print(line)
    if IS_BADGER:
        y = 10
        for line in lines:
            screen.text(line, 10, y)
            y += 20
        badge.update()


def light(on):
    """The Pico's on-board LED, or the Badger's case lights."""
    if IS_BADGER:
        badge.caselights(0.4 if on else 0)
    else:
        from machine import Pin

        Pin("LED", Pin.OUT).value(1 if on else 0)
