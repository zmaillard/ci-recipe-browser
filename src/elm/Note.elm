module Note exposing (Note, toNote, fromNote, noteDecoder)

import Json.Decode exposing (Decoder, map, string)

type Note
    = Note String

fromNote : Note -> String
fromNote (Note note) =
    note

toNote : String -> Note
toNote str =
    Note str


noteDecoder : Decoder Note
noteDecoder =
    map Note string