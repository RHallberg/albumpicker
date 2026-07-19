package albumpicker
import rl  "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"

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

    // Truncate query if too long
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
