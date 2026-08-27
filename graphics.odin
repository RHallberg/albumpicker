package albumpicker
import rl  "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"

draw_grid :: proc(window: ^Window, grid_data: ^Gui_Data) {
  selected := grid_data.selected
  box_width := f32(window.width) / f32(grid_data.cols)
  box_height := f32(window.height) / f32(grid_data.rows)

  i := 0

  for row_ix: f32 = 0; row_ix < f32(grid_data.rows); row_ix += 1 {
    y := box_height * row_ix
    for col_ix: f32 = 0; col_ix < f32(grid_data.cols); col_ix += 1 {
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

// Greedily breaks text into lines that each fit within max_width.
// Caller owns the returned lines and array: delete each line, then the array itself.
wrap_text :: proc(font: ^rl.Font, text: string, font_size: f32, spacing: f32, max_width: f32) -> [dynamic]string {
  lines := make([dynamic]string)
  words := strings.split(text, " ")
  defer delete(words)

  line_start := 0
  for i in 0..<len(words) {
    candidate := strings.join(words[line_start:i+1], " ")
    cs := strings.clone_to_cstring(candidate)
    measure := rl.MeasureTextEx(font^, cs, font_size, spacing)
    delete(cs)
    delete(candidate)

    if measure.x > max_width && i > line_start {
      append(&lines, strings.join(words[line_start:i], " "))
      line_start = i
    }
  }

  if line_start < len(words) {
    append(&lines, strings.join(words[line_start:], " "))
  }

  return lines
}

draw_box_text_content :: proc(artist: string, album_name: string, box: rl.Rectangle, font: ^rl.Font) {
  trimmed_artist := strings.trim(artist, " \t\n\r")
  trimmed_album := strings.trim(album_name, " \t\n\r")

  spacing : f32 = 2.0
  font_size := f32(FONT_SIZE)
  max_width := box.width - TEXT_PADDING * 2

  artist_lines := wrap_text(font, trimmed_artist, font_size, spacing, max_width)
  album_lines := wrap_text(font, trimmed_album, font_size, spacing, max_width)
  defer {
    for line in artist_lines do delete(line)
    delete(artist_lines)
    for line in album_lines do delete(line)
    delete(album_lines)
  }

  dash_measure := rl.MeasureTextEx(font^, "-", font_size, spacing)
  line_height := dash_measure.y
  line_gap : f32 = 2.0

  total_lines := len(artist_lines) + 1 + len(album_lines)
  total_height := f32(total_lines) * line_height + f32(total_lines - 1) * line_gap

  rl.DrawRectangleRec(box, rl.Fade(BOX_TEXT_BACKGROUND_COLOR, 0.7))

  text_y := box.y + (box.height - total_height) / 2

  for line in artist_lines {
    cs := strings.clone_to_cstring(line)
    defer delete(cs)
    measure := rl.MeasureTextEx(font^, cs, font_size, spacing)
    x := box.x + (box.width - measure.x) / 2
    rl.DrawTextEx(font^, cs, [2]f32{x, text_y}, font_size, spacing, FONT_COLOR)
    text_y += line_height + line_gap
  }

  dash_x := box.x + (box.width - dash_measure.x) / 2
  rl.DrawTextEx(font^, "-", [2]f32{dash_x, text_y}, font_size, spacing, FONT_COLOR)
  text_y += line_height + line_gap

  for line in album_lines {
    cs := strings.clone_to_cstring(line)
    defer delete(cs)
    measure := rl.MeasureTextEx(font^, cs, font_size, spacing)
    x := box.x + (box.width - measure.x) / 2
    rl.DrawTextEx(font^, cs, [2]f32{x, text_y}, font_size, spacing, FONT_COLOR)
    text_y += line_height + line_gap
  }
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
