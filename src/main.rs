use std::convert::Infallible;
use std::net::SocketAddr;

use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Client, Request, Response, Server, StatusCode};

async fn handle(_: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    let client = Client::new();

    match Request::builder()
        .method(hyper::Method::GET)
        .uri("http://localhost:1234")
        .body(Body::empty())
    {
        Ok(request) => {
            let response = client.request(request).await?;

            let body_byes = hyper::body::to_bytes(response.into_body()).await?;

            Ok(Response::builder()
                .status(StatusCode::OK)
                .body(Body::from(body_byes))
                .unwrap())
        }
        Err(_) => Ok(Response::builder()
            .status(StatusCode::INTERNAL_SERVER_ERROR)
            .body(Body::empty())
            .unwrap()),
    }
}

#[tokio::main]
async fn main() {
    let address = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on http://localhost:{}", address);

    let make_service = make_service_fn(|_| async { Ok::<_, Infallible>(service_fn(handle)) });

    let server = Server::bind(&address).serve(make_service);

    if let Err(e) = server.await {
        println!("error: {}", e)
    }
}
