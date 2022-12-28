module Flags exposing(Flags, decodeFlags, initialFlags)

import Json.Decode.Pipeline exposing (required)
import Json.Decode exposing (succeed, Decoder, string)
import API.Bot exposing(BotUrl(..))
import Auth0 exposing (decodeRawAuthenticationResult, RawAuthenticationResult)
import API.Bot exposing (botUrlDecoder)
import Auth0 exposing (initRawAuthResult)

type alias Flags =
    { searchServiceUrl : String
    , searchApiKey : String
    , initialUser : RawAuthenticationResult
    , botUrl : BotUrl
    }

decodeFlags : Decoder Flags
decodeFlags =
    succeed Flags
        |> required "searchServiceUrl" string
        |> required "searchApiKey" string
        |> required "initialUser" decodeRawAuthenticationResult 
        |> required "botUrl" botUrlDecoder
    
initialFlags : Flags
initialFlags =
    { searchServiceUrl = ""
    , searchApiKey = ""
    , initialUser = initRawAuthResult
    , botUrl = BotUrl ""
    }
    