package mpd_grid

import     "core:fmt"
import mpd "mpd"
import rl  "vendor:raylib"
import db "musicdb"
import "core:strings"

GRID_ROWS :: 4
GRID_COLS :: 4
FONT_SIZE :: 20
BORDER_THICKNESS :: 4

Window :: struct {
  name:          cstring,
  width:         i32,
  height:        i32,
  fps:           i32,
  control_flags: rl.ConfigFlags,
}

Gui_Data :: struct {
  offset: int,
  uris: ^[]string,
  albums: ^db.Album_Map,
  albumart: ^Albumart_Map,
  font: ^rl.Font,
  render_text: bool
}
Albumart_Map :: map[string]rl.Texture


Box :: struct {
  x : i32,
  y : i32,
}

draw_grid :: proc(window: ^Window, selected: ^Box, grid_data: ^Gui_Data) {
  box_width := f32(window.width) / f32(GRID_COLS)
  box_height := f32(window.height) / f32(GRID_ROWS)
  outline_thickness := BORDER_THICKNESS
  i := 0

  for row_ix: f32 = 0; row_ix < GRID_ROWS; row_ix += 1 {
    y := box_height * row_ix
    for col_ix: f32 = 0; col_ix < GRID_COLS; col_ix += 1 {
      x := box_width * col_ix
      border_color: rl.Color

      uri := grid_data.uris^[i+grid_data.offset]
      album := grid_data.albums^[uri]

      rect := rl.Rectangle{x, y, box_width, box_height}
      rect_inner := rl.Rectangle{x + BORDER_THICKNESS, y + BORDER_THICKNESS, box_width - BORDER_THICKNESS*2, box_height - BORDER_THICKNESS*2}

      rl.DrawRectangleRec(rect, rl.RAYWHITE)

      tex, ok := grid_data.albumart[uri]
      if ok {
        draw_box_image_content(&tex, rect_inner)
        if grid_data.render_text {
          draw_box_text_content(album.artist, album.name, rect_inner, grid_data.font)
        }
      } else {
        draw_box_text_content(album.artist, album.name, rect_inner, grid_data.font)
      }
      if selected.x == i32(col_ix) && selected.y == i32(row_ix) {
        border_color = rl.BLUE
        rl.DrawRectangleRec(rect_inner, rl.Fade(rl.BLUE, 0.2))
      } else {
        border_color = rl.RAYWHITE
      }
      rl.DrawRectangleLinesEx(rect, BORDER_THICKNESS, border_color)
      i += 1
    }
  }
}

draw_box_image_content :: proc(texture: ^rl.Texture, box: rl.Rectangle) {
  source_rec := rl.Rectangle{
      x = 0.0,
      y = 0.0,
      width = f32(texture.width),
      height = f32(texture.height),
  }
  rl.DrawTexturePro(texture^, source_rec, box, rl.Vector2{0, 0}, 0, rl.WHITE)
}

draw_box_text_content :: proc(artist: string, album_name: string, box: rl.Rectangle, font: ^rl.Font) {
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

      if artist_measure.x > box.width - 10 && artist_size > min_size {
          artist_size -= 1
          changed = true
      }

      if album_measure.x > box.width - 10 && album_size > min_size {
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
  text_y := box.y + (box.height - total_height) / 2

  artist_x := box.x + (box.width - artist_measure.x) / 2
  dash_x := box.x + (box.width - dash_measure.x) / 2
  album_x := box.x + (box.width - album_measure.x) / 2

  rl.DrawRectangleRec(box, rl.Fade(rl.BLACK, 0.7))
  rl.DrawTextEx(font^, cs_artist, [2]f32{artist_x, text_y}, artist_size, spacing, rl.RAYWHITE)
  rl.DrawTextEx(font^, "-", [2]f32{dash_x, text_y + artist_measure.y}, dash_size, spacing, rl.RAYWHITE)
  rl.DrawTextEx(font^, cs_album, [2]f32{album_x, text_y + artist_measure.y + dash_measure.y}, album_size, spacing, rl.RAYWHITE)
}

Direction :: enum{Up, Right, Down, Left}
move_selected :: proc(selected: ^Box, direction: Direction, grid_data: ^Gui_Data) {
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
    albumart_m := make(Albumart_Map)
    defer {
      // FIXME: segfaults
      for _, art in albumart_m {
        rl.UnloadTexture(art)
      }
      delete(albumart_m)
      db.db_free(&db_m)
    }

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

    // rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
    rl.InitWindow(window.width, window.height, window.name)
    font := rl.LoadFontEx("assets/IosevkaNerdFont-Bold.ttf", FONT_SIZE, nil, 17000)

    defer {
      rl.UnloadFont(font)
      rl.CloseWindow()
    }

    rl.SetWindowState(window.control_flags)
    rl.SetTargetFPS(window.fps)

    grid_data := Gui_Data{offset, &uris, &db_m, &albumart_m, &font, false}

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

      if rl.IsKeyPressed(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = true
      }

      if rl.IsKeyReleased(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = false
      }

      for i := 0; i < GRID_ROWS * GRID_COLS; i += 1 {
        uri := grid_data.uris^[i+grid_data.offset]
        tex, ok := grid_data.albumart[uri]
        if !ok {
          album := grid_data.albums[uri]
          // TODO: Fetch album art asynchronously
          img_data, img_ok := mpd.fetch_album_art(album.full_uri, "localhost", 6600)
          defer delete(img_data)
          if img_ok {
            img := rl.LoadImageFromMemory(".jpg", raw_data(img_data), i32(len(img_data)))
            grid_data.albumart[uri] = rl.LoadTextureFromImage(img)
            rl.UnloadImage(img)
          }
        }
      }
      // TODO: Cull album art that isn't visible

      rl.BeginDrawing()

      rl.ClearBackground(rl.RAYWHITE)
      draw_grid(&window, &selected, &grid_data)

      rl.EndDrawing()
    }

}
