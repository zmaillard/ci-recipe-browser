module Views.NoteView exposing (Model, Msg, update, view, init, viewNoteButton )
import Auth0
import Recipe exposing (Recipe, RecipeNotes)
import RemoteData exposing (RemoteData(..), WebData)
import API.Bot exposing (NoteRecipeResult, BotUrl, getNote, updateNotes)
import Html exposing (Html, p, text, textarea, div, header, button, section, footer)
import Html.Attributes as A
import Html.Events as E
import Note exposing (Note, toNote, fromNote)

type alias Model = 
    { noteEditText : String
    , showEditModal : Bool
    , noteEditRecipe : Maybe Recipe
    , login : Auth0.AuthenticationState
    , botUrl : BotUrl
    , isSaving : Bool
    }


init : Auth0.AuthenticationState -> BotUrl -> Model 
init auth botUrl =
    { noteEditText = ""
    , showEditModal = False
    , noteEditRecipe = Maybe.Nothing
    , login = auth
    , botUrl = botUrl
    , isSaving = False
    }


type Msg 
    = ShowNote Recipe
    | GotGetNotes (WebData NoteRecipeResult)
    | UpdateNoteResults (WebData NoteRecipeResult)
    | CloseModal
    | SaveNoteEdits Recipe
    | CancelNoteEdits
    | NoteValueChanged String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of 
        ShowNote recipe ->
            case model.login of
                Auth0.LoggedIn user ->
                    ( { model | noteEditRecipe = Just recipe }, getNote model.botUrl user recipe GotGetNotes )

                _ ->
                    ( model, Cmd.none )

        UpdateNoteResults noteResult ->
            case noteResult of
                Success _ ->
                    ( { model | noteEditText = "", showEditModal = False, isSaving = False}, Cmd.none )
                _ ->
                    ( { model | isSaving = False}, Cmd.none )

        GotGetNotes noteResult ->
            case noteResult of
                Success data ->
                    case data.notes |> List.head of 
                        Just note ->
                            ( { model | noteEditText = (note.note |> fromNote ), showEditModal = True, isSaving = False}, Cmd.none )
                        _ ->
                            ( { model | noteEditText = "", showEditModal = True, isSaving = False}, Cmd.none )

                _ ->
                    ( { model | noteEditText = "", showEditModal = False, isSaving = False }, Cmd.none )
        CloseModal ->
            ( { model | noteEditText = "", showEditModal = False }, Cmd.none )

        SaveNoteEdits recipe ->
            case model.login of
                Auth0.LoggedIn user ->
                    ( { model | isSaving = True }, saveNote model.botUrl (toNote model.noteEditText) recipe user )

                _ ->
                    ( { model | isSaving = False }, Cmd.none )

        CancelNoteEdits ->
            ( { model | noteEditText = "", showEditModal = False }, Cmd.none )
        NoteValueChanged noteText ->
            ( { model | noteEditText = noteText }, Cmd.none )

viewRecipe : Model -> Recipe -> Html Msg
viewRecipe model recipe =
    let
        modalclass =
            if model.showEditModal then
                " is-active"

            else
                ""
    
        loadingClass = if model.isSaving then " is-loading" else ""
    in
    div [ A.class ("modal " ++ modalclass) ]
        [ div [ A.class "modal-background" ]
            []
        , div [ A.class "modal-card" ]
            [ header [ A.class "modal-card-head" ]
                [ p [ A.class "modal-card-title" ]
                    [ text "Add/Edit Notes"
                    ]
                , button [ A.class "delete", E.onClick CloseModal ]
                    []
                ]
            , section [ A.class "modal-card-body" ]
                [ textarea [ A.class "textarea", A.placeholder "Enter A New Note...", A.value model.noteEditText, E.onInput NoteValueChanged ]
                    []
                ]
            , footer [ A.class "modal-card-foot", E.onClick (SaveNoteEdits recipe )]
                [ button [ A.class ("button is-success" ++ loadingClass) ]
                    [ text "Save"
                    ]
                , button [ A.class "button", E.onClick CancelNoteEdits ]
                    [ text "Cancel"
                    ]
                ]
            ]
        ]


view : Model -> Html Msg
view model =
    case model.noteEditRecipe of
        Just r ->
            viewRecipe model r 
        _ ->

            let
                modalclass =
                    if model.showEditModal then
                        " is-active"
        
                    else
                        ""
            in
            div [ A.class ("modal " ++ modalclass) ]
                [ div [ A.class "modal-background" ]
                    []
                , div [ A.class "modal-content" ]
                [
                    p []
                    [
                        text "No Content Found"
                    ]
                ]
                ]

viewNoteButton : Recipe -> Html Msg
viewNoteButton recipe =
    button [ A.class "button is-small is-text", E.onClick (ShowNote recipe) ]
        [ text "Edit Note"
        ]

saveNote : BotUrl -> Note -> Recipe -> Auth0.LoggedInUser -> Cmd Msg
saveNote url note recipe user =
    updateNotes url user recipe note  UpdateNoteResults 


viewNoteDetails : RecipeNotes -> Html Msg
viewNoteDetails recipeNotes =
    div [A.class "box"]
    [
        p[ ]
        [
            text recipeNotes.user
        ]
        , p[ ]
        [
            recipeNotes.noteDetails |> fromNote |> text
        ]
    ]

viewAllNotesReadOnly : Recipe -> Html Msg
viewAllNotesReadOnly recipe =
    div [A.class "modal-content"]
    ( List.map viewNoteDetails recipe.notes )
