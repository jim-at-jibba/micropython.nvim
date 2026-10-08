"""Counts for a minute. Used to test stopping running code (Ctrl-C, :MP interrupt)."""

from time import sleep

for i in range(1, 61):
    print("count", i)
    sleep(1)
print("count finished")
