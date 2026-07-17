package albumpicker

import     "core:fmt"
import "core:time"
import mpd "mpd"
import rl  "vendor:raylib"
import db "musicdb"
import "core:strings"
import "core:thread"

GRID_ROWS :: 4
GRID_COLS :: 7
FONT_SIZE :: 20
BORDER_THICKNESS :: 4
ART_CACHE_SIZE :: GRID_ROWS * GRID_COLS * 3

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
  albumart_cache: ^Albumart_Cache,
  selected: ^Box,
  font: ^rl.Font,
  render_text: bool,
  sort_reverse : bool,
}
Albumart_Map :: map[string]Albumart_Data
Albumart_Data :: struct {
  texture: rl.Texture,
  status: Albumart_Status,
}
Albumart_Status :: enum {
  UNLOADED,
  LOADED,
  LOADING,
  NONE,
}

Albumart_Task_Data :: struct {
  uri: string,
  full_uri: string,
  img: rl.Image,
  img_present: bool,
}

Albumart_Cache :: struct {
  slots: [ART_CACHE_SIZE]Albumart_Cache_Data,
  count: int,
}
Albumart_Cache_Data :: struct {
  used_at: time.Time,
  uri: string
}

Box :: struct {
  x : i32,
  y : i32,
}

draw_grid :: proc(window: ^Window, grid_data: ^Gui_Data) {
  selected := grid_data.selected
  box_width := f32(window.width) / f32(GRID_COLS)
  box_height := f32(window.height) / f32(GRID_ROWS)

  i := 0

  for row_ix: f32 = 0; row_ix < GRID_ROWS; row_ix += 1 {
    y := box_height * row_ix
    for col_ix: f32 = 0; col_ix < GRID_COLS; col_ix += 1 {
      x := box_width * col_ix
      border_color: rl.Color

      rect := rl.Rectangle{x, y, box_width, box_height}
      rect_inner := rl.Rectangle{x + BORDER_THICKNESS, y + BORDER_THICKNESS, box_width - BORDER_THICKNESS*2, box_height - BORDER_THICKNESS*2}

      if (i + grid_data.offset >= len(grid_data.uris)) {
        rl.DrawRectangleRec(rect_inner, rl.Fade(rl.BLACK, 0.7))
        continue
      }
      uri := grid_data.uris^[i+grid_data.offset]
      album := grid_data.albums^[uri]

      rl.DrawRectangleRec(rect, rl.RAYWHITE)

      art_data, ok := grid_data.albumart[uri]
      if ok && art_data.status == .LOADED {
        draw_box_image_content(&art_data.texture, rect_inner)
        if grid_data.render_text {
          draw_box_text_content(album.artist, album.name, rect_inner, grid_data.font)
        }
      } else if art_data.status == .LOADING {
        rl.DrawRectangleRec(rect_inner, rl.Fade(rl.BLACK, 0.7))
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
move_selected :: proc(direction: Direction, grid_data: ^Gui_Data) {
  selected := grid_data.selected
  new_x := selected.x
  new_y := selected.y
  new_offset := grid_data.offset
  switch direction {
    case .Up:
      if selected.y -1 < 0 {
        if grid_data.offset >= GRID_ROWS + 1{
         new_offset -= GRID_COLS
        }
        break
      }
      new_y -= 1
    case .Down:
      if grid_data.selected.y + 1 >= GRID_ROWS && grid_data.offset + GRID_COLS * GRID_ROWS <= len(grid_data.uris) {
        new_offset += GRID_COLS
        break
      }
      new_y += 1
    case .Left:
      new_x = (selected.x - 1 + GRID_COLS) % GRID_COLS
    case .Right:
      new_x = (selected.x + 1) % GRID_COLS
  }
  if (int(new_y) * GRID_COLS) + int(new_x) + new_offset >= len(grid_data.uris) {
    return
  }
  grid_data.offset = new_offset
  selected.x = new_x
  selected.y = new_y
}

enqueue_album :: proc (conn: ^mpd.MPD_Connection, grid_data: ^Gui_Data) {
  selected := grid_data.selected
  position := (int(selected.y) * GRID_COLS) + int(selected.x) + grid_data.offset
  if position >= len(grid_data.uris) {
    return
  }
  uri := grid_data.uris[position]
  c_uri := strings.clone_to_cstring(uri)
  defer delete(c_uri)

  mpd.mpd_run_clear(conn)
  mpd.mpd_run_add(conn, c_uri)
  mpd.mpd_run_play(conn)
}

sort_order :: proc(grid_data: ^Gui_Data) {
  grid_data.offset = 0
  grid_data.selected.x = 0
  grid_data.selected.y = 0
  if(grid_data.sort_reverse) {
    db.sort_by_artist(grid_data.albums, grid_data.uris^)
    grid_data.sort_reverse = false
  } else {
    db.sort_by_artist_reverse(grid_data.albums, grid_data.uris^)
    grid_data.sort_reverse = true
  }
}

refresh_connection :: proc (conn: ^^mpd.MPD_Connection) -> bool {
    new_conn := mpd.mpd_connection_new(
        "localhost",
        6600,
        15000,
    )

    if new_conn == nil {
        return false
    }
    else if mpd.mpd_connection_get_error(new_conn) != .SUCCESS {
      mpd.mpd_connection_free(new_conn)
      return false
    }

    if conn^ != nil {
        mpd.mpd_connection_free(conn^)
    }

    conn^ = new_conn
    return true
}

main :: proc() {
    conn: ^mpd.MPD_Connection
    conn_success := refresh_connection(&conn)
    if !conn_success {
        return
    }
    defer mpd.mpd_connection_free(conn)
    conn_refresh_time := time.now()
    conn_refresh_interval_ms: f64 = 14000

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

    albumart_m := make(Albumart_Map)
    art_cache: Albumart_Cache
    pool: thread.Pool
    thread.pool_init(&pool, context.allocator, 4)
    thread.pool_start(&pool)
    defer {
      thread.pool_destroy(&pool)
      delete(albumart_m)
    }

    offset := 0
    uris := db.get_uris(&db_m)
    defer delete(uris)

    db.sort_by_artist(&db_m, uris)

    window := Window{"mpd_nowplaying", 1400 * 1.75, 1400, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

    rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
    rl.InitWindow(window.width, window.height, window.name)
    font_data := #load("assets/IosevkaNerdFont-Bold.ttf")
    font := rl.LoadFontFromMemory(
        ".ttf",
        raw_data(font_data),
        i32(len(font_data)),
        FONT_SIZE,
        nil,
        17000,
    )

    defer {
      rl.UnloadFont(font)
      rl.CloseWindow()
    }

    rl.SetWindowState(window.control_flags)
    rl.SetTargetFPS(window.fps)


    selected := Box{0,0}

    grid_data := Gui_Data{
      offset = offset,
      uris = &uris,
      albums = &db_m,
      albumart = &albumart_m,
      albumart_cache = &art_cache,
      selected = &selected,
      font = &font,
      render_text = false,
      sort_reverse = false,
    }

    for !rl.WindowShouldClose() {

      elapsed := time.duration_milliseconds(time.since(conn_refresh_time))
      if elapsed > conn_refresh_interval_ms {
        conn_success = refresh_connection(&conn)
        if !conn_success {
          break
        }
        conn_refresh_time = time.now()
      }

      if rl.IsWindowResized() {
        window.width = rl.GetScreenWidth()
        window.height = rl.GetScreenHeight()
      }
      if rl.IsKeyPressed(rl.KeyboardKey.Q) {
        break
      } else if rl.IsKeyPressed(.K) || rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
        move_selected(Direction.Up, &grid_data)
      } else if rl.IsKeyPressed(.J) || rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
        move_selected(Direction.Down, &grid_data)
      } else if rl.IsKeyPressed(.H) || rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
        move_selected(Direction.Left, &grid_data)
      } else if rl.IsKeyPressed(.L) || rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
        move_selected(Direction.Right, &grid_data)
      } else if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) {
        enqueue_album(conn, &grid_data)
      } else if rl.IsKeyPressed(.TAB) {
        sort_order(&grid_data)
      } else if rl.IsKeyPressed(.R) {
        grid_data.offset = 0
        db.shuffle(grid_data.uris^)
      }

      if rl.IsKeyPressed(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = true
      }

      if rl.IsKeyReleased(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = false
      }

      for i := 0 - GRID_COLS * 2; i < GRID_ROWS * GRID_COLS + (GRID_COLS * 2); i += 1 {
        if (i + grid_data.offset < 0) {
          continue
        }
        if (i + grid_data.offset >= len(grid_data.uris)) {
          break
        }
        uri := grid_data.uris^[i+grid_data.offset]
        art , ok := grid_data.albumart[uri]
        if !ok || art.status == .UNLOADED {
          album := grid_data.albums[uri]

          grid_data.albumart[uri] = Albumart_Data{
            status = .LOADING
          }
          task_data := new(Albumart_Task_Data, context.allocator)
          task_data.uri = strings.clone(uri)
          task_data.full_uri = strings.clone(album.full_uri)
          thread.pool_add_task(&pool, context.allocator, fetch_album_art_handler, task_data)
        }
      }

      for {
        task, got_task := thread.pool_pop_done(&pool)
        if !got_task {
          break
        }
        data := cast(^Albumart_Task_Data)task.data
        art_data := &grid_data.albumart[data.uri]
        status: Albumart_Status
        if data.img_present {
          status = .LOADED
        } else {
          status = .NONE
        }
        art_data^ = Albumart_Data{
           texture = rl.LoadTextureFromImage(data.img),
           status = status
        }
        rl.UnloadImage(data.img)

        // Cache art and unload any textures evicted from the cache
        evicted_uri, any_evicted := cache_put(&grid_data, strings.clone(data.uri))
        delete(data.full_uri)
        delete(data.uri)
        free(data)
        if any_evicted {
          evicted_art := &grid_data.albumart[evicted_uri]
          evicted_art.status = .UNLOADED
          rl.UnloadTexture(evicted_art.texture)
          delete(evicted_uri)
        }
      }

      rl.BeginDrawing()

      rl.ClearBackground(rl.RAYWHITE)
      draw_grid(&window, &grid_data)

      rl.EndDrawing()
    }

    thread.pool_finish(&pool)
    for _, art in albumart_m {
      if art.status == .LOADED {
        rl.UnloadTexture(art.texture)
      }
    }
}

fetch_album_art_handler :: proc(task: thread.Task) {
  data := cast(^Albumart_Task_Data)task.data
  img_data, img_ok := mpd.fetch_album_art(data.full_uri, "localhost", 6600)
  defer delete(img_data)
  img: rl.Image
  if img_ok {
    img = rl.LoadImageFromMemory(".jpg", raw_data(img_data), i32(len(img_data)))
    rl.ImageResize(&img, 300, 300)
  }
  data.img = img
  data.img_present = img_ok
}

cache_put :: proc(grid_data: ^Gui_Data, uri: string) -> (evicted: string, any_evicted: bool) {
  cache := grid_data.albumart_cache
  for i in 0..<cache.count {
    if cache.slots[i].uri == uri {
      cache.slots[i].used_at = time.now()
      return "", false
    }
  }

  if cache.count < ART_CACHE_SIZE {
    cache.slots[cache.count] = Albumart_Cache_Data{
      used_at = time.now(),
      uri = uri,
    }
    cache.count += 1
    return "", false
  }

  oldest_index := 0
  oldest_time := cache.slots[0].used_at

  for i in 1..<ART_CACHE_SIZE {
    visible := img_visible(grid_data, cache.slots[i].uri)
    if time.diff(cache.slots[i].used_at, oldest_time) > 0 && !visible {
      oldest_time = cache.slots[i].used_at
      oldest_index = i
    }
  }

  evicted = strings.clone(cache.slots[oldest_index].uri)
  delete(cache.slots[oldest_index].uri)
  cache.slots[oldest_index] = Albumart_Cache_Data{
    used_at = time.now(),
    uri = uri,
  }

  return evicted, true
}

img_visible :: proc(grid_data: ^Gui_Data, uri: string) -> bool {
  for i in 0..<(GRID_COLS * GRID_ROWS) {
    if uri == grid_data.uris[i+grid_data.offset] {
      return true
    }
  }
  return false
}
