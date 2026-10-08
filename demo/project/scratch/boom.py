"""Raises on purpose. Used to check errors are shown, not swallowed."""


def fail():
    raise ValueError("boom: this error is expected")


fail()
