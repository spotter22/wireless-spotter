# wireless-spotter
**A set of utils which provides multiple wrappers for scanning, parsing and testing Wi-Fi networks.**

## Features
1. Supports manipulating output of `cmd wifi`, `iw`, `iproute2`, `arp-scan` and `arping`.
2. Supports parsing Captive-Portal's login page without JavaScript.
3. Multiple set of wrappers for querying, manipulating Network state.
4. Provides a ready environment for testing Wi-Fi attacks.

### Requirements
* Internal: `iproute2` `iw` `arp-scan`
* External: `arping` `arp-poison`


### Installation
* **Automatic installation:**
```Bash
curl -sL "https://raw.githubusercontent.com/spotter22/wireless-spotter/refs/heads/main/install.sh" | bash -s -- --install-latest
```

### Background
* It's all started back before few years (2023) when a friend
 requested me to write an application for discovering
 competitive Captive-Portals networks. My friend didn't
 liked using CLI application and the database structure
 at that time was a unorganised bare entries. Later on with
 some help we have adopted JSON manipulation.
 But after some period we discovered choosing JSON
 for database manipulation was a mistake since it's was
 too slow for handling a very large entries. Now we use our
 own database structure for manipulating all parsed entries.
