module Recipe exposing (Recipe, RecipeNotes, formatDate, formatTitle, recipeDecoder, recipesDecoder)

import Json.Decode exposing (Decoder, field, int, list, map, maybe, string, succeed)
import Json.Decode.Pipeline exposing (required)
import Maybe
import Note exposing (Note, noteDecoder)
import Json.Decode exposing (nullable)
import Json.Decode.Pipeline exposing (optional)


type alias Recipe =
    { issue : Int
    , months : String
    , year : Int
    , mainTitle : Maybe String
    , coverTitle : Maybe String
    , categories : List String
    , page : Int
    , recipeId : Int
    , notes : List RecipeNotes
    }


type alias RecipeNotes =
    { noteDetails : Note
    , user : String
    }


formatTitle : Recipe -> String
formatTitle recipe =
    case recipe.mainTitle of
        Just val ->
            val

        Nothing ->
            Maybe.withDefault "" recipe.coverTitle


formatDate : Recipe -> String
formatDate recipe =
    recipe.months ++ " " ++ String.fromInt recipe.year


recipesDecoder : Decoder (List Recipe)
recipesDecoder =
    list recipeDecoder
        |> field "value"


recipeDecoder : Decoder Recipe
recipeDecoder =
    succeed Recipe
      |> required "issue" int
      |> required "months" string
      |> required "year" int
      |> required "mainTitle" (nullable string)
      |> required "coverTitle" (nullable string)
      |> required "categories" (list string)
      |> required "page" int
      |> required "recipeId" (string |> Json.Decode.andThen stringToIntDecoder)
      |> optional "notes" (list recipeNoteDecoder) []


recipeNoteDecoder : Decoder RecipeNotes
recipeNoteDecoder =
    succeed RecipeNotes
        |> required "noteDetails" noteDecoder
        |> required "user" string


stringToIntDecoder : String -> Decoder Int
stringToIntDecoder s =
    case String.toInt s of
        Just value ->
            Json.Decode.succeed value

        Nothing ->
            Json.Decode.fail "Invalid integer"
