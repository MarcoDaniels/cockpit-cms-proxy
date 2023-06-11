port module Main exposing (main)

import Dict
import Json.Decode as Decode exposing (Decoder, Error)
import Json.Decode.Pipeline as Decode
import Json.Encode as Encode
import Url


port input : (Decode.Value -> msg) -> Sub msg


port output : Decode.Value -> Cmd msg


type alias HTTPReqRes =
    { request : Decode.Value, response : Decode.Value }


type InputPort
    = InputPortOk InputOk
    | InputPortError InputError


type alias InputOk =
    { success : Bool, handler : HTTPReqRes }


type alias InputError =
    { success : Bool, error : String, handler : HTTPReqRes }


type OutputPort
    = OutputPortOk OutputOk
    | OutputPortError OutputError


type alias OutputOk =
    { success : Bool, options : Options, secure : Bool, handler : HTTPReqRes }


type alias OutputError =
    { success : Bool, data : String, handler : HTTPReqRes }


type alias HttpRequest =
    { url : String, method : String, headers : Headers }


type alias Headers =
    Dict.Dict String String


type alias Options =
    { headers : Headers
    , hostname : String
    , port_ : Maybe Int
    , path : String
    , method : String
    }


type alias Config =
    { baseURL : String, token : String }


toOutput : OutputPort -> Cmd msg
toOutput out =
    let
        handlerEncoder : HTTPReqRes -> Encode.Value
        handlerEncoder handler =
            Encode.object [ ( "request", handler.request ), ( "response", handler.response ) ]
    in
    (case out of
        OutputPortOk ok ->
            Encode.object
                [ ( "success", Encode.bool ok.success )
                , ( "options"
                  , Encode.object
                        [ ( "headers", ok.options.headers |> Encode.dict identity Encode.string )
                        , ( "hostname", Encode.string ok.options.hostname )
                        , ( "port", ok.options.port_ |> Maybe.map Encode.int |> Maybe.withDefault Encode.null )
                        , ( "path", Encode.string ok.options.path )
                        , ( "method", Encode.string ok.options.method )
                        ]
                  )
                , ( "secure", Encode.bool ok.secure )
                , ( "handler", handlerEncoder ok.handler )
                ]

        OutputPortError err ->
            Encode.object
                [ ( "success", Encode.bool err.success )
                , ( "data", Encode.string err.data )
                , ( "handler", handlerEncoder err.handler )
                ]
    )
        |> output


fromInput : Decoder InputPort
fromInput =
    Decode.field "success" Decode.bool
        |> Decode.andThen
            (\success ->
                let
                    handlerDecoder =
                        Decode.succeed HTTPReqRes
                            |> Decode.required "request" Decode.value
                            |> Decode.required "response" Decode.value
                in
                case success of
                    True ->
                        Decode.map InputPortOk
                            (Decode.succeed InputOk
                                |> Decode.required "success" Decode.bool
                                |> Decode.required "handler" handlerDecoder
                            )

                    False ->
                        Decode.map InputPortError
                            (Decode.succeed InputError
                                |> Decode.required "success" Decode.bool
                                |> Decode.required "error" Decode.string
                                |> Decode.required "handler" handlerDecoder
                            )
            )


main : Program Config Config (Result Error InputPort)
main =
    Platform.worker
        { init = \config -> ( config, Cmd.none )
        , update = update
        , subscriptions = \_ -> input (Decode.decodeValue fromInput)
        }


update : Result Error InputPort -> Config -> ( Config, Cmd (Result Error InputPort) )
update msg config =
    case msg of
        Err _ ->
            ( config
            , OutputPortError
                { success = False
                , data = "Error on decoder"
                , handler = { response = Encode.null, request = Encode.null }
                }
                |> toOutput
            )

        Ok inputDecoded ->
            case inputDecoded of
                InputPortError { error, handler } ->
                    ( config
                    , OutputPortError
                        { success = False, data = "Handler error: " ++ error, handler = handler }
                        |> toOutput
                    )

                InputPortOk { handler } ->
                    case
                        Decode.decodeValue
                            (Decode.succeed HttpRequest
                                |> Decode.required "url" Decode.string
                                |> Decode.required "method" Decode.string
                                |> Decode.required "headers" (Decode.dict Decode.string)
                            )
                            handler.request
                    of
                        Ok { url, method, headers } ->
                            case checkRoute url of
                                Page ->
                                    ( config
                                    , OutputPortOk
                                        { success = True
                                        , handler = handler
                                        , options =
                                            { headers = Dict.union (Dict.insert "host" "localhost" Dict.empty) headers
                                            , hostname = "localhost"
                                            , port_ = Just 1234
                                            , path = url
                                            , method = method
                                            }
                                        , secure = False
                                        }
                                        |> toOutput
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
                                    , OutputPortOk
                                        { success = True
                                        , handler = handler
                                        , options =
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
                                        , secure = True
                                        }
                                        |> toOutput
                                    )

                        -- TODO: handle errors
                        Err _ ->
                            ( config
                            , OutputPortError
                                { success = False, data = "something went wrong", handler = handler }
                                |> toOutput
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
