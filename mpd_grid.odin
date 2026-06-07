package mpd_grid

import "core:fmt"
import mpd "mpd"

print_song_info :: proc(entity: ^mpd.MPD_Entity) {
  song := mpd.mpd_entity_get_song(entity)

  artist := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0)
  album  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0)
  title  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0)
  uri    := mpd.mpd_song_get_uri(song)

  fmt.println(artist, album, title, "uri: ", uri)

}

main :: proc() {
    conn := mpd.mpd_connection_new(
        "localhost",
        6600,
        30000,
    )
    defer mpd.mpd_connection_free(conn)

    if conn == nil {
        return
    }

    if mpd.mpd_connection_get_error(conn) != .SUCCESS {
        fmt.println("Connection failed")
    } else {
        fmt.println("Connection successful!")
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
      switch type {
        case mpd.MPD_Entity_Type.UNKNOWN:
          // fmt.println("Entity Unknown")
        case mpd.MPD_Entity_Type.DIRECTORY:
          // fmt.println("Entity Directory")
        case mpd.MPD_Entity_Type.SONG:
          print_song_info(entity)
        case mpd.MPD_Entity_Type.PLAYLIST:
          // fmt.println("Entity Playlist")
      }
    }

}
