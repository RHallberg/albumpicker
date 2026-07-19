package albumpicker

import     "core:fmt"
import "core:time"
import mpd "mpd"
import rl  "vendor:raylib"
import db "musicdb"
import "core:strings"
import "core:unicode/utf8"
import "core:thread"

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
  search_state: ^Search_State,
  font: ^rl.Font,
  font_large: ^rl.Font,
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

Search_State :: struct {
  search_mode: bool,
  query: [dynamic]rune,
  index: int
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
        rl.DrawRectangleRec(rect_inner, rl.Fade(BOX_BACKGROUND_COLOR, 0.7))
        rl.DrawRectangleLinesEx(rect, BORDER_THICKNESS, BORDER_COLOR)
        continue
      }
      uri := grid_data.uris^[i+grid_data.offset]
      album := grid_data.albums^[uri]

      art_data, ok := grid_data.albumart[uri]
      if ok && art_data.status == .LOADED {
        draw_box_image_content(&art_data.texture, rect_inner)
        if grid_data.render_text {
          draw_box_text_content(album.artist, album.name, rect_inner, grid_data.font)
        }
      } else if art_data.status == .LOADING {
        rl.DrawRectangleRec(rect_inner, rl.Fade(BOX_BACKGROUND_COLOR, 0.7))
      } else {
        draw_box_text_content(album.artist, album.name, rect_inner, grid_data.font)
      }
      if selected.x == i32(col_ix) && selected.y == i32(row_ix) {
        border_color = SELECTED_COLOR
        rl.DrawRectangleRec(rect_inner, rl.Fade(SELECTED_COLOR, 0.35))
      } else {
        border_color = BORDER_COLOR
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

  // Resize font until it fits within box. FIXME: Make less ugly for long album/artist names
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

  rl.DrawRectangleRec(box, rl.Fade(BOX_TEXT_BACKGROUND_COLOR, 0.7))
  rl.DrawTextEx(font^, cs_artist, [2]f32{artist_x, text_y}, artist_size, spacing, FONT_COLOR)
  rl.DrawTextEx(font^, "-", [2]f32{dash_x, text_y + artist_measure.y}, dash_size, spacing, FONT_COLOR)
  rl.DrawTextEx(font^, cs_album, [2]f32{album_x, text_y + artist_measure.y + dash_measure.y}, album_size, spacing, FONT_COLOR)
}

draw_search_box :: proc(window: ^Window, grid_data: ^Gui_Data) {
  search := grid_data.search_state
  font := grid_data.font_large
  search_font_size : f32 = FONT_SIZE * 2
  box_height : f32 = search_font_size + 4
  box_width : f32 = f32(window.width) / 2
  box_y := f32(window.height)/4 - ((box_height + f32(BORDER_THICKNESS))/2)
  box_x := f32(window.width)/2  - ((box_width + f32(BORDER_THICKNESS))/2)
  rect := rl.Rectangle{box_x, box_y, box_width, box_height}
  border_rect := rl.Rectangle{
    box_x - BORDER_THICKNESS,
    box_y - BORDER_THICKNESS,
    box_width + BORDER_THICKNESS,
    box_height + BORDER_THICKNESS
  }
  rl.DrawRectangleRec(rect, BOX_TEXT_BACKGROUND_COLOR)
  rl.DrawRectangleLinesEx(border_rect, BORDER_THICKNESS, BORDER_COLOR)
  prompt : cstring = "SEARCH:"
  prompt_size := rl.MeasureTextEx(font^, prompt, search_font_size, 2.0) + 8
  rl.DrawTextEx(font^, prompt, [2]f32{rect.x+6, rect.y+2}, search_font_size, 2.0, FONT_COLOR)
  if len(search.query) > 0 {
    query_s : cstring = nil
    query_r := search.query[:]
    defer{
      if query_s != nil {
        delete(query_s)
      }
    }
    for i := len(search.query); i >=  0 ; i -= 1 {
      query := utf8.runes_to_string(query_r)
      query_c := strings.clone_to_cstring(query)
      query_size := rl.MeasureTextEx(font^, query_c, search_font_size, 2.0)
      if query_size.x + prompt_size.x <= box_width {
        query_s = strings.clone_to_cstring(query)
        delete(query)
        delete(query_c)
        break
      }
      query_r = search.query[:i]
      delete(query)
      delete(query_c)
    }

    rl.DrawTextEx(
      font^,
      query_s,
      [2]f32{rect.x+prompt_size.x, rect.y+2},
      search_font_size,
      2.0,
      FONT_COLOR
    )
  }
}

handle_navigation :: proc(grid_data: ^Gui_Data) {
  if rl.IsKeyPressed(.K) || rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
    move_selected(Direction.Up, grid_data)
  } else if rl.IsKeyPressed(.J) || rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
    move_selected(Direction.Down, grid_data)
  } else if rl.IsKeyPressed(.H) || rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
    move_selected(Direction.Left, grid_data)
  } else if rl.IsKeyPressed(.L) || rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
    move_selected(Direction.Right, grid_data)
  } else if rl.IsKeyPressed(.TAB) {
    sort_order(grid_data)
  } else if rl.IsKeyPressed(.R) {
    grid_data.offset = 0
    db.shuffle(grid_data.uris^)
  }
}

handle_search :: proc(grid_data: ^Gui_Data) {
  state := grid_data.search_state
  backspace := rl.IsKeyPressed(.BACKSPACE)
  char := rl.GetCharPressed()
  if u8(char) == 0 && !backspace {
    return
  }

  if backspace && state.index > 0 {
    pop(&state.query)
    reset_uris(grid_data)
    // FIXME: Replaying the search is shit but it's quick enough surprisingly
    sub_q := utf8.runes_to_string(state.query[:])
    grid_data.uris^ = db.filter_by_album_artist(grid_data.albums, grid_data.uris^, sub_q)
    delete(sub_q)
    state.index -= 1
    return
  } else if backspace {
    return
  }

  append(&state.query, char)
  query := utf8.runes_to_string(state.query[:])
  defer delete(query)

  grid_data.offset = 0
  grid_data.selected.x = 0
  grid_data.selected.y = 0
  grid_data.uris^ = db.filter_by_album_artist(grid_data.albums, grid_data.uris^, query)
  state.index += 1
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

enqueue_album :: proc (conn: ^mpd.MPD_Connection, grid_data: ^Gui_Data, append_to_queue: bool) {
  selected := grid_data.selected
  position := (int(selected.y) * GRID_COLS) + int(selected.x) + grid_data.offset
  if position >= len(grid_data.uris) {
    return
  }
  uri := grid_data.uris[position]
  c_uri := strings.clone_to_cstring(uri)
  defer delete(c_uri)

  if append_to_queue {
    mpd.mpd_run_add(conn, c_uri)
    return
  }
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
        MPD_HOST,
        MPD_PORT,
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

    // Setup: MPD connection
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

    // Setup: music db
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

    // Setup: The album art cache and pool
    albumart_m := make(Albumart_Map)
    art_cache: Albumart_Cache
    pool: thread.Pool
    thread.pool_init(&pool, context.allocator, 4)
    thread.pool_start(&pool)
    defer {
      thread.pool_destroy(&pool)
      delete(albumart_m)
    }

    // Setup: Initialize the raylib window and context
    window := Window{"albumpicker", 1000, 1000, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

    rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
    rl.InitWindow(window.width, window.height, window.name)
    defer rl.CloseWindow()

    rl.SetWindowState(window.control_flags)
    rl.SetTargetFPS(window.fps)

    // Setup: Initialize the app context
    font_data := #load("assets/IosevkaNerdFont-Bold.ttf")
    font := rl.LoadFontFromMemory(
        ".ttf",
        raw_data(font_data),
        i32(len(font_data)),
        FONT_SIZE,
        nil,
        8900,
    )
    font_large := rl.LoadFontFromMemory(
        ".ttf",
        raw_data(font_data),
        i32(len(font_data)),
        FONT_SIZE * 4,
        nil,
        1000,
    )
    offset := 0
    selected := Box{0,0}
    uris := db.get_uris(&db_m)
    db.sort_by_artist(&db_m, uris)
    search_state := Search_State{
      query = nil,
      index = 0,
      search_mode = false,
    }
    defer {
      delete(uris)
      rl.UnloadFont(font)
      if search_state.query != nil {
        delete(search_state.query)
      }
    }

    // Main graphics-context
    grid_data := Gui_Data{
      offset = offset,
      uris = &uris,
      albums = &db_m,
      albumart = &albumart_m,
      albumart_cache = &art_cache,
      search_state = &search_state,
      selected = &selected,
      font = &font,
      font_large = &font_large,
      render_text = false,
      sort_reverse = false,
    }

    ctrl_held := false

    // Graphics loop
    for {

      // Refresh connection
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

      if !grid_data.search_state.search_mode {
        if rl.IsKeyPressed(rl.KeyboardKey.Q) || rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
          break
        } else if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) {
          append_to_queue := false
          if ctrl_held {
            append_to_queue = true
          }
          enqueue_album(conn, &grid_data, append_to_queue)
        } else if rl.IsKeyPressed(.C) {
          grid_data.search_state.index = 0
          if grid_data.search_state.query != nil {
            delete(grid_data.search_state.query)
            grid_data.search_state.query = make([dynamic]rune)
          }
          reset_uris(&grid_data)
        } else if rl.IsKeyPressed(.F) && ctrl_held {
          if grid_data.search_state.query == nil {
            grid_data.search_state.query = make([dynamic]rune)
          }
          grid_data.search_state.search_mode = true
        }
        handle_navigation(&grid_data)
      } else {
        if(rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.ESCAPE) || (rl.IsKeyPressed(.F) && ctrl_held)) {
          grid_data.search_state.search_mode = false
          if (len(grid_data.uris) == 0) {
            reset_uris(&grid_data)
          }
        } else {
          handle_search(&grid_data)
        }
      }
      if rl.IsKeyPressed(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = true
      }
      if rl.IsKeyReleased(rl.KeyboardKey.LEFT_SHIFT) {
        grid_data.render_text = false
      }

      if rl.IsKeyPressed(CTRL_KEY) {
        ctrl_held = true
      }
      if rl.IsKeyReleased(CTRL_KEY) {
        ctrl_held = false
      }

      // Push image tasks to task pool. Preload 2 rows above and 2 below visible grid
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

      // Fetch finished tasks from thread pool
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
      if(grid_data.search_state.search_mode){
        draw_search_box(&window, &grid_data)
      }

      rl.EndDrawing()
    }

    // Some cleanup on exit
    thread.pool_finish(&pool)
    for _, art in albumart_m {
      if art.status == .LOADED {
        rl.UnloadTexture(art.texture)
      }
    }
}

fetch_album_art_handler :: proc(task: thread.Task) {
  data := cast(^Albumart_Task_Data)task.data
  img_data, img_ok := mpd.fetch_album_art(data.full_uri, MPD_HOST, MPD_PORT)
  defer delete(img_data)
  img: rl.Image
  if img_ok {
    img = rl.LoadImageFromMemory(".jpg", raw_data(img_data), i32(len(img_data)))
    rl.ImageResize(&img, 400, 400)
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

// Helper to check that we do not evict visible images from the cache
img_visible :: proc(grid_data: ^Gui_Data, uri: string) -> bool {
  for i in 0..<(GRID_COLS * GRID_ROWS) {
    if i+grid_data.offset < len(grid_data.uris) && uri == grid_data.uris[i+grid_data.offset] {
      return true
    }
  }
  return false
}

reset_uris :: proc(grid_data: ^Gui_Data) {
  delete(grid_data.uris^)
  grid_data.uris^ = db.get_uris(grid_data.albums)
  grid_data.sort_reverse = true
  sort_order(grid_data)
}
