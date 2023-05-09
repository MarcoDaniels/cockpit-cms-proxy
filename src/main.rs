use do_notation::m;
use std::convert::Infallible;
use std::env;
use std::net::SocketAddr;

use hyper::client::HttpConnector;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Client, Error, Request, Response, Server, StatusCode, Uri};
use hyper_tls::HttpsConnector;

// TODO:
//  - remove unwraps and await?

async fn handle(request: Request<Body>) -> Result<Response<Body>, Error> {
    let path: &str = request.uri().path();
    let client: Client<HttpConnector> = Client::new();

    return if path.starts_with("/image/api") {
        println!("Fetching images {}", path);

        handle_images(request).await
    } else {
        println!("Fetch website {}", path);

        handle_website(request, client).await
    };
}

async fn handle_images(
    request: Request<Body>,
) -> Result<Response<Body>, Error> {
    let base_url= env::var("COCKPIT_BASE_URL").unwrap();
    let api_token = env::var("COCKPIT_API_TOKEN").unwrap();
    let path_pattern = env::var("ASSET_PATH_PATTERN").unwrap();

    let https = HttpsConnector::new();
    let client = Client::builder().build::<_, hyper::Body>(https);

    let image_path = request.uri().path().replace(&path_pattern, "");

    let path = format!(
        "/api/cockpit/image?token={}&src={}/storage/uploads{}&{}",
        api_token,
        base_url,
        image_path,
        request.uri().query().get_or_insert("")
    );

    let image_url = Uri::builder()
        .scheme("https")
        .authority(base_url.replace("https://", ""))
        .path_and_query(path)
        .build()
        .unwrap();

    let response = client.get(image_url).await?;

    Ok(response)
}

async fn handle_website(
    request: Request<Body>,
    client: Client<HttpConnector>,
) -> Result<Response<Body>, Error> {
    let target_host = env::var("TARGET_HOST").unwrap();
    let target_port = env::var("TARGET_PORT").unwrap();

    match m! {
        uri <- Uri::builder()
            .scheme("http")
            .authority(format!("{}:{}", target_host, target_port))
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

            Ok(response)
        }
        Err(e) => Ok(Response::builder()
            .status(StatusCode::INTERNAL_SERVER_ERROR)
            .body(format!("Error: {}", e).into())
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
