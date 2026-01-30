use hyper::{
    Body, Request, Response, Server,
    service::{make_service_fn, service_fn},
};
use std::net::SocketAddr;
use tokio::sync::oneshot;

use crate::{
    frames,
    router::{self},
    swift_dispatch,
    types::SharedRoutes,
};

async fn handle(
    request: Request<Body>,
    routes: SharedRoutes,
) -> Result<Response<Body>, hyper::Error> {
    let method = router::method_to_u8(request.method());
    let path = request.uri().path().to_string();

    let handler_id = routes
        .read()
        .await
        .iter()
        .find(|r| r.method == method && router::matches(&r.pattern, &path))
        .map(|r| r.handler_id);

    let handler_id = match handler_id {
        Some(id) => id,
        None => {
            let mut response = Response::new(Body::from("not found\n"));
            *response.status_mut() = hyper::StatusCode::NOT_FOUND;
            return Ok(response);
        }
    };

    let body_bytes = hyper::body::to_bytes(request.into_body()).await?;
    let request_frame = frames::encode_request(method, &path, &body_bytes);

    let response_frame = match swift_dispatch::dispatch_to_swift(handler_id, &request_frame).await {
        Ok(b) => b,
        Err(_) => {
            let mut response = Response::new(Body::from("swift dispatch failed\n"));
            *response.status_mut() = hyper::StatusCode::INTERNAL_SERVER_ERROR;
            return Ok(response);
        }
    };

    let (status, body) = match frames::decode_response(&response_frame) {
        Some(v) => v,
        None => {
            let mut response = Response::new(Body::from("invalid response frame\n"));
            *response.status_mut() = hyper::StatusCode::INTERNAL_SERVER_ERROR;
            return Ok(response);
        }
    };

    let mut response = Response::new(Body::from(body));
    *response.status_mut() =
        hyper::StatusCode::from_u16(status).unwrap_or(hyper::StatusCode::INTERNAL_SERVER_ERROR);
    return Ok(response);
}

pub fn run_server(port: u16, shutdown_receiver: oneshot::Receiver<()>, routes: SharedRoutes) {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed toclear build Tokio runtime");

    runtime.block_on(async move {
        let address = SocketAddr::from(([127, 0, 0, 1], port));

        let make_svc = make_service_fn(move |_connection| {
            let routes = routes.clone();
            async move {
                Ok::<_, hyper::Error>(service_fn(move |request| handle(request, routes.clone())))
            }
        });

        let server = Server::bind(&address).serve(make_svc);

        let graceful = server.with_graceful_shutdown(async move {
            // When the shutdown request is received, shut the server down gracefully.
            let _ = shutdown_receiver.await;
            println!("[Rust] stopping server");
        });

        if let Err(e) = graceful.await {
            eprintln!("[Rust] server error: {e}");
        }
    })
}
