# LED Button Example

A multi-file MicroPython example demonstrating modular project structure.

## Project Structure

```
led_button/
├── main.py           # Entry point
├── lib/
│   ├── __init__.py   # Package marker
│   ├── led.py        # LED control module
│   └── button.py     # Button input module
├── .micropython      # Plugin configuration
└── README.md
```

## Hardware Requirements

- MicroPython-compatible board (Raspberry Pi Pico, ESP32, etc.)
- Built-in LED or external LED connected to a GPIO pin
- Push button connected to GPIO 15 (optional)

## Usage

### Quick Start

1. Open Neovim in this directory
2. Run `:MPSetPort` to select your device
3. Run `:MPUploadAll` to upload all files
4. Run `:MPRunMain` to execute

### Live Development with MPSync

For rapid development, use the mount feature:

1. Run `:MPSync` to mount this directory on the device
2. The local `lib/` directory becomes available as `/remote/lib/` on device
3. Edit files locally - changes are immediately available
4. Use `:MPRepl` and run `import main` to test

### Commands Used

| Command | Description |
|---------|-------------|
| `:MPUploadAll` | Upload all project files to device |
| `:MPRunMain` | Execute main.py on device |
| `:MPSync` | Mount local directory for live development |
| `:MPRepl` | Open interactive REPL |
| `:MPListFiles` | Show files on device |

## Customization

### Changing the LED Pin

Edit `main.py` and modify the LED initialization:

```python
led = LED(25)  # Use GPIO 25 instead of built-in LED
```

### Changing the Button Pin

```python
button = Button(14)  # Use GPIO 14
```

### Using External LED with Inverted Logic

```python
led = LED(25, inverted=True)  # LOW = on, HIGH = off
```
