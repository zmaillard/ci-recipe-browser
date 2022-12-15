port module Ports exposing 
    (auth0Authorize
    , auth0AuthResult
    , auth0Logout
    , pageLoaded)

import Auth0
import Json.Encode

port auth0Authorize : Auth0.Options -> Cmd msg
port auth0AuthResult : (Json.Encode.Value -> msg) -> Sub msg
port auth0Logout : () -> Cmd msg
port pageLoaded : String -> Cmd msg

