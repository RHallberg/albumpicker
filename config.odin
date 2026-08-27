package albumpicker
import rl  "vendor:raylib"

// Layout
GRID_ROWS :: 4
GRID_COLS :: 4
FONT_SIZE :: 18
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

Keybind :: struct {
  shift: bool,
  ctrl: bool,
  key: rl.KeyboardKey,
  action: UserAction,
}

UserAction :: enum {
  EXIT,
  ADD_ALBUM,
  ENQUEUE_ALBUM,
  RESET_GRID,
  RANDOMIZE_GRID,
  SORT_GRID,
  SEARCH,
  EXIT_SEARCH,
  MOVE_UP,
  MOVE_DOWN,
  MOVE_LEFT,
  MOVE_RIGHT,
}


keybindings := []Keybind{
// shift  ctrl   rl.KeyboardKey         action
  {false, false, rl.KeyboardKey.Q,      .EXIT},
  {false, false, rl.KeyboardKey.ESCAPE, .EXIT},
  {false, false, rl.KeyboardKey.ENTER,  .ADD_ALBUM},
  {false, true,  rl.KeyboardKey.ENTER,  .ENQUEUE_ALBUM},
  {false, false, rl.KeyboardKey.SPACE,  .ADD_ALBUM},
  {false, true,  rl.KeyboardKey.SPACE,  .ENQUEUE_ALBUM},
  {false, false, rl.KeyboardKey.C,      .RESET_GRID},
  {false, true,  rl.KeyboardKey.F,      .SEARCH},
  {false, false, rl.KeyboardKey.TAB,    .SORT_GRID},
  {false, false, rl.KeyboardKey.R,      .RANDOMIZE_GRID},
  {false, true,  rl.KeyboardKey.F,      .EXIT_SEARCH},
  {false, false, rl.KeyboardKey.ENTER,  .EXIT_SEARCH},
  {false, false, rl.KeyboardKey.ESCAPE, .EXIT_SEARCH},
  {false, false, rl.KeyboardKey.K,      .MOVE_UP},
  {false, false, rl.KeyboardKey.UP,     .MOVE_UP},
  {false, false, rl.KeyboardKey.W,      .MOVE_UP},
  {false, false, rl.KeyboardKey.J,      .MOVE_DOWN},
  {false, false, rl.KeyboardKey.S,      .MOVE_DOWN},
  {false, false, rl.KeyboardKey.DOWN,   .MOVE_DOWN},
  {false, false, rl.KeyboardKey.H,      .MOVE_LEFT},
  {false, false, rl.KeyboardKey.A,      .MOVE_LEFT},
  {false, false, rl.KeyboardKey.LEFT,   .MOVE_LEFT},
  {false, false, rl.KeyboardKey.L,      .MOVE_RIGHT},
  {false, false, rl.KeyboardKey.D,      .MOVE_RIGHT},
  {false, false, rl.KeyboardKey.RIGHT,  .MOVE_RIGHT},
}
//TODO Add keybindings
