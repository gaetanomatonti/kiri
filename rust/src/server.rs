use hyper::{
    Body, Request, Response, Server,
    service::{make_service_fn, service_fn},
};
use std::net::SocketAddr;
use tokio::sync::oneshot;

use crate::{
    router,
    types::{Route, SharedRoutes},
};

async fn handle(
    request: Request<Body>,
    routes: SharedRoutes,
) -> Result<Response<Body>, hyper::Error> {
    let method = router::method_to_u8(request.method());
    let path = request.uri().path();

    let guard = routes.read().unwrap();
    let route = guard
        .iter()
        .find(|r: &&Route| r.method == method && router::matches(&r.pattern, path));

    if let Some(route) = route {
        let body = format!("matched handlerId={}\n", route.handler_id);
        return Ok(Response::new(Body::from(body)));
    }

    let mut response = Response::new(Body::from("not found\n"));
    *response.status_mut() = hyper::StatusCode::NOT_FOUND;
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
