use crate::{
    core::{
        server::run_server,
        types::{HandlerId, Route, SharedRoutes},
    },
    error::set_last_error,
};
use std::{
    sync::{Arc, mpsc},
    thread::{self, JoinHandle},
};
use tokio::sync::{RwLock, oneshot};

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
    handler_id: HandlerId,
) -> i32 {
    if handle.is_null() || pattern_ptr.is_null() {
        return -1;
    }

    let pattern_bytes = unsafe { std::slice::from_raw_parts(pattern_ptr, pattern_len) };
    let pattern = match std::str::from_utf8(pattern_bytes) {
        Ok(s) => s.to_string(),
        Err(_e) => return -2,
    };

    let h = unsafe { &mut *handle };
    let mut routes = h.routes.blocking_write();
    routes.push(Route {
        method,
        pattern,
        handler_id,
    });

    return 0;
}
