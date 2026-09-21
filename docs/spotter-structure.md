# Wireless-Spotter Database Structure


```Bash
database/country/:
bssid.gid = record history of gid
bssid.info = last network info
bssid.list = list of devices from this bssid
bssid.rate = result of scanned network

database/country/:
gid.points = list of bssid
gid.state0 = active (tried and it work)
gid.state1 = inactive (tried but didnt work)
gid.state2 = gateway (checked and its gw)
gid.state3 = blacklisted (tried but its reserved)
gid.state4 = whitelisted (tried and it has no limits)
```
