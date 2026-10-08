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
2. Run `:MP set_port` to select your device
3. Run `:MP upload_all` to upload all files, including `lib/`
4. Run `:MP run_main` to run `main.py`

### Live Development with `:MP mount`

For rapid development, use the mount feature:

1. Run `:MP mount` to mount this directory on the device
2. The local `lib/` directory becomes available as `/remote/lib/` on device
3. Edit files locally - changes are immediately available
4. Use `:MP repl` and run `import main` to test

### Commands Used

| Command | Description |
|---------|-------------|
| `:MP upload_all` | Upload all project files to device |
| `:MP run_main` | Run the local main.py on the device |
| `:MP mount` | Mount local directory for live development |
| `:MP repl` | Open interactive REPL |
| `:MP list_files` | Show files on device |

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
