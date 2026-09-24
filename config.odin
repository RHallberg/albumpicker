package albumpicker
import rl  "vendor:raylib"

// Layout
GRID_ROWS :: 6
GRID_COLS :: 7
FONT_SIZE :: 24
BORDER_THICKNESS :: 2
TEXT_PADDING :: 8


// Colors
FONT_COLOR :: rl.Color{76, 79, 105, 255}
ALBUM_FONT_COLOR :: rl.Color{205, 214, 244, 255}
BORDER_COLOR :: rl.Color{220, 224, 232, 255}
BOX_BACKGROUND_COLOR :: rl.LIGHTGRAY
SEARCH_BOX_BACKGROUND_COLOR :: rl.Color{204, 208, 218, 255}

BOX_TEXT_BACKGROUND_COLOR :: rl.Color{69, 71, 90, 255}
SELECTED_COLOR :: rl.Color{30, 102, 245, 255}

MPD_HOST :: "localhost"
MPD_PORT :: 6600

// Apparently raylib doesn't recognize setxkbmap swapcaps
// Uncomment to use the normal left control
// CTRL_KEY :: rl.KeyboardKey.LEFT_CONTROL
CTRL_KEY :: rl.KeyboardKey.CAPS_LOCK

Arg :: union {
    int,
    string,
}
Keybind :: struct {
  shift: bool,
  ctrl: bool,
  key: rl.KeyboardKey,
  action: UserAction,
  arg: Arg
}

UserAction :: enum {
  EXIT,
  ADD,
  ENQUEUE,
  SHOW_SONGS,
  RESET_GRID,
  RANDOMIZE_GRID,
  SORT_GRID,
  SEARCH,
  EXIT_SEARCH,
  MOVE_UP,
  MOVE_DOWN,
  MOVE_LEFT,
  MOVE_RIGHT,
  INCREASE_ROWS,
  INCREASE_COLS,
  DECREASE_ROWS,
  DECREASE_COLS,
}

keybindings := []Keybind{
// shift  ctrl   rl.KeyboardKey         action            arg
  {false, false, rl.KeyboardKey.Q,      .EXIT,            nil},
  {false, false, rl.KeyboardKey.ESCAPE, .EXIT,            nil},
  {false, false, rl.KeyboardKey.ENTER,  .ADD,             nil},
  {false, true,  rl.KeyboardKey.ENTER,  .ENQUEUE,         nil},
  {false, false, rl.KeyboardKey.SPACE,  .ADD,             nil},
  {false, true,  rl.KeyboardKey.SPACE,  .ENQUEUE,         nil},
  {false, false, rl.KeyboardKey.E,      .SHOW_SONGS,      nil},
  {false, false, rl.KeyboardKey.C,      .RESET_GRID,      nil},
  {false, true,  rl.KeyboardKey.F,      .SEARCH,          nil},
  {false, false, rl.KeyboardKey.TAB,    .SORT_GRID,       nil},
  {false, false, rl.KeyboardKey.R,      .RANDOMIZE_GRID,  nil},
  {false, true,  rl.KeyboardKey.F,      .EXIT_SEARCH,     nil},
  {false, false, rl.KeyboardKey.ENTER,  .EXIT_SEARCH,     nil},
  {false, false, rl.KeyboardKey.ESCAPE, .EXIT_SEARCH,     nil},
  {false, false, rl.KeyboardKey.K,      .MOVE_UP,         1},
  {false, true,  rl.KeyboardKey.K,      .MOVE_UP,         GRID_ROWS},
  {false, false, rl.KeyboardKey.UP,     .MOVE_UP,         1},
  {false, false, rl.KeyboardKey.W,      .MOVE_UP,         1},
  {false, false, rl.KeyboardKey.J,      .MOVE_DOWN,       1},
  {false, true,  rl.KeyboardKey.J,      .MOVE_DOWN,       GRID_ROWS},
  {false, false, rl.KeyboardKey.S,      .MOVE_DOWN,       1},
  {false, false, rl.KeyboardKey.DOWN,   .MOVE_DOWN,       1},
  {false, false, rl.KeyboardKey.H,      .MOVE_LEFT,       1},
  {false, false, rl.KeyboardKey.A,      .MOVE_LEFT,       1},
  {false, false, rl.KeyboardKey.LEFT,   .MOVE_LEFT,       1},
  {false, false, rl.KeyboardKey.L,      .MOVE_RIGHT,      1},
  {false, false, rl.KeyboardKey.D,      .MOVE_RIGHT,      1},
  {false, false, rl.KeyboardKey.RIGHT,  .MOVE_RIGHT,      1},
  {true, false,  rl.KeyboardKey.RIGHT,  .INCREASE_COLS,   nil},
  {true, false,  rl.KeyboardKey.LEFT,   .DECREASE_COLS,   nil},
  {true, false,  rl.KeyboardKey.UP,     .DECREASE_ROWS,   nil},
  {true, false,  rl.KeyboardKey.DOWN,   .INCREASE_ROWS,   nil},
}
