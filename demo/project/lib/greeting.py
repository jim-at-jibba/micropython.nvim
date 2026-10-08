"""Greeting text. Edit MESSAGE to check that uploads, mp:// buffers and :MP mount pick it up."""

MESSAGE = "Hello"


def greeting(name):
    return "{}, {}!".format(MESSAGE, name)
