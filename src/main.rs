use do_notation::m;
use std::convert::Infallible;
use std::net::SocketAddr;

use hyper::body::Bytes;
use hyper::client::HttpConnector;
use hyper::service::{make_service_fn, service_fn};
use hyper::{body, Body, Client, Error, Request, Response, Server, StatusCode, Uri};

// TODO:
//  - remove unwraps and await?
//  - use environment for ports, image path, auth

async fn handle(request: Request<Body>) -> Result<Response<Body>, Error> {
    let path: &str = request.uri().path();
    let client: Client<HttpConnector> = Client::new();

    return if path.starts_with("/image/api") {
        println!("Fetching images {}", request.uri());

        Ok(Response::builder()
            .status(StatusCode::INTERNAL_SERVER_ERROR)
            .body(Body::empty())
            .unwrap())
    } else {
        println!("Fetch website {}", path);

        handle_website(request, client).await
    };
}

async fn handle_website(
    request: Request<Body>,
    client: Client<HttpConnector>,
) -> Result<Response<Body>, Error> {
    match m! {
        uri <- Uri::builder()
            .scheme("http")
            .authority("localhost:1234")
            .path_and_query(request.uri().path())
            .build();
        request <- Request::builder()
            .method(request.method())
            .uri(uri)
            .body(Body::empty());
        Ok(request)
    } {
        Ok(web_request) => {
            let response: Response<Body> = client.request(web_request).await?;

            let body_byes: Bytes = body::to_bytes(response.into_body()).await?;

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
    let address: SocketAddr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on http://{}", address);

    let server = Server::bind(&address).serve(make_service_fn(|_| async {
        Ok::<_, Infallible>(service_fn(handle))
    }));

    if let Err(e) = server.await {
        println!("error: {}", e)
    }
}
