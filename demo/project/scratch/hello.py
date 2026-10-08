"""Prints a few facts about the board, then exits. Used by :MP run tests."""

import os
import sys

print("hello from scratch/hello.py")
print("platform:", sys.platform)
print("board:", os.uname().machine)
print("micropython:", ".".join(str(n) for n in sys.implementation.version[:3]))
