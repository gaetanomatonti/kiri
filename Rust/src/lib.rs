use std::{
    net::SocketAddr,
    thread::{self, JoinHandle},
};

use hyper::{
    Body, Request, Response, Server,
    service::{make_service_fn, service_fn},
};

use tokio::sync::oneshot;

#[repr(C)]
pub struct ServerHandle {
    shutdown_transmitter: Option<oneshot::Sender<()>>,
    join: Option<JoinHandle<()>>,
}

async fn handle(_req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    Ok(Response::new(Body::from("OK\n")))
}

fn run_server(port: u16, shutdown_receiver: oneshot::Receiver<()>) {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to build Tokio runtime");

    runtime.block_on(async move {
        let address = SocketAddr::from(([127, 0, 0, 1], port));

        let make_svc =
            make_service_fn(|_connection| async { Ok::<_, hyper::Error>(service_fn(handle)) });

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

/// Starts the server and returns the server handle
#[unsafe(no_mangle)]
pub extern "C" fn server_start(port: u16) -> *mut ServerHandle {
    println!("[Rust] starting server");

    // Create a channel to send information across the async task.
    // The transmitter transmits the shutdown request (client)
    // and the receiver receives the request.
    let (shutdown_transmitter, shutdown_receiver) = oneshot::channel::<()>();

    // We spawn a new thread for Tokio to run on to create a clear lifetime boundary.
    // Returns the handler needed to wait for the thread to finish its work (join).
    let join_handle = thread::spawn(move || {
        // Pass the receiver to the run_server function to await any shutdown request from the transmitter.
        run_server(port, shutdown_receiver);
    });

    // Return a server handle to the client so that it can:
    // - transmit the shutdown request (shutdown_transmitter)
    // - and await for the operation to finish (join)
    let handle = ServerHandle {
        shutdown_transmitter: Some(shutdown_transmitter),
        join: Some(join_handle),
    };

    return Box::into_raw(Box::new(handle));
}

/// Stops the server managed by the passed handle
#[unsafe(no_mangle)]
pub extern "C" fn server_stop(handle: *mut ServerHandle) {
    if handle.is_null() {
        return;
    }

    let mut boxed = unsafe { Box::from_raw(handle) };

    if let Some(transmitter) = boxed.shutdown_transmitter.take() {
        let _ = transmitter.send(());
    }

    if let Some(join) = boxed.join.take() {
        let _ = join.join();
    }
}
