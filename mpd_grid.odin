package mpd_grid

import     "core:fmt"
import mpd "mpd"
import rl  "vendor:raylib"
import "core:strings"

GRID_ROWS :: 5
GRID_COLS :: 5
FONT_SIZE :: 20

Window :: struct {
  name:          cstring,
  width:         i32,
  height:        i32,
  fps:           i32,
  control_flags: rl.ConfigFlags,
}

Box :: struct {
  x : i32,
  y : i32,
}

print_song_info :: proc(entity: ^mpd.MPD_Entity) {
  song := mpd.mpd_entity_get_song(entity)

  artist := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0)
  album  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0)
  title  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0)
  uri    := mpd.mpd_song_get_uri(song)

  fmt.println(artist, album, title, "uri: ", uri)

}

draw_grid :: proc(window: ^Window, selected: ^Box) {
  box_width := f32(window.width) / f32(GRID_COLS)
  box_height := f32(window.height) / f32(GRID_ROWS)
  i := 0
  text: string

  for row_ix: f32 = 0; row_ix < GRID_ROWS; row_ix += 1 {
    y := box_height * row_ix
    for col_ix: f32 = 0; col_ix < GRID_COLS; col_ix += 1 {
      x := box_width * col_ix
      i += 1
      border_color: rl.Color
      if selected.x == i32(col_ix) && selected.y == i32(row_ix) {
        border_color = rl.BLUE
        text = "Selected"
      } else {
        border_color = rl.GRAY
        text = fmt.tprintf("%d", i)
      }
      rect := rl.Rectangle{x, y, box_width, box_height}
      rl.DrawRectangleRec(rect, rl.RAYWHITE)
      rl.DrawRectangleLinesEx(rect, 4, border_color)
      draw_box_content(text, rect, box_width, box_height)
    }
  }
}

draw_box_content :: proc(content: string, box: rl.Rectangle, box_width, box_height: f32) {
  cs_content := strings.clone_to_cstring(content)
  defer delete(cs_content)
  text_width := rl.MeasureText(cs_content, FONT_SIZE)
  text_x := box.x + (box_width - f32(text_width)) / 2
  text_y := box.y + (box_height - f32(FONT_SIZE)) / 2
  rl.DrawText(cs_content, i32(text_x), i32(text_y), FONT_SIZE, rl.BLACK)
}

Direction :: enum{Up, Right, Down, Left}
move_selected :: proc(selected: ^Box, direction: Direction) {
  switch direction {
    case .Up:
      selected.y = (selected.y - 1 + GRID_ROWS) % GRID_ROWS
    case .Down:
      selected.y = (selected.y + 1) % GRID_ROWS
    case .Left:
      selected.x = (selected.x - 1 + GRID_COLS) % GRID_COLS
    case .Right:
      selected.x = (selected.x + 1) % GRID_COLS
  }
}

main :: proc() {
    conn := mpd.mpd_connection_new(
        "localhost",
        6600,
        30000,
    )
    defer mpd.mpd_connection_free(conn)

    if conn == nil || mpd.mpd_connection_get_error(conn) != .SUCCESS {
        return
    }

    // res := mpd.mpd_send_list_all_meta(conn, "")
    // if !res {
    //   fmt.println("Failed to get data")
    //   return
    // }
    // for {
    //   entity := mpd.mpd_recv_entity(conn)
    //   if entity == nil {
    //     break
    //   }
    //   defer mpd.mpd_entity_free(entity)

    //   type := mpd.mpd_entity_get_type (entity)
    //   switch type {
    //     case mpd.MPD_Entity_Type.UNKNOWN:
    //       // fmt.println("Entity Unknown")
    //     case mpd.MPD_Entity_Type.DIRECTORY:
    //       // fmt.println("Entity Directory")
    //     case mpd.MPD_Entity_Type.SONG:
    //       print_song_info(entity)
    //     case mpd.MPD_Entity_Type.PLAYLIST:
    //       // fmt.println("Entity Playlist")
    //   }
    // }

    window := Window{"mpd_nowplaying", 900, 900, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

    rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
    rl.InitWindow(window.width, window.height, window.name)
    defer rl.CloseWindow()

    rl.SetWindowState(window.control_flags)
    rl.SetTargetFPS(window.fps)

    selected := Box{0,0}

    for !rl.WindowShouldClose() {

      if rl.IsWindowResized() {
        window.width = rl.GetScreenWidth()
        window.height = rl.GetScreenHeight()
      }
      if rl.IsKeyPressed(rl.KeyboardKey.Q) {
        break
      } else if rl.IsKeyPressed(rl.KeyboardKey.K){
        move_selected(&selected, Direction.Up)
      } else if rl.IsKeyPressed(rl.KeyboardKey.J){
        move_selected(&selected, Direction.Down)
      } else if rl.IsKeyPressed(rl.KeyboardKey.H){
        move_selected(&selected, Direction.Left)
      } else if rl.IsKeyPressed(rl.KeyboardKey.L){
        move_selected(&selected, Direction.Right)
      }

      rl.BeginDrawing()

      rl.ClearBackground(rl.PINK)
      draw_grid(&window, &selected)

      rl.EndDrawing()
    }

}
