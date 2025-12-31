"""Button input module for MicroPython."""

from machine import Pin


class Button:
    """Simple button controller with debouncing and callback support."""

    def __init__(self, pin, pull_up=True):
        """
        Initialize button on specified pin.

        Args:
            pin: Pin number or identifier
            pull_up: If True, use internal pull-up resistor (button connects to GND)
        """
        pull = Pin.PULL_UP if pull_up else Pin.PULL_DOWN
        self._pin = Pin(pin, Pin.IN, pull)
        self._pull_up = pull_up
        self._callback = None

    def is_pressed(self):
        """
        Return True if button is currently pressed.

        Accounts for pull-up/pull-down configuration.
        """
        value = self._pin.value()
        return value == 0 if self._pull_up else value == 1

    def wait_for_press(self):
        """Block until button is pressed."""
        while not self.is_pressed():
            pass

    def wait_for_release(self):
        """Block until button is released."""
        while self.is_pressed():
            pass

    def on_press(self, callback):
        """
        Register a callback for button press events.

        Args:
            callback: Function to call when button is pressed
        """
        self._callback = callback
        trigger = Pin.IRQ_FALLING if self._pull_up else Pin.IRQ_RISING
        self._pin.irq(trigger=trigger, handler=self._irq_handler)

    def _irq_handler(self, pin):
        """Internal IRQ handler."""
        if self._callback:
            self._callback()

    def disable_irq(self):
        """Disable interrupt handling."""
        self._pin.irq(handler=None)
