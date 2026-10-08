# Lines to send to the REPL. Open the REPL first (:MP repl).

# T1: put the cursor on the next line and run :MP send
answer = 21 * 2

# T2: send this line on its own; the REPL prints 42
print(answer)

# T3: select the whole function and the call below it (V), then :'<,'>MP send
def shout(text):
    for word in text.split():
        print(word.upper())

    return len(text)


shout("sent from neovim")

# T4: select ONLY the two lines inside the "if" (not the "if" line) and send them; they are
# dedented before sending, so the REPL does not raise IndentationError
if True:
    for n in range(3):
        print("dedented", n)

# T5: :MP send_buffer sends this whole file; the last line prints "buffer done"
print("buffer done")
