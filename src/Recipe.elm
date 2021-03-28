module Recipe exposing (Recipe, recipesDecoder, recipeDecoder)
import Json.Decode exposing (Decoder, int, list, string, map4, field)

type alias Recipe = 
  { issue : String
  , year : Int
  , recipe : String
  , category: String
  }

recipesDecoder : Decoder (List Recipe)
recipesDecoder =
  list recipeDecoder
    |> field "value"

recipeDecoder : Decoder Recipe
recipeDecoder =
  map4 Recipe
    (field "issue" string)
    (field "year" int)
    (field "recipe" string)
    (field "category" string)
