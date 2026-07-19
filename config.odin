package albumpicker
import rl  "vendor:raylib"

// Layout
GRID_ROWS :: 4
GRID_COLS :: 5
FONT_SIZE :: 15
BORDER_THICKNESS :: 2


// Colors
FONT_COLOR :: rl.RAYWHITE
BORDER_COLOR :: rl.RAYWHITE
BOX_BACKGROUND_COLOR :: rl.LIGHTGRAY
BOX_TEXT_BACKGROUND_COLOR :: rl.BLACK
SELECTED_COLOR :: rl.BLUE

MPD_HOST :: "localhost"
MPD_PORT :: 6600

// Apparently raylib doesn't recognize setxkbmap swapcaps
// Uncomment to use the normal left control
// CTRL_KEY :: rl.KeyboardKey.LEFT_CONTROL
CTRL_KEY :: rl.KeyboardKey.CAPS_LOCK

//TODO Add keybindings
