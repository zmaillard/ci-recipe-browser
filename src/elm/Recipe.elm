module Recipe exposing (Recipe, recipesDecoder, recipeDecoder)
import Json.Decode exposing (Decoder, int, list, string, map6, field)

type alias Recipe = 
  { issue : String
  , year : Int
  , recipe : String
  , category: String
  , page: Int 
  , month : List String
  }

recipesDecoder : Decoder (List Recipe)
recipesDecoder =
  list recipeDecoder
    |> field "value"

recipeDecoder : Decoder Recipe
recipeDecoder =
  map6 Recipe
    (field "issue" string)
    (field "year" int)
    (field "recipe" string)
    (field "category" string)
    (field "page" int)
    (field "months" (list string))
