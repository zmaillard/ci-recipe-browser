module Favorite exposing (Favorite, Favorites, fromFavorite, toFavorite)

type Favorite
    = Favorite Int

type alias Favorites = List Favorite

fromFavorite : Favorite -> Int
fromFavorite (Favorite f) =
    f

toFavorite : Int -> Favorite
toFavorite f =
    Favorite f