module Recipe exposing (Recipe, recipesDecoder, recipeDecoder, formatDate, formatTitle)
import Json.Decode exposing (Decoder, int, list, string, map7, field)
import Json.Decode exposing (maybe)
import Maybe

type alias Recipe = 
  { issue : Int
  , months : String
  , year : Int
  , mainTitle : Maybe String
  , coverTitle : Maybe String
  , categories : List String
  , page: Int 
  }

formatTitle: Recipe -> String
formatTitle recipe =
  case recipe.mainTitle of
    Just val ->
      val
    Nothing ->
      Maybe.withDefault "" recipe.coverTitle 

formatDate : Recipe -> String
formatDate  recipe = 
  recipe.months ++ " " ++ String.fromInt recipe.year

recipesDecoder : Decoder (List Recipe)
recipesDecoder =
  list recipeDecoder
    |> field "value"

recipeDecoder : Decoder Recipe
recipeDecoder =
  map7 Recipe
    (field "issue" int)
    (field "months" string)
    (field "year" int)
    (maybe (field "mainTitle" string))
    (maybe (field "coverTitle"  string))
    (field "categories" (list string))
    (field "page" int)
