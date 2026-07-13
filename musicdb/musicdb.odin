package musicdb

import mpd "../mpd"
import     "core:strings"

Album :: struct {
  name : string,
  artist : string,
  full_uri : string,
}
Album_Map :: map[string]Album

db_init :: proc() -> Album_Map {
  db := make(Album_Map)
  return db
}

db_free :: proc(db: ^Album_Map) {
  for key, album in db {
      delete(key)
      delete(album.name)
      delete(album.artist)
      delete(album.full_uri)
  }
  delete(db^)
}

add_song :: proc(db: ^Album_Map, song: ^mpd.MPD_Song) {
    uri := strings.clone_from_cstring(mpd.mpd_song_get_uri(song))

    last := strings.last_index(uri, "/")
    if last == -1 {
        return
    }

    artist_album := strings.clone(uri[:last])

    artist := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0)
    album_name := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0)

    value, ok := &db[artist_album]
    if ok {
        value^ = Album{
            name   = strings.clone_from_cstring(album_name),
            artist = strings.clone_from_cstring(artist),
            full_uri = uri
        }
    } else {
        db[artist_album] = Album{
            name   = strings.clone_from_cstring(album_name),
            artist = strings.clone_from_cstring(artist),
            full_uri = uri
        }
    }
}

get_uris :: proc(db: ^Album_Map) -> []string {
  keys := make([]string, len(db))

  i := 0
  for key in db {
      keys[i] = key
      i += 1
  }
  return keys
}
