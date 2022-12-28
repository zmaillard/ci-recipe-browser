module Auth0 exposing
    ( AuthenticationState(..)
    , Options
    , defaultOpts
    , mapResult
    , LoggedInUser 
    , UserProfile
    , AuthenticationError
    , AuthenticationResult
    , RawAuthenticationResult
    , initRawAuthResult 
    , decodeRawAuthenticationResult  )

import Json.Decode exposing(Decoder, succeed, string, nullable)
import Json.Decode.Pipeline exposing (required, optional, hardcoded)

type alias LoggedInUser =
    { profile : UserProfile
    , token : Token
    }

type AuthenticationState
    = LoggedIn LoggedInUser
    | LoggedOut

type alias Options =
    { }

type alias UserProfile =
    { emailAddress : String
    , phoneNumber : String
    }


type alias Token = String

type alias AuthenticationError =
    { name : String
    }
type alias AuthenticationResult =
    Result AuthenticationError LoggedInUser

type alias RawAuthenticationResult =
    { err : Maybe AuthenticationError
    , ok : Maybe LoggedInUser
    }

initRawAuthResult : RawAuthenticationResult
initRawAuthResult =
    { err = Maybe.Nothing
    , ok = Maybe.Nothing
    }


-- convert : Json.Encode.Value -> RawAuthenticationResult
-- convert j =
--     let
--         u = Json.Decode.decodeValue decodeRawAuthenticationResult j 
--     in
--     case u of
--         Ok rawAuthResult ->
--             rawAuthResult
--         _ ->
--             { err = (Just { name = "No information was received from the authentication provider" })
--             , ok  = Maybe.Nothing }


mapResult : RawAuthenticationResult -> AuthenticationResult
mapResult result =
    case ( result.err, result.ok ) of
        ( Just msg, _ ) ->
            Err msg

        ( Nothing, Nothing ) ->
            Err { name = "No information was received from the authentication provider" }

        ( Nothing, Just user ) ->
            Ok user


decodeRawAuthenticationResult : Decoder RawAuthenticationResult
decodeRawAuthenticationResult =
    succeed  RawAuthenticationResult
        |> required "err" (nullable decodeError )
        |> required "ok" (nullable decodeLoggedInUser )

decodeLoggedInUser : Decoder LoggedInUser
decodeLoggedInUser =
    succeed LoggedInUser
        |> required "profile" decodeUserProfile
        |> required "token" string

decodeUserProfile : Decoder UserProfile
decodeUserProfile =
    succeed UserProfile
        |> required "emailAddress" string
        |> required "phoneNumber" string

decodeError : Decoder AuthenticationError
decodeError =
    succeed AuthenticationError
        |> required "name" string

defaultOpts : Options
defaultOpts =
    { }
