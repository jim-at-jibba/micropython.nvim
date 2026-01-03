local M = {}

M.micropython_config = [[
# MicroPython project configuration
PORT=/dev/ttyUSB0
BAUD=115200
]]

M.micropython_config_auto = [[
PORT=auto
BAUD=115200
]]

M.ampy_config = [[
# Legacy ampy config
AMPY_PORT=/dev/ttyACM0
AMPY_BAUD=9600
]]

M.micropython_config_with_comments = [[
# This is a comment
PORT=/dev/ttyUSB0
# Another comment
BAUD=9600
# Final comment
]]

M.micropython_config_whitespace = [[
  PORT  =  /dev/ttyUSB0  
BAUD=115200
]]

M.pyproject_toml = [[
[project]
name = "test-project"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "mpremote",
    "ruff",
]

[tool.uv]
dev-dependencies = [
    "micropython-rp2-stubs",
]
]]

M.requirements_txt = [[
mpremote
micropython-rp2-stubs
]]

return M
