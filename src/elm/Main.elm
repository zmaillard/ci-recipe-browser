module Main exposing (init, main)

import API.Bot exposing (BotUrl, FavoriteResult, NoteRecipeResult, getFavorites, getNote, updateFavorites)
import Auth0
import Authentication
import Browser
import Browser.Events exposing (onKeyDown)
import Browser.Navigation as Nav
import Favorite exposing (Favorites, toFavorite)
import Flags exposing (Flags)
import FontAwesome as Icon exposing (Icon)
import FontAwesome.Solid as Icon
import FontAwesome.Styles as Icon
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Json.Decode exposing (Decoder, Error(..), field, int, map2, map3, string)
import Note exposing (fromNote)
import Ports exposing (auth0AuthResult, auth0Authorize, auth0Logout, pageLoaded)
import Recipe exposing (Recipe, formatDate, formatTitle, recipesDecoder)
import RemoteData exposing (RemoteData(..), WebData)
import Url
import Url.Parser exposing ((<?>))
import Url.Parser.Query
import Views.NoteView as NoteView


type Route
    = DefaultUrl
    | SearchUrl (Maybe String)


type alias YearFacet =
    { year : Int
    , count : Int
    }


type alias CategoryFacet =
    { category : String
    , count : Int
    }


type alias IndexResult =
    { yearFacet : List YearFacet
    , categoryFacet : List CategoryFacet
    , recipes : List Recipe
    }


type alias Model =
    { results : WebData IndexResult
    , selectedYearFacets : List String
    , selectedCategoryFacets : List String
    , searchTerm : String
    , searchServiceUrl : String
    , searchServiceApiKey : String
    , route : Maybe Route
    , navKey : Nav.Key
    , authModel : Authentication.Model
    , noteModel : NoteView.Model
    , favorites : Favorites
    , flags : Flags
    }


type Msg
    = SendHttpRequest
    | RemoveFacet String
    | RecipesReceived (WebData IndexResult)
    | CategoryFacetChanged String Bool
    | YearFacetChanged String Bool
    | SearchTermChanged String
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | AuthenticationMsg Authentication.Msg
    | NoteMsg NoteView.Msg
    | LoginRequest
    | LogoutRequest
    | FavoriteChange Recipe
    | GotFavorites (WebData (List FavoriteResult))
    | ShowNote Recipe


urlParser : Url.Parser.Parser (Route -> a) a
urlParser =
    Url.Parser.oneOf
        [ Url.Parser.map DefaultUrl <| Url.Parser.top
        , Url.Parser.map SearchUrl <|
            Url.Parser.s "search"
                <?> Url.Parser.Query.string "q"
        ]


initSearchTerm : Maybe Route -> String
initSearchTerm route =
    case route of
        Just searchUrl ->
            case searchUrl of
                SearchUrl search ->
                    Maybe.withDefault "*" search

                _ ->
                    "*"

        _ ->
            "*"


init : Json.Decode.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init rawFlags url navKey =
    let
        fixFlag =
            Json.Decode.decodeValue Flags.decodeFlags rawFlags

        flags =
            case fixFlag of
                Ok f ->
                    f

                Err _ ->
                    Flags.initialFlags

        initRoute =
            Url.Parser.parse urlParser url

        initSearch =
            initSearchTerm initRoute

        initUser =
            flags.initialUser |> Auth0.mapResult

        user =
            case initUser of
                Ok u ->
                    Just u

                Err _ ->
                    Maybe.Nothing

        authModel =
            Authentication.init auth0Authorize auth0Logout user
    in
    ( { results = RemoteData.Loading
      , selectedYearFacets = []
      , selectedCategoryFacets = []
      , searchTerm = initSearch
      , searchServiceUrl = flags.searchServiceUrl
      , searchServiceApiKey = flags.searchApiKey
      , route = initRoute
      , navKey = navKey
      , authModel = authModel
      , noteModel = NoteView.init authModel.state flags.botUrl
      , favorites = []
      , flags = flags
      }
    , Cmd.batch [ pageLoaded "", loadFavorites flags.botUrl user, fetchRecipes [] [] initSearch flags.searchServiceUrl flags.searchApiKey ]
    )


loadFavorites : BotUrl -> Maybe Auth0.LoggedInUser -> Cmd Msg
loadFavorites url user =
    case user of
        Just u ->
            getFavorites url u GotFavorites

        Nothing ->
            Cmd.none


toggleFavorite : BotUrl -> Recipe -> Auth0.LoggedInUser -> Cmd Msg
toggleFavorite url recipe user =
    updateFavorites url user recipe GotFavorites


fetchRecipes : List String -> List String -> String -> String -> String -> Cmd Msg
fetchRecipes yearFacets categoryFacets searchTerm url apiKey =
    Http.get
        { url = buildSearchUrl url apiKey yearFacets categoryFacets searchTerm
        , expect =
            indexDecoder
                |> Http.expectJson (RemoteData.fromResult >> RecipesReceived)
        }


buildFilters : List String -> List String -> String
buildFilters yearFacets categoryFacets =
    let
        yearFacet =
            String.join " or " (List.map (\s -> "year eq " ++ s) yearFacets)

        categoryFacet =
            String.join " or " (List.map (\s -> "categories/any(c: c eq '" ++ s ++ "')") categoryFacets)
    in
    if String.isEmpty yearFacet && String.isEmpty categoryFacet then
        ""

    else if String.isEmpty yearFacet then
        "&$filter=" ++ categoryFacet

    else if String.isEmpty categoryFacet then
        "&$filter=" ++ yearFacet

    else
        "&$filter=" ++ categoryFacet ++ " and " ++ yearFacet


buildSearchUrl : String -> String -> List String -> List String -> String -> String
buildSearchUrl url apiKey yearFacets categoryFacets searchTerm =
    url ++ "/docs?search=" ++ searchTerm ++ buildFilters yearFacets categoryFacets ++ "&api-version=2020-06-30-Preview&facet=categories&facet=year&api-key=" ++ apiKey


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShowNote recipe ->
            ( model, Cmd.none )

        FavoriteChange recipe ->
            case model.authModel.state of
                Auth0.LoggedIn user ->
                    ( model, toggleFavorite model.flags.botUrl recipe user )

                _ ->
                    ( model, Cmd.none )

        GotFavorites favorites ->
            case favorites of
                Success data ->
                    ( { model | favorites = List.map (\s -> toFavorite s.recipeId) data }, Cmd.none )

                _ ->
                    ( { model | favorites = [] }, Cmd.none )

        AuthenticationMsg authMsg ->
            let
                ( authModel, cmd ) =
                    Authentication.update authMsg model.authModel
            in
            ( { model | authModel = authModel }, Cmd.map AuthenticationMsg cmd )

        NoteMsg noteViewMsg ->
            let
                ( noteModel, cmd ) =
                    NoteView.update noteViewMsg model.noteModel
            in
            ( { model | noteModel = noteModel }, Cmd.map NoteMsg cmd )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navKey (Url.toString url) )

                Browser.External url ->
                    ( model, Nav.load url )

        UrlChanged url ->
            ( { model | route = Url.Parser.parse urlParser url }, Cmd.none )

        LogoutRequest ->
            let
                authModel =
                    model.authModel

                newAuthModel =
                    { authModel | state = Auth0.LoggedOut }
            in
            ( { model | authModel = newAuthModel }, auth0Logout () )

        LoginRequest ->
            ( { model | results = RemoteData.Loading }, auth0Authorize {} )

        SendHttpRequest ->
            ( { model | results = RemoteData.Loading }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm model.searchServiceUrl model.searchServiceApiKey )

        RecipesReceived response ->
            ( { model | results = response }, Cmd.none )

        SearchTermChanged searchTerm ->
            ( { model | searchTerm = searchTerm }, Cmd.none )

        YearFacetChanged facet checked ->
            let
                updatedYearFacets =
                    if checked then
                        model.selectedYearFacets ++ [ facet ]

                    else
                        List.filter (\s -> s /= facet) model.selectedYearFacets
            in
            ( { model | selectedYearFacets = updatedYearFacets }, fetchRecipes updatedYearFacets model.selectedCategoryFacets model.searchTerm model.searchServiceUrl model.searchServiceApiKey )

        CategoryFacetChanged facet checked ->
            let
                updatedCategoryFacets =
                    if checked then
                        model.selectedCategoryFacets ++ [ facet ]

                    else
                        List.filter (\s -> s /= facet) model.selectedCategoryFacets
            in
            ( { model | selectedCategoryFacets = updatedCategoryFacets }, fetchRecipes model.selectedYearFacets updatedCategoryFacets model.searchTerm model.searchServiceUrl model.searchServiceApiKey )

        RemoveFacet facet ->
            let
                updatedCategoryFacets =
                    List.filter (\s -> s /= facet) model.selectedCategoryFacets

                updatedYearFacets =
                    List.filter (\s -> s /= facet) model.selectedYearFacets
            in
            ( { model
                | selectedYearFacets = updatedYearFacets
                , selectedCategoryFacets = updatedCategoryFacets
              }
            , fetchRecipes updatedYearFacets updatedCategoryFacets model.searchTerm model.searchServiceUrl model.searchServiceApiKey
            )


view : Model -> Browser.Document Msg
view model =
    { title = "Recipe Search"
    , body =
        [ div []
            [ viewLogin model
            , viewSearchBox
            , viewChips model
            , viewContents model
            , NoteView.view model.noteModel |> Html.map NoteMsg
            ]
        ]
    }


viewLogin : Model -> Html Msg
viewLogin model =
    let
        display =
            case model.authModel.state of
                Auth0.LoggedIn user ->
                    viewHasLoggedInUser model user

                Auth0.LoggedOut ->
                    viewIsLoggedOut model
    in
    div [ class "column is-4 is-offset-6" ]
        [ div [ class "block" ]
            [ display ]
        ]


viewIsLoggedOut : Model -> Html Msg
viewIsLoggedOut model =
    button [ class "button is-text", onClick LoginRequest ]
        [ text "[Login]"
        ]


viewHasLoggedInUser : Model -> Auth0.LoggedInUser -> Html Msg
viewHasLoggedInUser model user =
    button [ class "button is-text", onClick LogoutRequest ]
        [ text ("Logout " ++ user.profile.emailAddress)
        ]


chip : String -> Html Msg
chip facet =
    div [ class "control" ]
        [ div [ class "tags has-addons" ]
            [ span [ class "tag" ] [ text facet ]
            , a [ class "tag is-delete", onClick (RemoveFacet facet) ] []
            ]
        ]


viewChips : Model -> Html Msg
viewChips model =
    let
        chips =
            List.concat [ model.selectedYearFacets, model.selectedCategoryFacets ]
    in
    div [ class "container" ]
        [ div [ class "column is-8 is-offset-2" ]
            [ div [ class "field is-grouped is-grouped-multiline" ]
                (List.map (\k -> chip k) chips)
            ]
        ]


viewContents : Model -> Html Msg
viewContents model =
    div [ class "container" ]
        [ div [ class "columns" ]
            [ div [ class "column is-9" ]
                [ viewRecipesOrError model ]
            , div [ class "column is-3" ]
                [ viewFacetsOrError model ]
            ]
        ]


viewSearchBox : Html Msg
viewSearchBox =
    div [ class "container has-text-centered" ]
        [ div [ class "column is-6 is-offset-3" ]
            [ div [ class "box" ]
                [ div [ class "field is-grouped" ]
                    [ p [ class "control is-expanded" ]
                        [ input [ type_ "text", placeholder "Search For Recipes", class "input", onInput SearchTermChanged ]
                            []
                        ]
                    , p [ class "control" ]
                        [ button [ class "button is-info", onClick SendHttpRequest ]
                            [ text "Search" ]
                        ]
                    ]
                ]
            ]
        ]


viewRecipes : Model -> List Recipe -> Html Msg
viewRecipes model recipes =
    div []
        [ table [ class "table is-hoverable is-narrow" ]
            (viewTableHeader model :: List.map (\r -> viewRecipe model r) recipes)
        ]


viewTableHeader : Model -> Html Msg
viewTableHeader model =
    let
        favHeader =
            if Authentication.isLoggedIn model.authModel then
                th [] []

            else
                text ""
    in
    thead []
        [ tr []
            [ favHeader
            , th []
                [ text "Issue" ]
            , th []
                [ text "Date" ]
            , th []
                [ text "Recipe Name" ]
            , th []
                [ text "Page" ]
            , th []
                [ text "Category" ]
            , th []
                [ text "Actions" ]
            ]
        ]


viewFavorite : Favorites -> Recipe -> Html Msg
viewFavorite favs recipe =
    case List.filter (\f -> recipe.recipeId == Favorite.fromFavorite f) favs |> List.length of
        1 ->
            span [ class "icon" ]
                [ i []
                    [ Icon.star |> Icon.view ]
                ]

        _ ->
            text ""


viewNote : Recipe -> Html Msg
viewNote recipe =
    if List.isEmpty recipe.notes |> not then
        button [ class "button is-small" ]
            [ span [ class "icon" ]
                [ i []
                    [ Icon.comments |> Icon.view ]
                ]
            ]

    else
        text ""


viewRecipe : Model -> Recipe -> Html Msg
viewRecipe model recipe =
    let
        favHeader =
            if Authentication.isLoggedIn model.authModel then
                td [] [ viewFavorite model.favorites recipe, viewNote recipe ]

            else
                text ""
    in
    tr []
        [ favHeader
        , td []
            [ text (String.fromInt recipe.issue) ]
        , td []
            [ text (formatDate recipe) ]
        , td []
            [ text (formatTitle recipe) ]
        , td []
            [ text (String.fromInt recipe.page) ]
        , td []
            [ text (String.join ", " recipe.categories) ]
        , td []
            [ viewFavoriteButton model.favorites recipe
            , text "|"
            , NoteView.viewNoteButton recipe |> Html.map NoteMsg
            ]
        ]


viewFavoriteButton : Favorites -> Recipe -> Html Msg
viewFavoriteButton favs recipe =
    let
        textBlock =
            if isFavorite favs recipe then
                "Unfavorite"

            else
                "Favorite"
    in
    button [ class "button is-small is-text", onClick (FavoriteChange recipe) ]
        [ text textBlock
        ]


isFavorite : Favorites -> Recipe -> Bool
isFavorite favs recipe =
    let
        count =
            List.filter (\f -> recipe.recipeId == Favorite.fromFavorite f) favs |> List.length
    in
    count == 1


viewCategoryFacet : List String -> CategoryFacet -> Html Msg
viewCategoryFacet selected facet =
    let
        isChecked =
            not (List.isEmpty (List.filter (\s -> s == facet.category) selected))
    in
    label [ class "panel-block" ]
        [ input [ type_ "checkbox", checked isChecked, onCheck (CategoryFacetChanged facet.category) ] []
        , text (facet.category ++ " (" ++ String.fromInt facet.count ++ ")")
        ]


viewYearFacet : List String -> YearFacet -> Html Msg
viewYearFacet selected facet =
    let
        isChecked =
            not (List.isEmpty (List.filter (\s -> s == String.fromInt facet.year) selected))

        -- isChecked = True
    in
    label [ class "panel-block" ]
        [ input [ type_ "checkbox", checked isChecked, onCheck (YearFacetChanged (String.fromInt facet.year)) ] []
        , text (String.fromInt facet.year ++ " (" ++ String.fromInt facet.count ++ ")")
        ]


viewFacets : List CategoryFacet -> List YearFacet -> List String -> List String -> Html Msg
viewFacets categoryFacets yearFacets selectedCategoryFacets selectedYearFacets =
    let
        viewCatFacetWithSelect =
            viewCategoryFacet selectedCategoryFacets

        viewYearFacetWithSelect =
            viewYearFacet selectedYearFacets
    in
    div []
        [ nav [ class "panel" ]
            (panelHeading "Filter By Category"
                :: List.map
                    viewCatFacetWithSelect
                    categoryFacets
            )
        , nav [ class "panel" ]
            (panelHeading "Filter By Year"
                :: List.map viewYearFacetWithSelect yearFacets
            )
        ]


panelHeading : String -> Html Msg
panelHeading title =
    p [ class "panel-heading" ]
        [ text title
        ]


viewFacetsOrError : Model -> Html Msg
viewFacetsOrError model =
    case model.results of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            h3 [] [ text "Loading..." ]

        RemoteData.Success results ->
            viewFacets results.categoryFacet results.yearFacet model.selectedCategoryFacets model.selectedYearFacets

        RemoteData.Failure httpError ->
            viewError (buildErrorMessage httpError)


viewRecipesOrError : Model -> Html Msg
viewRecipesOrError model =
    case model.results of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            h3 [] [ text "Loading..." ]

        RemoteData.Success results ->
            viewRecipes model results.recipes

        RemoteData.Failure httpError ->
            viewError (buildErrorMessage httpError)


viewError : String -> Html Msg
viewError errorMessage =
    let
        errorHeading =
            "Couldn't fetch data at this time."
    in
    div []
        [ h3 [] [ text errorHeading ]
        , text ("Error: " ++ errorMessage)
        ]


buildErrorMessage : Http.Error -> String
buildErrorMessage httpError =
    case httpError of
        Http.BadUrl message ->
            message

        Http.Timeout ->
            "Server is taking too long to respond.  Please try again later."

        Http.NetworkError ->
            "Unable to reach server."

        Http.BadStatus statusCode ->
            "Request failed with status code: " ++ String.fromInt statusCode

        Http.BadBody message ->
            message


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


yearFacetDecoder : Decoder (List YearFacet)
yearFacetDecoder =
    field "@search.facets"
        (field "year"
            (Json.Decode.list
                (map2 YearFacet
                    (field "value" int)
                    (field "count" int)
                )
            )
        )


categoryFacetDecoder : Decoder (List CategoryFacet)
categoryFacetDecoder =
    field "@search.facets"
        (field "categories"
            (Json.Decode.list
                (map2 CategoryFacet
                    (field "value" string)
                    (field "count" int)
                )
            )
        )


indexDecoder : Decoder IndexResult
indexDecoder =
    map3 IndexResult
        yearFacetDecoder
        categoryFacetDecoder
        recipesDecoder


subscriptions : Model -> Sub Msg
subscriptions model =
    auth0AuthResult (Authentication.handleAuthResult >> AuthenticationMsg)
