# Version 1.0.0 changes:

## Whats new

- added script [tests/iface-tests.sh](https://github.com/spotter22/wireless-spotter/blob/main/tests/iface-tests.sh) for testing interface compatibility.

## Whats fixed

- fixed issue in `_connection_interface_state` where set interface down results in turning wifi off.
- fixed issue in `_connection_interface_setaddr` where testing interface failes on some devices.
