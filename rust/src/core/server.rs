use std::{
    net::SocketAddr,
    sync::mpsc,
    thread::{self, JoinHandle},
};

use hyper::{
    Body, Request, Response, Server,
    service::{make_service_fn, service_fn},
};
use tokio::sync::oneshot;

use crate::{
    core::{frames, router, types::SharedRoutes},
    error::set_last_error,
    runtime::dispatch,
};

pub struct ServerHandle {
    pub shutdown_transmitter: Option<oneshot::Sender<()>>,
    pub join: Option<JoinHandle<()>>,
    pub routes: SharedRoutes,
}

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

    let response_frame = match dispatch::dispatch_to_swift(handler_id, &request_frame).await {
        Ok(b) => b,
        Err(dispatch::DispatchErr::Timeout) => {
            let mut response = Response::new(Body::from("timeout\n"));
            *response.status_mut() = hyper::StatusCode::GATEWAY_TIMEOUT;
            return Ok(response);
        }
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

pub fn start_server(port: u16, routes: SharedRoutes) -> *mut ServerHandle {
    println!("[Rust] starting server");

    // Create a channel to send information across the async task.
    // The transmitter transmits the shutdown request (client)
    // and the receiver receives the request.
    let (shutdown_transmitter, shutdown_receiver) = oneshot::channel::<()>();

    let routes_for_thread = routes.clone();

    let (ready_transmitter, ready_receiver) = mpsc::channel::<Result<(), String>>();

    // We spawn a new thread for Tokio to run on to create a clear lifetime boundary.
    // Returns the handler needed to wait for the thread to finish its work (join).
    let join_handle = thread::spawn(move || {
        // Pass the receiver to the run_server function to await any shutdown request from the transmitter.
        run_server(
            port,
            shutdown_receiver,
            routes_for_thread,
            ready_transmitter,
        );
    });

    match ready_receiver.recv() {
        Ok(Ok(())) => {
            // Return a server handle to the client so that it can:
            // - transmit the shutdown request (shutdown_transmitter)
            // - and await for the operation to finish (join)
            let handle = ServerHandle {
                shutdown_transmitter: Some(shutdown_transmitter),
                join: Some(join_handle),
                routes,
            };

            Box::into_raw(Box::new(handle))
        }
        Ok(Err(message)) => {
            set_last_error(format!("Failed to start server: {}", message));
            let _ = join_handle.join();
            std::ptr::null_mut()
        }
        Err(_) => {
            set_last_error(
                "Failed to start server: internal error (startup channel closed)".to_string(),
            );
            let _ = join_handle.join();
            std::ptr::null_mut()
        }
    }
}

pub fn run_server(
    port: u16,
    shutdown_receiver: oneshot::Receiver<()>,
    routes: SharedRoutes,
    ready_transmitter: mpsc::Sender<Result<(), String>>,
) {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed toclear build Tokio runtime");

    runtime.block_on(async move {
        let address = SocketAddr::from(([127, 0, 0, 1], port));

        let builder = match Server::try_bind(&address) {
            Ok(builder) => {
                let _ = ready_transmitter.send(Ok(()));
                builder
            }
            Err(e) => {
                let _ = ready_transmitter.send(Err(format!("bind {} failed: {}", address, e)));
                return;
            }
        };

        let make_service = make_service_fn(move |_connection| {
            let routes = routes.clone();
            async move {
                Ok::<_, hyper::Error>(service_fn(move |request| handle(request, routes.clone())))
            }
        });

        let server = builder.serve(make_service);
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
