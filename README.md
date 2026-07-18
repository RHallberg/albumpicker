# MPD Album picker
Simple mpd album picker

### Controls:

**HJKL/WASD/Arrow keys:** Navigation

**Q/ESCAPE:** Quit

**Space/Enter:** Play album

**CTRL+Space/Enter:** Append album to queue

**Shift:** Show Titles

**TAB:** Toggle desc/asc sorting

**R:** Shuffle ordering

**CTRL+F:** Start search mode

**C:** Reset search

### In search mode:
Naively searches album and artist. No misspellings.

**ESC/Enter/CTRL+F:** Exit search


## Preview
![preview of the the program](screenshots/preview.gif "preview")

## Building

Dependencies:
 - mpd
 - libmpdclient
 - odin

```bash
$ odin build . -build-mode:exe
```

### Installation

```bash
$ sudo make clean install
```


