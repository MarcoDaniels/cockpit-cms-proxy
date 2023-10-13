import gleam/bit_builder
import gleam/erlang/process
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import mist.{Connection, ResponseData}
import gleam/httpc
import gleam/http.{Get, Http}
import gleam/string.{join}

fn handle_website(segments: List(String)) -> Response(ResponseData) {
  let result =
    request.new()
    |> request.set_scheme(Http)
    |> request.set_method(Get)
    |> request.set_host("localhost")
    |> request.set_port(1234)
    |> request.set_path(join(segments, "/"))
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

pub fn main() {
  fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      _ as segments -> handle_website(segments)
    }
  }
  |> mist.new
  |> mist.port(8000)
  |> mist.start_http

  process.sleep_forever()
}
