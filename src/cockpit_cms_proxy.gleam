import gleam/bit_builder
import gleam/erlang/process
import gleam/erlang/os
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import mist.{Connection, ResponseData}
import gleam/httpc
import gleam/http.{Method, Scheme}
import gleam/string
import gleam/io
import gleam/option.{Option, unwrap}
import gleam/result
import gleam/int

pub type Website {
  Website(
    target_host: String,
    target_port: Int,
    scheme: Scheme,
    method: Method,
    path: String,
  )
}

fn handle_website(config: Website) -> Response(ResponseData) {
  let result =
    request.new()
    |> request.set_scheme(config.scheme)
    |> request.set_method(config.method)
    |> request.set_host(config.target_host)
    |> request.set_port(config.target_port)
    |> request.set_path(config.path)
    |> httpc.send

  case result {
    Ok(r) ->
      response.new(200)
      |> response.set_body(mist.Bytes(bit_builder.from_string(r.body)))
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bit_builder.from_string("<h1>nope</h1>")))
  }
}

type Image {
  Image(
    base_url: String,
    api_token: String,
    path: List(String),
    query: Option(String),
  )
}

fn handle_images(config: Image) -> Response(ResponseData) {
  let url =
    "/api/cockpit/image?token=" <> config.api_token <> "&src=" <> config.base_url <> "/storage/uploads/" <> string.join(
      config.path,
      "/",
    ) <> "&" <> unwrap(config.query, "")

  let result =
    request.new()
    |> request.set_host(string.replace(config.base_url, "https://", ""))
    |> request.set_path(url)
    |> request.set_body(<<>>)
    |> httpc.send_bits

  case result {
    Ok(r) ->
      response.new(200)
      |> response.set_body(mist.Bytes(bit_builder.from_bit_string(r.body)))
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bit_builder.from_string("<h1>nope</h1>")))
  }
}

type Configuration {
  Configuration(
    base_url: String,
    api_token: String,
    target_host: String,
    target_port: Int,
    port: Int,
  )
}

fn load_configuration() -> Result(Configuration, String) {
  case
    result.all([
      os.get_env("COCKPIT_BASE_URL"),
      os.get_env("COCKPIT_API_TOKEN"),
      os.get_env("TARGET_HOST"),
      os.get_env("TARGET_PORT"),
      os.get_env("PORT"),
    ])
  {
    Ok([base_url, api_token, target_host, target_p, p]) ->
      case result.all([int.parse(target_p), int.parse(p)]) {
        Ok([target_port, port]) ->
          Ok(Configuration(base_url, api_token, target_host, target_port, port))
        Error(_) -> Error("Port values are not numbers")
      }
    Error(_) -> Error("Missing environment variables")
  }
}

pub fn main() {
  case load_configuration() {
    Ok(config) -> {
      fn(req: Request(Connection)) -> Response(ResponseData) {
        case request.path_segments(req) {
          ["image", "api", ..path] ->
            handle_images(Image(
              config.base_url,
              config.api_token,
              path,
              req.query,
            ))
          _ ->
            handle_website(Website(
              config.target_host,
              config.target_port,
              req.scheme,
              req.method,
              req.path,
            ))
        }
      }
      |> mist.new
      |> mist.port(config.port)
      |> mist.start_http

      process.sleep_forever()
    }
    Error(message) -> io.print_error(message)
  }
}
