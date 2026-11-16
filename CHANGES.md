# Version 1.0.4 changes:

## Whats new

- added new script [tests/getlogs.sh](https://github.com/spotter22/wireless-spotter/blob/main/tests/getlogs.sh) for analyzing or checking logs.

## Whats fixed

- improved pattern matching in `_302parser_parse_resources` by replacing previous one with new one.
- fixed issue in `_302parser_parse_auto` by reseting result store variable on every session for `_302parser_parse_resources`.
