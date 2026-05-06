# REPL Command History

The Soroban Debugger REPL provides persistent command history to help you retain your iterative debugging workflows across sessions.

## History Persistence
By default, the REPL saves your command history to a file in your home directory (`~/.soroban_repl_history`). This history is loaded automatically the next time you start a REPL session.

You can customize this behavior via the `.soroban-debug.toml` configuration file in your project directory:

```toml
[repl]
# Disable history saving
save_history = false

# Use a custom history file
history_file = ".my_custom_repl_history"
```

## Sensitive Commands
The REPL automatically filters commands that appear to contain sensitive data (e.g., arguments containing "secret", "token", "key", or "password") so they are not written to your history file in plaintext.

## Managing History
While inside the REPL, you can use the `history` command to view your session history:
```
> history

Command History:
  0: call initialize '{"admin": "GAAA..."}'
  1: storage
```