port module Main exposing (main)

import Dict
import Json.Decode as Decode exposing (Decoder, Error)
import Json.Decode.Pipeline as Decode
import Json.Encode as Encode
import Url


port input : (InputPort -> msg) -> Sub msg


port output : Decode.Value -> Cmd msg


type Msg
    = Incoming InputPort


type alias InputPort =
    { request : Decode.Value, response : Decode.Value, meta : Decode.Value }


type MetaInput
    = MetaInputOk InputOk
    | MetaInputError InputError


type alias InputOk =
    { success : Bool }


type alias InputError =
    { success : Bool, error : String }


type alias OutputPort =
    { request : Decode.Value, response : Decode.Value, meta : MetaOutput }


type MetaOutput
    = MetaOutputOk OutputOk
    | MetaOutputError OutputError


type alias OutputOk =
    { success : Bool, options : Options, secure : Bool }


type alias OutputError =
    { success : Bool, data : String }


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
    { baseURL : String
    , token : String
    , assetsPath : String
    , targetHost : String
    , targetPort : Maybe Int
    }


toOutput : OutputPort -> Cmd msg
toOutput { request, response, meta } =
    Encode.object
        [ ( "request", request )
        , ( "response", response )
        , ( "meta"
          , case meta of
                MetaOutputOk ok ->
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
                        ]

                MetaOutputError err ->
                    Encode.object
                        [ ( "success", Encode.bool err.success )
                        , ( "data", Encode.string err.data )
                        ]
          )
        ]
        |> output


fromInput : Decoder MetaInput
fromInput =
    Decode.field "success" Decode.bool
        |> Decode.andThen
            (\success ->
                case success of
                    True ->
                        Decode.map MetaInputOk
                            (Decode.succeed InputOk |> Decode.required "success" Decode.bool)

                    False ->
                        Decode.map MetaInputError
                            (Decode.succeed InputError
                                |> Decode.required "success" Decode.bool
                                |> Decode.required "error" Decode.string
                            )
            )


main : Program Config Config Msg
main =
    Platform.worker
        { init = \config -> ( config, Cmd.none )
        , update = update
        , subscriptions = \_ -> input Incoming
        }


update : Msg -> Config -> ( Config, Cmd Msg )
update msg config =
    case msg of
        Incoming { request, response, meta } ->
            let
                errorOutput : String -> ( Config, Cmd msg )
                errorOutput err =
                    ( config
                    , { response = response
                      , request = request
                      , meta = MetaOutputError { success = False, data = err }
                      }
                        |> toOutput
                    )
            in
            case Decode.decodeValue fromInput meta of
                Ok metaInput ->
                    case metaInput of
                        MetaInputOk _ ->
                            case
                                Decode.decodeValue
                                    (Decode.succeed HttpRequest
                                        |> Decode.required "url" Decode.string
                                        |> Decode.required "method" Decode.string
                                        |> Decode.required "headers" (Decode.dict Decode.string)
                                    )
                                    request
                            of
                                Ok { url, method, headers } ->
                                    case checkRoute config.assetsPath url of
                                        Page ->
                                            ( config
                                            , { request = request
                                              , response = response
                                              , meta =
                                                    MetaOutputOk
                                                        { success = True
                                                        , options =
                                                            { headers = Dict.union (Dict.insert "host" config.targetHost Dict.empty) headers
                                                            , hostname = config.targetHost
                                                            , port_ = config.targetPort
                                                            , path = url
                                                            , method = method
                                                            }
                                                        , secure = False
                                                        }
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
                                            , { response = response
                                              , request = request
                                              , meta =
                                                    MetaOutputOk
                                                        { success = True
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
                                                                , String.replace config.assetsPath "" urls.path
                                                                , "&"
                                                                , urls.query |> Maybe.withDefault ""
                                                                ]
                                                                    |> String.concat
                                                            , method = method
                                                            }
                                                        , secure = True
                                                        }
                                              }
                                                |> toOutput
                                            )

                                Err err ->
                                    errorOutput ("Error on decoder " ++ Decode.errorToString err)

                        MetaInputError { error } ->
                            errorOutput ("Input Error: " ++ error)

                Err err ->
                    errorOutput ("Error on decoder " ++ Decode.errorToString err)


type Route
    = ImageAPI
    | Page


checkRoute : String -> String -> Route
checkRoute pattern url =
    if String.startsWith pattern url then
        ImageAPI

    else
        Page
