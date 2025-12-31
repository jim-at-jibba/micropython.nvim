"""LED control module for MicroPython."""

from machine import Pin
from time import sleep


class LED:
    """Simple LED controller with on/off, toggle, and blink functionality."""

    def __init__(self, pin, inverted=False):
        """
        Initialize LED on specified pin.

        Args:
            pin: Pin identifier (e.g., "LED", 25, or Pin object)
            inverted: If True, logic is inverted (LOW = on, HIGH = off)
        """
        if isinstance(pin, Pin):
            self._pin = pin
        else:
            self._pin = Pin(pin, Pin.OUT)
        self._inverted = inverted
        self._state = False
        self.off()

    def on(self):
        """Turn the LED on."""
        self._state = True
        self._pin.value(0 if self._inverted else 1)

    def off(self):
        """Turn the LED off."""
        self._state = False
        self._pin.value(1 if self._inverted else 0)

    def toggle(self):
        """Toggle the LED state."""
        if self._state:
            self.off()
        else:
            self.on()

    def is_on(self):
        """Return True if LED is currently on."""
        return self._state

    def blink(self, count=1, interval=0.5):
        """
        Blink the LED a specified number of times.

        Args:
            count: Number of times to blink
            interval: Time in seconds for each on/off phase
        """
        original_state = self._state
        for _ in range(count):
            self.on()
            sleep(interval)
            self.off()
            sleep(interval)
        if original_state:
            self.on()
