package mpd

foreign import libmpdclient "system:mpdclient"
import "core:c"
import "core:strings"

MPD_Connection :: struct {}

MPD_Error :: enum int {
    SUCCESS = 0,
}

MPD_Entity :: struct {}
MPD_Entity_Type :: enum {
    UNKNOWN,
    DIRECTORY,
    SONG,
    PLAYLIST,
}

MPD_Tag_Type :: enum {

  MPD_TAG_ARTIST,
  MPD_TAG_ALBUM,
  MPD_TAG_ALBUM_ARTIST,
  MPD_TAG_TITLE,
  MPD_TAG_TRACK,
  MPD_TAG_NAME,
  MPD_TAG_GENRE,
  MPD_TAG_DATE,
  MPD_TAG_COMPOSER,
  MPD_TAG_PERFORMER,
  MPD_TAG_COMMENT,
  MPD_TAG_DISC,

  MPD_TAG_MUSICBRAINZ_ARTISTID,
  MPD_TAG_MUSICBRAINZ_ALBUMID,
  MPD_TAG_MUSICBRAINZ_ALBUMARTISTID,
  MPD_TAG_MUSICBRAINZ_TRACKID,
  MPD_TAG_MUSICBRAINZ_RELEASETRACKID,

  MPD_TAG_ORIGINAL_DATE,

  MPD_TAG_ARTIST_SORT,
  MPD_TAG_ALBUM_ARTIST_SORT,

  MPD_TAG_ALBUM_SORT,
  MPD_TAG_LABEL,
  MPD_TAG_MUSICBRAINZ_WORKID,

  MPD_TAG_GROUPING,
  MPD_TAG_WORK,
  MPD_TAG_CONDUCTOR,

  MPD_TAG_COMPOSER_SORT,
  MPD_TAG_ENSEMBLE,
  MPD_TAG_MOVEMENT,
  MPD_TAG_MOVEMENTNUMBER,
  MPD_TAG_LOCATION,
  MPD_TAG_MOOD,
  MPD_TAG_TITLE_SORT,
  MPD_TAG_MUSICBRAINZ_RELEASEGROUPID,
  MPD_TAG_SHOWMOVEMENT,

  MPD_TAG_COUNT,

  MPD_TAG_UNKNOWN = -1,
}

MPD_Song :: struct {}

foreign libmpdclient {
    mpd_connection_new :: proc(
        host: cstring,
        port: uint,
        timeout_ms: uint,
    ) -> ^MPD_Connection ---

    mpd_connection_get_error :: proc(
        conn: ^MPD_Connection,
    ) -> MPD_Error ---

    mpd_connection_free :: proc(
        conn: ^MPD_Connection,
    ) ---

    mpd_send_list_all :: proc (
      conn: ^MPD_Connection,
      path: cstring
    ) -> bool ---

    mpd_send_list_all_meta :: proc (
      conn: ^MPD_Connection,
      path: cstring
    ) -> bool ---

    mpd_recv_entity :: proc (
      conn: ^MPD_Connection
    ) -> ^MPD_Entity ---

    mpd_entity_get_type :: proc (
      entity: ^MPD_Entity
    ) -> MPD_Entity_Type ---

    mpd_entity_free :: proc (
      entity: ^MPD_Entity
    ) ---

    mpd_entity_get_song :: proc (
      entity: ^MPD_Entity
    ) -> ^MPD_Song ---

    mpd_song_get_tag :: proc (
      song: ^MPD_Song,
      type: MPD_Tag_Type,
      idx: uint
    ) -> cstring ---

    mpd_song_get_uri :: proc (
      song: ^MPD_Song
    ) -> cstring ---

    mpd_song_free :: proc (
      song: ^MPD_Song
    ) ---

    mpd_run_albumart :: proc (
      conn: ^MPD_Connection,
      uri: cstring,
      offset: c.uint,
      buffer: rawptr,
      buffer_size: c.size_t
    ) -> c.int ---

    mpd_run_readpicture :: proc (
      conn: ^MPD_Connection,
      uri: cstring,
      offset: c.uint,
      buffer: rawptr,
      buffer_size: c.size_t
    ) -> c.int ---

    mpd_connection_clear_error :: proc (
      conn: ^MPD_Connection
    ) -> c.bool ---

    mpd_run_clear :: proc (
      conn: ^MPD_Connection
    ) -> c.bool ---

    mpd_run_add :: proc (
      conn: ^MPD_Connection,
      uri: cstring
    ) -> c.bool ---

    mpd_run_play :: proc (
       conn: ^MPD_Connection
    ) -> c.bool ---
}

fetch_album_art :: proc(uri: string, host: cstring, port: uint) -> (img_data: [dynamic]u8, ok: bool) {
  cstr_uri := strings.clone_to_cstring(uri)
  defer delete(cstr_uri)
  conn := mpd_connection_new(
      host,
      port,
      1000
  )
  if conn == nil {
      return
  }
  defer mpd_connection_free(conn)
  chunk_size : c.size_t : 8192
  offset : c.uint = 0
  buffer: [chunk_size]u8
  ok = false

  for {
    size := mpd_run_readpicture(conn, cstr_uri, offset, &buffer, chunk_size)
    if size == -1 {
      mpd_connection_clear_error(conn)
      break
    } else if size == 0 && offset == 0 {
      break
    } else if size == 0 {
      ok = true
      break
    }
    append(&img_data, ..buffer[:size])
    offset += cast(c.uint)size
  }

  if ok {
    return img_data, ok
  }

  delete(img_data)
  img_data = {}
  offset = 0
  for {
    size := mpd_run_albumart(conn, cstr_uri, offset, &buffer, chunk_size)
    if size == -1 {
      mpd_connection_clear_error(conn)
      break
    } else if size == 0 && offset == 0 {
      break
    } else if size == 0 {
      ok = true
      break
    }
    append(&img_data, ..buffer[:size])
    offset += cast(c.uint)size
  }

  return img_data, ok
}
