# MPD Album picker
Simple mpd album picker

**todo:** Add Searching
### Controls:

**HJKL/WASD/Arrow keys:** Navigation

**Q:** Quit

**Space/Enter:** Play album

**Shift:** Show Titles

**TAB:** Toggle desc/asc sorting

**R:** Shuffle ordering


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


