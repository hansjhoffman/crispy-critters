module Main exposing (..)

import Api
import Api.Endpoint as Endpoint exposing (AccessToken, SubscriptionCreds)
import Browser
import Environment exposing (Environment)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Attributes.Extra as AttrExtra
import Html.Events as Events
import Html.Extra
import Http
import Icon
import InteropDefinitions
import InteropPorts
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData exposing (RemoteData(..), WebData)
import Space exposing (Space)



-- MODEL


type alias Model =
    { clientId : String
    , secretKey : String
    , accessToken : WebData AccessToken
    , showSecret : Bool
    , showEnvironmentChoices : Bool
    , selectedEnvironment : Maybe Environment
    , environments : WebData (List Environment)
    , showSpaceChoices : Bool
    , selectedSpace : Maybe Space
    , spaces : WebData (List Space)
    , events : List String
    , subscriptionCreds : WebData SubscriptionCreds
    , expandedEventId : Maybe String
    }


initialModel : Model
initialModel =
    { clientId = ""
    , secretKey = ""
    , accessToken = NotAsked
    , showSecret = False
    , showEnvironmentChoices = False
    , selectedEnvironment = Nothing
    , environments = NotAsked
    , showSpaceChoices = False
    , selectedSpace = Nothing
    , spaces = NotAsked
    , events = []
    , subscriptionCreds = NotAsked
    , expandedEventId = Nothing
    }


init : Decode.Value -> ( Model, Cmd Msg )
init flags =
    case InteropPorts.decodeFlags flags of
        Err _ ->
            ( initialModel, Cmd.none )

        Ok _ ->
            ( initialModel, Cmd.none )



-- UPDATE


type Msg
    = Reset
    | OpenExternalLink String
    | ClickedEvent String
      -- Form
    | EnteredClientId String
    | EnteredSecretKey String
    | ToggleShowSecret
    | SelectedEnvironment Environment
    | ToggleEnvironmentChoices
    | SelectedSpace Space
    | ToggleSpaceChoices
      -- Http
    | SendAuthRequest
    | GotAuthResponse (WebData AccessToken)
    | GotEnvironmentsResponse (WebData (List Environment))
    | GotSpacesResponse (WebData (List Space))
    | GotSubscriptionCredsResponse (WebData SubscriptionCreds)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Reset ->
            ( initialModel, Cmd.none )

        OpenExternalLink externalLink ->
            ( model
            , externalLink
                |> InteropDefinitions.OpenExternalLink
                |> InteropPorts.fromElm
            )

        ClickedEvent incomingEventId ->
            case model.expandedEventId of
                Just previousEventId ->
                    if incomingEventId == previousEventId then
                        ( { model | expandedEventId = Nothing }, Cmd.none )

                    else
                        ( { model | expandedEventId = Just incomingEventId }, Cmd.none )

                Nothing ->
                    ( { model | expandedEventId = Just incomingEventId }, Cmd.none )

        EnteredClientId clientId ->
            ( { model | clientId = clientId }, Cmd.none )

        EnteredSecretKey secretKey ->
            ( { model | secretKey = secretKey }, Cmd.none )

        ToggleShowSecret ->
            ( { model | showSecret = not model.showSecret }, Cmd.none )

        SelectedEnvironment env ->
            ( { model | selectedEnvironment = Just env, showEnvironmentChoices = False }
            , Space.list env.id GotSpacesResponse
            )

        ToggleEnvironmentChoices ->
            ( { model | showEnvironmentChoices = not model.showEnvironmentChoices }, Cmd.none )

        SelectedSpace space ->
            ( { model | selectedSpace = Just space }
            , Api.get (Endpoint.getSubscriptionCreds <| Space.unwrap space.id) GotSubscriptionCredsResponse Endpoint.subscriptionCredsDecoder
            )

        ToggleSpaceChoices ->
            ( { model | showSpaceChoices = not model.showSpaceChoices }, Cmd.none )

        GotAuthResponse response ->
            case response of
                Success _ ->
                    ( { model | accessToken = response }
                    , Environment.list GotEnvironmentsResponse
                    )

                Failure _ ->
                    ( { model | accessToken = response }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SendAuthRequest ->
            let
                clientId =
                    model.clientId

                secretKey =
                    model.secretKey

                jsonBody =
                    Encode.object
                        [ ( "clientId", Encode.string clientId )
                        , ( "secret", Encode.string secretKey )
                        ]
                        |> Http.jsonBody
            in
            ( model, Api.post Endpoint.auth jsonBody GotAuthResponse Endpoint.authDecoder )

        GotEnvironmentsResponse response ->
            ( { model | environments = response }, Cmd.none )

        GotSpacesResponse response ->
            ( { model | spaces = response }, Cmd.none )

        GotSubscriptionCredsResponse response ->
            ( { model | subscriptionCreds = response }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


mkTestAttribute : String -> Attribute msg
mkTestAttribute key =
    Attr.attribute "data-testid" (String.toLower key)


viewAuthForm : Model -> Html Msg
viewAuthForm model =
    case model.accessToken of
        NotAsked ->
            div [ Attr.class "w-full" ]
                [ form
                    [ Attr.class ""
                    , Events.onSubmit SendAuthRequest
                    ]
                    [ div [ Attr.class "grid grid-cols-2 gap-y-6 gap-x-8" ]
                        [ div [ Attr.class "" ]
                            [ label
                                [ Attr.class "block text-sm font-semibold leading-6 text-gray-900"
                                , Attr.for "client-id"
                                ]
                                [ text "Client Id" ]
                            , div [ Attr.class "mt-2.5" ]
                                [ input
                                    [ mkTestAttribute "input-client-id"
                                    , Attr.autocomplete False
                                    , Attr.autofocus True
                                    , Attr.class "block w-full rounded-md border-0 py-2 px-3.5 text-sm leading-6 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600"
                                    , Attr.id "client-id"
                                    , Attr.name "client-id"
                                    , Events.onInput EnteredClientId
                                    ]
                                    []
                                ]
                            ]
                        , div [ Attr.class "" ]
                            [ div [ Attr.class "flex items-center justify-between" ]
                                [ label
                                    [ Attr.class "block text-sm font-semibold leading-6 text-gray-900"
                                    , Attr.for "secret-key"
                                    ]
                                    [ text "Secret" ]
                                , div
                                    [ Attr.class "cursor-pointer text-gray-700"
                                    , Events.onClick ToggleShowSecret
                                    ]
                                    [ if model.showSecret then
                                        Icon.defaults
                                            |> Icon.withSize 18
                                            |> Icon.eyeClose

                                      else
                                        Icon.defaults
                                            |> Icon.withSize 18
                                            |> Icon.eyeOpen
                                    ]
                                ]
                            , div [ Attr.class "mt-2.5" ]
                                [ input
                                    [ mkTestAttribute "input-secret-key"
                                    , Attr.class "block w-full rounded-md border-0 py-2 px-3.5 text-sm leading-6 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600"
                                    , Attr.name "secret-key"
                                    , Attr.id "secret-key"
                                    , Attr.autocomplete False
                                    , Attr.type_
                                        (if model.showSecret then
                                            "text"

                                         else
                                            "password"
                                        )
                                    , Events.onInput EnteredSecretKey
                                    ]
                                    []
                                ]
                            ]
                        , button
                            [ mkTestAttribute "btn-auth-submit"
                            , Attr.class "col-span-full inline-flex items-center justify-center rounded-md px-3 py-2 text-sm font-semibold shadow-sm bg-indigo-600 text-white"
                            , Attr.type_ "submit"
                            ]
                            [ text "Authenticate" ]
                        ]
                    ]
                ]

        Loading ->
            div [] [ text "loading" ]

        Success _ ->
            div [] [ text "success!" ]

        Failure _ ->
            div [] [ text "failure :(" ]


viewMeta : Environment -> Space -> Html Msg
viewMeta selectedEnvironment selectedSpace =
    let
        spaceName : String
        spaceName =
            Maybe.withDefault ("[Unnamed — " ++ Space.unwrap selectedSpace.id ++ "]") selectedSpace.name

        environmentName : String
        environmentName =
            selectedEnvironment.name

        createdAt : String
        createdAt =
            Maybe.withDefault "[Date Unknown]" (Just "10 Jan 2023")

        createdBy : String
        createdBy =
            Maybe.withDefault "@username" selectedSpace.createdByUserName
    in
    div [ Attr.class "flex items-center justify-between py-5 px-4" ]
        [ div [ Attr.class "flex-col" ]
            [ h2 [ Attr.class "text-2xl font-bold leading-7 text-gray-900" ] [ text spaceName ]
            , div [ Attr.class "flex mt-1 space-x-6" ]
                [ div [ Attr.class "inline-flex items-center text-sm text-gray-300" ]
                    [ span [] [ text environmentName ]
                    ]
                , div [ Attr.class "inline-flex items-center text-sm text-gray-300" ]
                    [ Icon.defaults
                        |> Icon.withSize 20
                        |> Icon.calendar
                    , span [ Attr.class "ml-1.5" ] [ text createdAt ]
                    ]
                , div [ Attr.class "inline-flex items-center text-sm text-gray-300" ]
                    [ Icon.defaults
                        |> Icon.withSize 20
                        |> Icon.user
                    , span [ Attr.class "ml-1.5" ] [ text createdBy ]
                    ]
                ]
            ]
        , div [ Attr.class "flex" ]
            [ div [ Attr.class "mr-2" ]
                [ button
                    [ mkTestAttribute "btn-view-space"
                    , Attr.class "inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold shadow-sm"
                    , Events.onClick (OpenExternalLink <| "https://spaces.flatfile.com/space/" ++ Space.unwrap selectedSpace.id)
                    ]
                    [ Icon.defaults
                        |> Icon.withSize 20
                        |> Icon.chainlink
                    , span [ Attr.class "ml-1.5" ] [ text "View" ]
                    ]
                ]
            , div [ Attr.class "" ]
                [ button
                    [ mkTestAttribute "btn-reset"
                    , Attr.class "inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold shadow-sm"
                    , Events.onClick Reset
                    ]
                    [ Icon.defaults
                        |> Icon.withSize 20
                        |> Icon.resetCircle
                    , span [ Attr.class "ml-1.5" ] [ text "Reset" ]
                    ]
                ]
            ]
        ]


viewSelectEnvironment : Model -> Html Msg
viewSelectEnvironment model =
    case model.environments of
        NotAsked ->
            div [ Attr.class "" ] [ text "Not Asked" ]

        Loading ->
            div [ Attr.class "" ] [ text "Loading..." ]

        Success environments ->
            div [ Attr.class "" ]
                [ label
                    [ Attr.class "block text-sm font-semibold leading-6 text-gray-900"
                    , Attr.id "listbox-environments-label"
                    ]
                    [ text "Environments" ]
                , div [ Attr.class "relative mt-2" ]
                    [ button
                        [ Attr.class "relative w-full hover:cursor-pointer rounded-md bg-white py-1.5 pl-3 pr-10 text-left text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:text-sm sm:leading-6"
                        , Attr.attribute "aria-haspopup" "listbox"
                        , AttrExtra.attributeIf model.showEnvironmentChoices <| Attr.attribute "aria-expanded" "true"
                        , Attr.attribute "aria-labelledby" "listbox-environments-label"
                        , Events.onClick ToggleEnvironmentChoices
                        ]
                        [ span [ Attr.class "inline-flex w-full truncate" ]
                            [ span [ Attr.class "truncate select-none" ]
                                [ text <|
                                    Maybe.withDefault "Select..." <|
                                        Maybe.map (\env -> env.name) model.selectedEnvironment
                                ]
                            , span [ Attr.class "ml-2 truncate text-gray-500" ]
                                [ text <|
                                    Maybe.withDefault "" <|
                                        Maybe.map (\env -> Environment.unwrap env.id) model.selectedEnvironment
                                ]
                            ]
                        , span [ Attr.class "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2 text-gray-400" ]
                            [ Icon.defaults
                                |> Icon.withSize 20
                                |> Icon.selectArrows
                            ]
                        ]
                    , ul
                        [ Attr.class "absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm"
                        , Attr.classList [ ( "hidden", not model.showEnvironmentChoices ) ]
                        , Attr.tabindex -1
                        , Attr.attribute "role" "listbox"
                        , Attr.attribute "aria-labelledby" "listbox-environments-label"
                        , Attr.attribute "aria-activedescendant" "listbox-option-0"
                        ]
                        (List.indexedMap
                            (\idx env ->
                                let
                                    attrId : String
                                    attrId =
                                        "listbox-option-" ++ String.fromInt idx

                                    envId : String
                                    envId =
                                        Environment.unwrap env.id
                                in
                                li
                                    [ Attr.class "text-gray-900 relative cursor-default select-none py-2 pl-3 pr-9 hover:bg-indigo-100"
                                    , Attr.id attrId
                                    , Attr.attribute "role" "option"
                                    , Events.onClick (SelectedEnvironment env)
                                    ]
                                    [ div [ Attr.class "flex font-normal" ]
                                        [ span
                                            [ Attr.classList
                                                [ ( "font-semibold"
                                                  , case model.selectedEnvironment of
                                                        Just selected ->
                                                            selected.id == env.id

                                                        Nothing ->
                                                            False
                                                  )
                                                , ( "truncate", True )
                                                ]
                                            ]
                                            [ text env.name ]
                                        , span [ Attr.class "text-gray-500 ml-2 truncate" ] [ text envId ]
                                        ]
                                    , case model.selectedEnvironment of
                                        Just selected ->
                                            Html.Extra.viewIf (selected.id == env.id) <|
                                                span [ Attr.class "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2 text-indigo-600" ]
                                                    [ Icon.defaults
                                                        |> Icon.withSize 20
                                                        |> Icon.checkmark
                                                    ]

                                        Nothing ->
                                            Html.Extra.nothing
                                    ]
                            )
                            environments
                        )
                    ]
                ]

        Failure _ ->
            div [ Attr.class "" ] [ text "Failure :(" ]


viewSelectSpace : Model -> Html Msg
viewSelectSpace model =
    case model.spaces of
        NotAsked ->
            div [ Attr.class "" ] [ text "Not Asked" ]

        Loading ->
            div [ Attr.class "" ] [ text "Loading..." ]

        Success spaces ->
            div [ Attr.class "" ]
                [ label
                    [ Attr.class "block text-sm font-semibold leading-6 text-gray-900"
                    , Attr.id "listbox-spaces-label"
                    ]
                    [ text "Spaces" ]
                , div [ Attr.class "relative mt-2" ]
                    [ button
                        [ Attr.class "relative w-full hover:cursor-pointer rounded-md bg-white py-1.5 pl-3 pr-10 text-left text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:text-sm sm:leading-6"
                        , Attr.attribute "aria-haspopup" "listbox"
                        , AttrExtra.attributeIf model.showSpaceChoices <| Attr.attribute "aria-expanded" "true"
                        , Attr.attribute "aria-labelledby" "listbox-spaces-label"
                        , Events.onClick ToggleSpaceChoices
                        ]
                        [ span [ Attr.class "inline-flex w-full truncate" ]
                            [ span [ Attr.class "truncate select-none" ]
                                [ text <|
                                    Maybe.withDefault "Select..." <|
                                        Maybe.andThen (\name -> name) <|
                                            Maybe.map (\space -> space.name) model.selectedSpace
                                ]
                            , span [ Attr.class "ml-2 truncate text-gray-500" ]
                                [ text <|
                                    Maybe.withDefault "" <|
                                        Maybe.map (\space -> Space.unwrap space.id) model.selectedSpace
                                ]
                            ]
                        , span [ Attr.class "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2 text-gray-400" ]
                            [ Icon.defaults
                                |> Icon.withSize 20
                                |> Icon.selectArrows
                            ]
                        ]
                    , ul
                        [ Attr.class "absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm"
                        , Attr.classList [ ( "hidden", not model.showSpaceChoices ) ]
                        , Attr.tabindex -1
                        , Attr.attribute "role" "listbox"
                        , Attr.attribute "aria-labelledby" "listbox-spaces-label"
                        , Attr.attribute "aria-activedescendant" "listbox-option-0"
                        ]
                        (List.indexedMap
                            (\idx space ->
                                let
                                    attrId : String
                                    attrId =
                                        "listbox-option-" ++ String.fromInt idx

                                    spaceId : String
                                    spaceId =
                                        Space.unwrap space.id
                                in
                                li
                                    [ Attr.class "text-gray-900 relative cursor-default select-none py-2 pl-3 pr-9 hover:bg-indigo-100"
                                    , Attr.id attrId
                                    , Attr.attribute "role" "option"
                                    , Events.onClick (SelectedSpace space)
                                    ]
                                    [ div [ Attr.class "flex font-normal" ]
                                        [ span
                                            [ Attr.classList
                                                [ ( "font-semibold"
                                                  , case model.selectedSpace of
                                                        Just selected ->
                                                            selected.id == space.id

                                                        Nothing ->
                                                            False
                                                  )
                                                , ( "truncate", True )
                                                ]
                                            ]
                                            [ text <| Maybe.withDefault "[Unnamed]" space.name ]
                                        , span [ Attr.class "text-gray-500 ml-2 truncate" ] [ text spaceId ]
                                        ]
                                    , case model.selectedSpace of
                                        Just selected ->
                                            Html.Extra.viewIf (selected.id == space.id) <|
                                                span [ Attr.class "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2 text-indigo-600" ]
                                                    [ Icon.defaults
                                                        |> Icon.withSize 20
                                                        |> Icon.checkmark
                                                    ]

                                        Nothing ->
                                            Html.Extra.nothing
                                    ]
                            )
                            spaces
                        )
                    ]
                ]

        Failure _ ->
            div [ Attr.class "" ] [ text "Failure :(" ]


viewEventsTable : Model -> Html Msg
viewEventsTable model =
    let
        arrowIcon : String -> Html msg
        arrowIcon incomingEventId =
            case model.expandedEventId of
                Just previousEventId ->
                    if incomingEventId == previousEventId then
                        Icon.defaults
                            |> Icon.withSize 20
                            |> Icon.arrowDown

                    else
                        Icon.defaults
                            |> Icon.withSize 20
                            |> Icon.arrowRight

                Nothing ->
                    Icon.defaults
                        |> Icon.withSize 20
                        |> Icon.arrowRight

        domainIcon : String -> Html msg
        domainIcon domain =
            case domain of
                "workbook" ->
                    Icon.defaults
                        |> Icon.withSize 24
                        |> Icon.domainWorkbook

                "file" ->
                    Icon.defaults
                        |> Icon.withSize 24
                        |> Icon.domainFile

                "job" ->
                    Icon.defaults
                        |> Icon.withSize 24
                        |> Icon.domainJob

                "space" ->
                    Icon.defaults
                        |> Icon.withSize 24
                        |> Icon.domainSpace

                _ ->
                    span [] []

        badge : String -> Html msg
        badge eventTopic =
            span [ Attr.class "inline-flex items-center rounded-md bg-gray-100 px-2.5 py-0.5 text-sm font-medium text-gray-800" ] [ text eventTopic ]
    in
    div [ Attr.class "px-4" ]
        [ div [ Attr.class "flex items-center" ]
            [ div [ Attr.class "flex-auto" ]
                [ h1 [ Attr.class "text-base font-semibold leading-6 text-gray-900" ] [ text "Events" ]
                , p [ Attr.class "mt-2 text-sm text-gray-700" ] [ text "Flatfile's platform was built using the event-driven architecture... Events are streamed in real-time" ]
                ]
            , div [ Attr.class "mt-4 sm:mt-0 sm:ml-16 sm:flex-none" ]
                [ button [ Attr.class "block rounded-md bg-indigo-600 py-2 px-3 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600" ] [ text "Export" ]
                ]
            ]
        , div [ Attr.class "mt-8 flow-root" ]
            [ div [ Attr.class "-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8" ]
                [ div [ Attr.class "inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8" ]
                    [ table [ Attr.class "min-w-full divide-y divide-gray-300" ]
                        [ thead [ Attr.class "" ]
                            [ tr [ Attr.class "" ]
                                [ th
                                    [ Attr.class "whitespace-nowrap py-3.5 px-2 text-left text-sm font-semibold text-gray-900"
                                    , Attr.scope "col"
                                    ]
                                    [ text "Domain" ]
                                , th
                                    [ Attr.class "whitespace-nowrap py-3.5 px-2 text-left text-sm font-semibold text-gray-900"
                                    , Attr.scope "col"
                                    ]
                                    [ text "Timestamp" ]
                                , th
                                    [ Attr.class "whitespace-nowrap py-3.5 px-2 text-left text-sm font-semibold text-gray-900"
                                    , Attr.scope "col"
                                    ]
                                    [ text "Summary" ]
                                ]
                            ]
                        , tbody [ Attr.class "divide-y divide-gray-200 bg-white" ]
                            [ tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_1")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_1"
                                    , domainIcon "workbook"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "records:created"
                                    , span [ Attr.class "ml-2" ] [ text "42 records" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_1")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_1"
                                    , domainIcon "workbook"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "records:updated"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_1")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_1"
                                    , domainIcon "workbook"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "records:deleted"
                                    , span [ Attr.class "ml-2" ] [ text "1 record" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_1")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_1"
                                    , domainIcon "workbook"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "sheet:validated"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_2")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_2"
                                    , domainIcon "file"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "upload:started"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_2")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_2"
                                    , domainIcon "file"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "upload:completed"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_3")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_3"
                                    , domainIcon "job"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "job:waiting"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_3")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_3"
                                    , domainIcon "job"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "job:started"
                                    , span [ Attr.class "ml-2" ] [ text "File extraction" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_3")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_3"
                                    , domainIcon "job"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "job:updated"
                                    , span [ Attr.class "ml-2" ] [ text "File extraction" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_3")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_3"
                                    , domainIcon "job"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "job:failed"
                                    , span [ Attr.class "ml-2" ] [ text "File extraction" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_3")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_3"
                                    , domainIcon "job"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "job:completed"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            , tr
                                [ Attr.class "cursor-pointer"
                                , Events.onClick (ClickedEvent "us_evt_4")
                                ]
                                [ td [ Attr.class "flex items-center space-x-2 whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ arrowIcon "us_evt_4"
                                    , domainIcon "space"
                                    ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ] [ text "2019-12-17 10:10:37.951 MST" ]
                                , td [ Attr.class "whitespace-nowrap py-2 px-2 text-sm text-gray-500" ]
                                    [ badge "space:created"
                                    , span [ Attr.class "ml-2" ] [ text "Some helpful summary text" ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    -- let
    --     env : Environment
    --     env =
    --         Environment "us_env_GHasdfyU" "us_acc_FBClpjku" "Some Env Name"
    --     space : Space
    --     space =
    --         Space "us_sp_UxfreSbn" Nothing Nothing Nothing (Just "10 Jan 2023") "us_env_GHasdfyU" Nothing
    -- in
    { title = "Hello"
    , body =
        [ div [ Attr.class "w-4/5 m-auto mt-20" ]
            -- [ section [ Attr.class "", mkTestAttribute "section-events" ]
            --     [ viewMeta env space
            --     , viewEventsTable model
            --     ]
            -- ]
            [ section
                [ mkTestAttribute "section-preflight"
                , Attr.class "flex items-center justify-between"
                ]
                [ viewAuthForm model
                , div [ Attr.class "border-r-2 border-gray-300 w-1 h-12 mx-8" ] []
                , div [ Attr.class "flex justify-between w-full" ]
                    [ viewSelectEnvironment model
                    , viewSelectSpace model
                    ]
                ]
            ]
        ]
    }



-- MAIN


main : Program Decode.Value Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
