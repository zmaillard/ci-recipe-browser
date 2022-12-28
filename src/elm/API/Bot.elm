module API.Bot exposing (..)
import RemoteData
import Http
import Json.Decode exposing (Decoder)
import Auth0 exposing (UserProfile)
import Auth0 exposing (LoggedInUser)
import Json.Encode as Encode
import Json.Decode exposing (int, succeed, list, string, map)
import Json.Decode.Pipeline exposing (required)
import Recipe exposing (Recipe)
import Note exposing (Note, fromNote, noteDecoder)

type BotUrl =
    BotUrl String

type alias FavoriteResult =
    { recipeId : Int
    }
type alias NoteRecipeResult  =
    { recipeId : Int
    , notes : List NoteResult
    }

type alias NoteResult =
    { note : Note
    , email : String
    }
getNote : BotUrl -> LoggedInUser -> Recipe -> (RemoteData.WebData NoteRecipeResult -> msg) -> Cmd msg
getNote (BotUrl url) user recipe res =
    Http.request
        { url = url ++ "/GetNote"
        , method = "POST"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ user.token)
            ]
        , body = buildUpdateFavoritePut user.profile recipe
        , expect = Http.expectJson (RemoteData.fromResult >> res) noteRecipeDecoder 
        , timeout = Maybe.Nothing
        , tracker = Maybe.Nothing
        }
updateFavorites : BotUrl -> LoggedInUser -> Recipe -> (RemoteData.WebData (List FavoriteResult) -> msg) -> Cmd msg
updateFavorites (BotUrl url) user recipe res =
    Http.request
        { url = url ++ "/UpdateFavorite"
        , method = "PUT"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ user.token)
            ]
        , body = buildUpdateFavoritePut user.profile recipe
        , expect = Http.expectJson (RemoteData.fromResult >> res) favroitesDecoder 
        , timeout = Maybe.Nothing
        , tracker = Maybe.Nothing
        }
buildUpdateFavoritePut : UserProfile -> Recipe ->  Http.Body
buildUpdateFavoritePut  userProfile recipe =
    Encode.object
        [ ( "email", Encode.string userProfile.emailAddress )
        , ( "phoneNumber", Encode.string userProfile.emailAddress )
        , ( "recipeId", Encode.int recipe.recipeId )
        ]
        |> Http.jsonBody

getFavorites : BotUrl -> LoggedInUser -> (RemoteData.WebData (List FavoriteResult) -> msg) -> Cmd msg
getFavorites (BotUrl url) user res =
    Http.request
        { url = url ++ "/AllFavorites"
        , method = "POST"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ user.token)
            ]
        , body = buildGetFavoritePost user.profile
        , expect = Http.expectJson (RemoteData.fromResult >> res) favroitesDecoder 
        , timeout = Maybe.Nothing
        , tracker = Maybe.Nothing
        }

buildGetFavoritePost : UserProfile -> Http.Body
buildGetFavoritePost  userProfile =
    Encode.object
        [ ( "email", Encode.string userProfile.emailAddress )
        , ( "phoneNumber", Encode.string userProfile.emailAddress )
        ]
        |> Http.jsonBody
updateNotes : BotUrl -> LoggedInUser -> Recipe -> Note -> (RemoteData.WebData NoteRecipeResult -> msg) -> Cmd msg
updateNotes  (BotUrl url) user recipe note res =
    Http.request
        { url = url ++ "/UpdateNote"
        , method = "POST"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ user.token)
            ]
        , body = buildUpdateNotePost user.profile recipe note
        , expect = Http.expectJson (RemoteData.fromResult >> res) noteRecipeDecoder 
        , timeout = Maybe.Nothing
        , tracker = Maybe.Nothing
        }


buildUpdateNotePost : UserProfile -> Recipe -> Note -> Http.Body
buildUpdateNotePost  userProfile recipe  note =
    Encode.object
        [ ( "email", Encode.string userProfile.emailAddress )
        , ( "phoneNumber", Encode.string userProfile.emailAddress )
        , ( "recipeId", Encode.int recipe.recipeId )
        , ( "note", Encode.string (note |> fromNote) )
        ]
        |> Http.jsonBody

favroitesDecoder : Decoder (List FavoriteResult)
favroitesDecoder =
    Json.Decode.list favoriteDecoder

favoriteDecoder : Decoder FavoriteResult
favoriteDecoder =
    succeed FavoriteResult
        |> required "recipeId" int  
    

noteRecipeDecoder  : Decoder NoteRecipeResult
noteRecipeDecoder =
    succeed NoteRecipeResult
        |> required "recipeId" int
        |> required "notes" (list noteResultDecoder )
    
noteResultDecoder : Decoder NoteResult
noteResultDecoder =
    succeed NoteResult
        |> required "note" noteDecoder
        |> required "userName" string

botUrlDecoder : Decoder BotUrl
botUrlDecoder =
    map BotUrl string