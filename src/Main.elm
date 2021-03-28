module Main exposing (init, main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, Error(..), field, int, map2, map3, string)
import Recipe exposing (Recipe, recipesDecoder)
import RemoteData exposing (WebData)


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
    }


type Msg
    = SendHttpRequest
    | RecipesReceived (WebData IndexResult)
    | CategoryFacetChanged String Bool
    | YearFacetChanged String Bool


init : () -> ( Model, Cmd Msg )
init _ =
    ( { results = RemoteData.Loading
      , selectedYearFacets = []
      , selectedCategoryFacets = []
      , searchTerm = "*"
      }
    , fetchRecipes [] [] "*"
    )


fetchRecipes : List String -> List String -> String -> Cmd Msg
fetchRecipes yearFacets categoryFacets searchTerm =
    Http.get
        { url = buildSearchUrl yearFacets categoryFacets searchTerm
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
            String.join " or " (List.map (\s -> "category eq '" ++ s ++ "'") categoryFacets)
    in
    if String.isEmpty yearFacet && String.isEmpty categoryFacet then
        ""

    else if String.isEmpty yearFacet then
        "&$filter=" ++ categoryFacet

    else if String.isEmpty categoryFacet then
        "&$filter=" ++ yearFacet

    else
        "&$filter=" ++ categoryFacet ++ " and " ++ yearFacet


buildSearchUrl : List String -> List String -> String -> String
buildSearchUrl yearFacets categoryFacets searchTerm =
    "https://signsearchtest.search.windows.net/indexes/recipe-index/docs?search=" ++ searchTerm ++ buildFilters yearFacets categoryFacets ++ "&api-version=2020-06-30-Preview&facet=category&facet=year&api-key=4672B657830653CCAE3976FBDA26ED2D"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SendHttpRequest ->
            ( { model | results = RemoteData.Loading }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm )

        RecipesReceived response ->
            ( { model | results = response }, Cmd.none )

        YearFacetChanged facet checked ->
            if checked then
                ( { model | selectedYearFacets = model.selectedYearFacets ++ [ facet ] }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm )

            else
                ( { model | selectedYearFacets = List.filter (\s -> s /= facet) model.selectedYearFacets }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm )

        --List.filter (\s -> s == facet.category) selected
        CategoryFacetChanged facet checked ->
            if checked then
                ( { model | selectedCategoryFacets = model.selectedCategoryFacets ++ [ facet ] }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm )

            else
                ( { model | selectedCategoryFacets = List.filter (\s -> s /= facet) model.selectedCategoryFacets }, fetchRecipes model.selectedYearFacets model.selectedCategoryFacets model.searchTerm )



-- VIEWS


view : Model -> Html Msg
view model =
    div []
        [ viewSearchBox
        , viewContents model
        ]


viewContents : Model -> Html Msg
viewContents model =
    div [ class "container" ]
        [ div [ class "columns" ]
            [ div [ class "column is-3" ]
                [ viewFacetsOrError model ]
            , div [ class "column is-9" ]
                [ viewRecipesOrError model
                ]
            ]
        ]


viewSearchBox : Html Msg
viewSearchBox =
    div [ class "container has-text-centered" ]
        [ div [ class "column is-6 is-offset-3" ]
            [ div [ class "box" ]
                [ div [ class "field is-grouped" ]
                    [ p [ class "control is-expanded" ]
                        [ input [ type_ "text", placeholder "Search For Recipes", class "input" ]
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
        [ table [ class "table is-striped" ]
            ([ viewTableHeader ] ++ List.map viewRecipe recipes)
        ]


viewTableHeader : Html Msg
viewTableHeader =
    thead []
        [ tr []
            [ th []
                [ text "Issue" ]
            , th []
                [ text "Year" ]
            , th []
                [ text "Recipe Name" ]
            , th []
                [ text "Category" ]
            ]
        ]


viewRecipe : Recipe -> Html Msg
viewRecipe recipe =
    tr []
        [ td []
            [ text recipe.issue ]
        , td []
            [ text (String.fromInt recipe.year) ]
        , td []
            [ text recipe.recipe ]
        , td []
            [ text recipe.category ]
        ]


viewCategoryFacet : List String -> CategoryFacet -> Html Msg
viewCategoryFacet selected facet =
    let
        isChecked =
            not (List.isEmpty (List.filter (\s -> s == facet.category) selected))
    in
    input [ type_ "checkbox", checked isChecked, onClick (CategoryFacetChanged facet.category (not isChecked)) ]
        [ text (facet.category ++ " (" ++ String.fromInt facet.count ++ ")") ]


viewYearFacet : List String -> YearFacet -> Html Msg
viewYearFacet selected facet =
    let
        isChecked =
            not (List.isEmpty (List.filter (\s -> s == String.fromInt facet.year) selected))

        -- isChecked = True
    in
    input [ type_ "checkbox", checked isChecked, onClick (YearFacetChanged (String.fromInt facet.year) (not isChecked)) ]
        [ text (String.fromInt facet.year ++ " (" ++ String.fromInt facet.count ++ ")") ]


viewFacets : List CategoryFacet -> List YearFacet -> List String -> List String -> Html Msg
viewFacets categoryFacets yearFacets selectedCategoryFacets selectedYearFacets =
    let
        viewCatFacetWithSelect =
            viewCategoryFacet selectedCategoryFacets

        viewYearFacetWithSelect =
            viewYearFacet selectedYearFacets
    in
    ul [] (List.append (List.map viewCatFacetWithSelect categoryFacets) (List.map viewYearFacetWithSelect yearFacets))


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


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
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
        (field "category"
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
