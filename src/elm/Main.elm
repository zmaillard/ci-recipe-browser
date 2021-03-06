module Main exposing (init, main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Json.Decode exposing (Decoder, Error(..), field, int, map2, map3, string)
import Recipe exposing (Recipe, formatDate, formatTitle, recipesDecoder)
import RemoteData exposing (WebData)
import Url
import Url.Parser exposing((<?>))
import Url.Parser.Query

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

urlParser : Url.Parser.Parser (Route -> a) a
urlParser = 
  Url.Parser.oneOf
      [ Url.Parser.map DefaultUrl <| Url.Parser.top
      ,  Url.Parser.map SearchUrl <| Url.Parser.s "search" 
           <?>  Url.Parser.Query.string "q"
      ]

initSearchTerm: Maybe Route -> String
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

init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        initRoute = Url.Parser.parse urlParser url 
        initSearch = initSearchTerm  initRoute 
        
          
    in
    
    ( { results = RemoteData.Loading
      , selectedYearFacets = []
      , selectedCategoryFacets = []
      , searchTerm = initSearch
      , searchServiceUrl = flags.searchServiceUrl
      , searchServiceApiKey = flags.searchApiKey
      , route = initRoute
      , navKey = navKey
      }
    , fetchRecipes [] [] initSearch flags.searchServiceUrl flags.searchApiKey
    )


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
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navKey (Url.toString url) )

                Browser.External url ->
                    ( model, Nav.load url )

        UrlChanged url ->
            ( { model | route = Url.Parser.parse urlParser url }, Cmd.none )

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



-- VIEWS


view : Model -> Browser.Document Msg
view model =
    { title = "Recipe Search"
    , body =
        [ div []
            [ viewSearchBox model.searchTerm
            , viewChips model
            , viewContents model
            ]
        ]
    }


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


viewSearchBox : String -> Html Msg
viewSearchBox defaultSearch =
    let
        fixedTerm = if defaultSearch == "*" then "" else defaultSearch
    in
    
    div [ class "container has-text-centered" ]
        [ div [ class "column is-6 is-offset-3" ]
            [ div [ class "box" ]
                [ div [ class "field is-grouped" ]
                    [ p [ class "control is-expanded" ]
                        [ input [ type_ "text", value fixedTerm, placeholder "Search For Recipes", class "input", onInput SearchTermChanged ]
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


viewRecipes : List Recipe -> Html Msg
viewRecipes recipes =
    div []
        [ table [ class "table is-hoverable is-narrow" ]
            (viewTableHeader :: List.map viewRecipe recipes)
        ]


viewTableHeader : Html Msg
viewTableHeader =
    thead []
        [ tr []
            [ th []
                [ text "Issue" ]
            , th []
                [ text "Date" ]
            , th []
                [ text "Recipe Name" ]
            , th []
                [ text "Page" ]
            , th []
                [ text "Category" ]
            ]
        ]


viewRecipe : Recipe -> Html Msg
viewRecipe recipe =
    tr []
        [ td []
            [ text (String.fromInt recipe.issue) ]
        , td []
            [ text (formatDate recipe) ]
        , td []
            [ text (formatTitle recipe) ]
        , td []
            [ text (String.fromInt recipe.page) ]
        , td []
            [ text (String.join ", " recipe.categories) ]
        ]


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
            viewRecipes results.recipes

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


type alias Flags =
    { searchServiceUrl : String
    , searchApiKey : String
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
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
