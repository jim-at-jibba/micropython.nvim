# Device views refresh on demand, never on their own

Every mpremote command, even listing files, enters the raw REPL, which Interrupts the code running
on the Device and needs the Port to be free. So the device file sidebar (`:MP files`) lists the
device only when the user opens it, presses `R`, or the plugin itself has just changed the device
(Upload, upload on save, Erase, mip), debounced and only while the sidebar is open. It never polls
and never refreshes on focus. When it can't list (REPL open, port busy, device missing) it keeps
the last good tree under a status line rather than retrying.

## Considered Options

- **Live tree like nvim-tree, refreshed on focus or a timer**: rejected. Each refresh would stop the
  user's running program and fight the REPL or a Mount session for the Port.
- **Snacks explorer source when snacks is installed**: rejected. Snacks' explorer assumes listings
  are cheap and frequent, and a second renderer would duplicate the keymaps and status handling.
- **Thonny-style pane** (lists only when the device is idle): this is the model we follow, minus
  Thonny's exclusive ownership of the connection.

## Consequences

- The tree can be stale after the user's own code writes files, or after **Run**. They press `R`.
- Auto-opening the sidebar on startup is ruled out, because opening it means listing.
