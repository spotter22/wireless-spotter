# Version 1.0.3 changes:

## Whats new

- migrated `_connection_interface_connect` to work with Magisk v31.1 (31100).
- dropped disconnect requirement when connecting into networks.

## Whats fixed

- improved `_connection_interface_connect` to work with SSIDs containg backticks.
- improved `_connection_interface_getpsk` to prevent unnecessary repeated parses.
- fixed issue in `_connection_interface_reconnect` were set address option was invoked at incorrect time.
