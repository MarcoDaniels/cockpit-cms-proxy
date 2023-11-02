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
  Website(config: Configuration, scheme: Scheme, method: Method, path: String)
}

fn handle_website(handler: Website) -> Response(ResponseData) {
  let result =
    request.new()
    |> request.set_scheme(handler.scheme)
    |> request.set_method(handler.method)
    |> request.set_host(handler.config.target_host)
    |> request.set_port(handler.config.target_port)
    |> request.set_path(handler.path)
    |> httpc.send

  case result {
    Ok(r) ->
      response.new(200)
      |> response.set_body(mist.Bytes(bit_builder.from_string(r.body)))
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bit_builder.from_string(
        "<h1>Not Found</h1><p>Website route " <> handler.path <> "`` not found</p>",
      )))
  }
}

type Image {
  Image(config: Configuration, path: List(String), query: Option(String))
}

fn handle_images(handler: Image) -> Response(ResponseData) {
  let url =
    "/api/cockpit/image?token=" <> handler.config.api_token <> "&src=" <> handler.config.base_url <> "/storage/uploads/" <> string.join(
      handler.path,
      "/",
    ) <> "&" <> unwrap(handler.query, "")

  let result =
    request.new()
    |> request.set_host(string.replace(handler.config.base_url, "https://", ""))
    |> request.set_path(url)
    |> request.set_body(<<>>)
    |> httpc.send_bits

  case result {
    Ok(r) ->
      response.new(200)
      |> response.set_body(mist.Bytes(bit_builder.from_bit_string(r.body)))
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bit_builder.from_string(
        "<h1>Not Found</h1><p>Image " <> handler.path <> "`` not found</p>",
      )))
  }
}

pub type Configuration {
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
            handle_images(Image(config, path, req.query))
          _ -> handle_website(Website(config, req.scheme, req.method, req.path))
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
