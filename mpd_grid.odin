package mpd_grid

import     "core:fmt"
import mpd "mpd"
import rl  "vendor:raylib"
import db "musicdb"
import "core:strings"

GRID_ROWS :: 4
GRID_COLS :: 4
FONT_SIZE :: 20

Window :: struct {
  name:          cstring,
  width:         i32,
  height:        i32,
  fps:           i32,
  control_flags: rl.ConfigFlags,
}

Gui_data :: struct {
  offset: int,
  uris: ^[]string,
  albums: ^db.Album_Map,
  font: ^rl.Font
}

Box :: struct {
  x : i32,
  y : i32,
}

draw_grid :: proc(window: ^Window, selected: ^Box, grid_data: ^Gui_data) {
  box_width := f32(window.width) / f32(GRID_COLS)
  box_height := f32(window.height) / f32(GRID_ROWS)
  i := 0

  for row_ix: f32 = 0; row_ix < GRID_ROWS; row_ix += 1 {
    y := box_height * row_ix
    for col_ix: f32 = 0; col_ix < GRID_COLS; col_ix += 1 {
      x := box_width * col_ix
      border_color: rl.Color
      if selected.x == i32(col_ix) && selected.y == i32(row_ix) {
        border_color = rl.BLUE
      } else {
        border_color = rl.GRAY
      }

      album := grid_data.albums^[grid_data.uris^[i+grid_data.offset]]

      rect := rl.Rectangle{x, y, box_width, box_height}
      rl.DrawRectangleRec(rect, rl.RAYWHITE)
      rl.DrawRectangleLinesEx(rect, 4, border_color)
      draw_box_content(album.artist, album.name, rect, box_width, box_height, grid_data.font)
      i += 1
    }
  }
}

draw_box_content :: proc(artist: string, album_name: string, box: rl.Rectangle, box_width, box_height: f32, font: ^rl.Font) {
  cs_artist := strings.clone_to_cstring(strings.trim(artist, " \t\n\r"))
  cs_album := strings.clone_to_cstring(strings.trim(album_name, " \t\n\r"))
  defer {
    delete(cs_artist)
    delete(cs_album)
  }

  artist_size := f32(FONT_SIZE)
  album_size := f32(FONT_SIZE)
  dash_size := f32(FONT_SIZE)

  spacing : f32 = 2.0
  min_size : f32 = 8.0

  for {
      artist_measure := rl.MeasureTextEx(font^, cs_artist, artist_size, spacing)
      album_measure := rl.MeasureTextEx(font^, cs_album, album_size, spacing)

      changed := false

      if artist_measure.x > box_width - 10 && artist_size > min_size {
          artist_size -= 1
          changed = true
      }

      if album_measure.x > box_width - 10 && album_size > min_size {
          album_size -= 1
          changed = true
      }

      if !changed {
          break
      }
  }

  dash_size = max(artist_size, album_size)

  artist_measure := rl.MeasureTextEx(font^, cs_artist, artist_size, spacing)
  dash_measure := rl.MeasureTextEx(font^, "-", dash_size, spacing)
  album_measure := rl.MeasureTextEx(font^, cs_album, album_size, spacing)

  total_height := artist_measure.y + dash_measure.y + album_measure.y + 10
  text_y := box.y + (box_height - total_height) / 2

  artist_x := box.x + (box_width - artist_measure.x) / 2
  dash_x := box.x + (box_width - dash_measure.x) / 2
  album_x := box.x + (box_width - album_measure.x) / 2

  rl.DrawTextEx(font^, cs_artist, [2]f32{artist_x, text_y}, artist_size, spacing, rl.BLACK)
  rl.DrawTextEx(font^, "-", [2]f32{dash_x, text_y + artist_measure.y}, dash_size, spacing, rl.BLACK)
  rl.DrawTextEx(font^, cs_album, [2]f32{album_x, text_y + artist_measure.y + dash_measure.y}, album_size, spacing, rl.BLACK)
}

Direction :: enum{Up, Right, Down, Left}
move_selected :: proc(selected: ^Box, direction: Direction, grid_data: ^Gui_data) {
  switch direction {
    case .Up:
      if selected.y -1 < 0 {
        if grid_data.offset >= GRID_ROWS + 1{
         grid_data.offset -= GRID_ROWS
        }
        break
      }
      selected.y -= 1
    case .Down:
      if selected.y + 1 >= GRID_ROWS {
        grid_data.offset += GRID_COLS
        break
      }
      selected.y += 1
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
    db_m := db.db_init()
    defer db.db_free(&db_m)

    res := mpd.mpd_send_list_all_meta(conn, "")
    if !res {
      fmt.println("Failed to get data")
      return
    }
    for {
      entity := mpd.mpd_recv_entity(conn)
      if entity == nil {
        break
      }
      defer mpd.mpd_entity_free(entity)

      type := mpd.mpd_entity_get_type (entity)
      if type == mpd.MPD_Entity_Type.SONG {
        song := mpd.mpd_entity_get_song(entity)
        db.add_song(&db_m, song)
      }
    }

    offset := 0
    uris := db.get_uris(&db_m)
    defer delete(uris)

    window := Window{"mpd_nowplaying", 1400, 1400, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

    rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
    rl.InitWindow(window.width, window.height, window.name)
    font := rl.LoadFontEx("assets/IosevkaNerdFont-Bold.ttf", FONT_SIZE, nil, 17000)

    defer {
      rl.UnloadFont(font)
      rl.CloseWindow()
    }

    rl.SetWindowState(window.control_flags)
    rl.SetTargetFPS(window.fps)
    grid_data := Gui_data{offset, &uris, &db_m, &font}

    selected := Box{0,0}

    for !rl.WindowShouldClose() {

      if rl.IsWindowResized() {
        window.width = rl.GetScreenWidth()
        window.height = rl.GetScreenHeight()
      }
      if rl.IsKeyPressed(rl.KeyboardKey.Q) {
        break
      } else if rl.IsKeyPressed(rl.KeyboardKey.K){
        move_selected(&selected, Direction.Up, &grid_data)
      } else if rl.IsKeyPressed(rl.KeyboardKey.J){
        move_selected(&selected, Direction.Down, &grid_data)
      } else if rl.IsKeyPressed(rl.KeyboardKey.H){
        move_selected(&selected, Direction.Left, &grid_data)
      } else if rl.IsKeyPressed(rl.KeyboardKey.L){
        move_selected(&selected, Direction.Right, &grid_data)
      }

      rl.BeginDrawing()

      rl.ClearBackground(rl.RAYWHITE)
      draw_grid(&window, &selected, &grid_data)

      rl.EndDrawing()
    }

}
