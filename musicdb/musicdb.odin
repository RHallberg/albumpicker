package musicdb

import mpd "../mpd"
import     "core:strings"
import     "core:slice"
import     "core:math/rand"
import     "core:unicode"
import     "core:unicode/utf8"
import     "core:text/regex"
import     "core:fmt"

Album :: struct {
  name : string,
  name_lower : string,
  artist : string,
  artist_lower : string,
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
      delete(album.name_lower)
      delete(album.artist)
      delete(album.artist_lower)
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
    name_s := strings.clone_from_cstring(album_name)
    name_lower := strings.to_lower(name_s)
    artist_s := strings.clone_from_cstring(artist)
    artist_lower := strings.to_lower(artist_s)

    album := Album{
            name   = name_s,
            name_lower = name_lower,
            artist = artist_s,
            artist_lower = artist_lower,
            full_uri = uri
    }

    value, ok := &db[artist_album]
    if ok {
        value^ = album
    } else {
        db[artist_album] = album
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

sort_by_artist :: proc(db: ^Album_Map, uris: []string) {
  cmp :: proc (i, j: string, data: rawptr) -> slice.Ordering {
    album_data := cast(^Album_Map)data
    album_i := album_data[i]
    album_j := album_data[j]

    if album_i.artist_lower < album_j.artist_lower {
      return .Less
    } else if album_i.artist_lower > album_j.artist_lower {
      return .Greater
    }

    if album_i.name_lower < album_j.name_lower {
      return .Less
    } else if album_i.name_lower > album_j.name_lower {
      return .Greater
    }

    return .Equal

  }

  slice.sort_by_cmp_with_data(uris, cmp, db)
}


sort_by_artist_reverse :: proc(db: ^Album_Map, uris: []string) {
  cmp :: proc (i, j: string, data: rawptr) -> slice.Ordering {
    album_data := cast(^Album_Map)data
    album_i := album_data[i]
    album_j := album_data[j]

    if album_i.artist_lower < album_j.artist_lower {
      return .Greater
    } else if album_i.artist_lower > album_j.artist_lower {
      return .Less
    }

    if album_i.name_lower < album_j.name_lower {
      return .Greater
    } else if album_i.name_lower > album_j.name_lower {
      return .Less
    }

    return .Equal

  }

  slice.sort_by_cmp_with_data(uris, cmp, db)
}

shuffle :: proc(uris: []string) {
  rand.shuffle(uris)
}

filter_by_album_artist :: proc(db: ^Album_Map, uris: []string, query: string) -> []string {
  pattern_string := fmt.aprintf("(^|\\b)%s", query)
  pattern, _err := regex.create(pattern_string, {.Case_Insensitive})
  defer {
    regex.destroy_regex(pattern)
    delete(pattern_string)
  }
  matches := 0
  for uri in uris {
    artist_cap, artist_success := regex.match_and_allocate_capture(pattern, db[uri].artist)
    regex.destroy_capture(artist_cap)
    if artist_success {
      uris[matches] = uri
      matches += 1
      continue
    }
    album_cap, album_success := regex.match_and_allocate_capture(pattern, db[uri].name)
    regex.destroy_capture(album_cap)
    if album_success {
      uris[matches] = uri
      matches += 1
    }
  }
  return uris[:matches]
}
