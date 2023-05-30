port module Main exposing (main)

import Dict
import Json.Decode as Decode exposing (Decoder, Error)
import Json.Encode as Encode
import Url


port input : (Input -> msg) -> Sub msg


port output : Output -> Cmd msg


type alias Input =
    { request : Decode.Value, response : Decode.Value }


type alias Output =
    { request : Decode.Value
    , response : Decode.Value
    , options : Maybe Encode.Value
    , secure : Bool
    }


type alias Request =
    { url : String, method : String, headers : Headers }


type Msg
    = Incoming Input


type alias Config =
    { baseURL : String, token : String }


main : Program Config Config Msg
main =
    Platform.worker
        { init = \config -> ( config, Cmd.none )
        , update = update
        , subscriptions = \_ -> input Incoming
        }


type alias Headers =
    Dict.Dict String String


type alias Options =
    { headers : Headers
    , hostname : String
    , port_ : Maybe Int
    , path : String
    , method : String
    }


options : Options -> Encode.Value
options opts =
    Encode.object
        [ ( "headers", opts.headers |> Encode.dict identity Encode.string )
        , ( "hostname", Encode.string opts.hostname )
        , ( "port", opts.port_ |> Maybe.map Encode.int |> Maybe.withDefault Encode.null )
        , ( "path", Encode.string opts.path )
        , ( "method", Encode.string opts.method )
        ]


update : Msg -> Config -> ( Config, Cmd Msg )
update msg config =
    case msg of
        Incoming { request, response } ->
            case
                Decode.decodeValue
                    (Decode.map3 Request
                        (Decode.field "url" Decode.string)
                        (Decode.field "method" Decode.string)
                        (Decode.field "headers" (Decode.dict Decode.string))
                    )
                    request
            of
                Ok { url, method, headers } ->
                    case checkRoute url of
                        Page ->
                            ( config
                            , output
                                { request = request
                                , response = response
                                , options =
                                    Just
                                        (options
                                            { headers = Dict.union (Dict.insert "host" "localhost" Dict.empty) headers
                                            , hostname = "localhost"
                                            , port_ = Just 1234
                                            , path = url
                                            , method = method
                                            }
                                        )
                                , secure = False
                                }
                            )

                        ImageAPI ->
                            let
                                urls : { path : String, query : Maybe String }
                                urls =
                                    [ "http://"
                                    , Dict.get "host" headers |> Maybe.withDefault ""
                                    , url
                                    ]
                                        |> String.concat
                                        |> Url.fromString
                                        |> Maybe.map (\{ path, query } -> { path = path, query = query })
                                        |> Maybe.withDefault { path = "", query = Nothing }

                                host : String
                                host =
                                    String.replace "https://" "" config.baseURL
                            in
                            ( config
                            , output
                                { request = request
                                , response = response
                                , options =
                                    Just
                                        (options
                                            { headers = Dict.union (Dict.insert "host" host Dict.empty) headers
                                            , hostname = host
                                            , port_ = Nothing
                                            , path =
                                                [ "/api/cockpit/image?token="
                                                , config.token
                                                , "&src="
                                                , config.baseURL
                                                , "/storage/uploads"
                                                , String.replace "/image/api" "" urls.path
                                                , "&"
                                                , urls.query |> Maybe.withDefault ""
                                                ]
                                                    |> String.concat
                                            , method = method
                                            }
                                        )
                                , secure = True
                                }
                            )

                -- TODO: handle errors
                Err _ ->
                    ( config
                    , output
                        { request = request
                        , response = response
                        , options = Nothing
                        , secure = False
                        }
                    )


type Route
    = ImageAPI
    | Page


checkRoute : String -> Route
checkRoute url =
    if String.startsWith "/image/api/" url then
        ImageAPI

    else
        Page
