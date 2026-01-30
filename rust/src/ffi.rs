use crate::{
    server::run_server,
    types::{Route, SharedRoutes},
};
use std::{
    sync::Arc,
    sync::RwLock,
    thread::{self, JoinHandle},
};
use tokio::sync::oneshot;

#[repr(C)]
pub struct ServerHandle {
    shutdown_transmitter: Option<oneshot::Sender<()>>,
    join: Option<JoinHandle<()>>,
    routes: SharedRoutes,
}

/// Starts the server and returns the server handle
#[unsafe(no_mangle)]
pub extern "C" fn server_start(port: u16) -> *mut ServerHandle {
    println!("[Rust] starting server");

    // Create a channel to send information across the async task.
    // The transmitter transmits the shutdown request (client)
    // and the receiver receives the request.
    let (shutdown_transmitter, shutdown_receiver) = oneshot::channel::<()>();

    let routes: SharedRoutes = Arc::new(RwLock::new(Vec::new()));
    let routes_for_thread = routes.clone();

    // We spawn a new thread for Tokio to run on to create a clear lifetime boundary.
    // Returns the handler needed to wait for the thread to finish its work (join).
    let join_handle = thread::spawn(move || {
        // Pass the receiver to the run_server function to await any shutdown request from the transmitter.
        run_server(port, shutdown_receiver, routes_for_thread);
    });

    // Return a server handle to the client so that it can:
    // - transmit the shutdown request (shutdown_transmitter)
    // - and await for the operation to finish (join)
    let handle = ServerHandle {
        shutdown_transmitter: Some(shutdown_transmitter),
        join: Some(join_handle),
        routes,
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

#[unsafe(no_mangle)]
pub extern "C" fn register_route(
    handle: *mut ServerHandle,
    method: u8,
    pattern_ptr: *const u8,
    pattern_len: usize,
    handler_id: u16,
) -> i32 {
    if handle.is_null() || pattern_ptr.is_null() {
        return -1;
    }

    let pattern_bytes = unsafe { std::slice::from_raw_parts(pattern_ptr, pattern_len) };
    let pattern = match std::str::from_utf8(pattern_bytes) {
        Ok(s) => s.to_string(),
        Err(e) => return -2,
    };

    let h = unsafe { &mut *handle };
    let mut routes = h.routes.write().unwrap();
    routes.push(Route {
        method,
        pattern,
        handler_id,
    });

    return 0;
}
