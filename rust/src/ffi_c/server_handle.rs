use std::{os::raw::c_void, sync::Arc};

use tokio::sync::RwLock;

use crate::{
    core::{
        arc::arc_from_borrowed_ptr,
        router_handle::RouterHandle,
        server::{ServerHandle, start_server},
        types::{Port, SharedRoutes},
    },
    error::set_last_error,
};

/// Starts the server with empty routes and returns the server handle.
/// Available for backwards compatibility.
#[unsafe(no_mangle)]
pub extern "C" fn kiri_server_start(port: Port) -> *mut ServerHandle {
    let routes: SharedRoutes = Arc::new(RwLock::new(Vec::new()));
    start_server(port, routes)
}

/// Starts the server and returns the server handle.
#[unsafe(no_mangle)]
pub extern "C" fn kiri_server_start_with_router(
    port: Port,
    router: *const c_void,
) -> *mut ServerHandle {
    if router.is_null() {
        set_last_error("router is null".to_string());
        return std::ptr::null_mut();
    }

    let router = unsafe { arc_from_borrowed_ptr(router as *const RouterHandle) };

    // Freeze the router to prevent new routes from being added.
    router.freeze();

    let snapshot = {
        let guard = router.routes.blocking_read();
        guard.clone()
    };

    let routes: SharedRoutes = Arc::new(RwLock::new(snapshot));

    start_server(port, routes)
}

/// Stops the server managed by the passed handle
#[unsafe(no_mangle)]
pub extern "C" fn kiri_server_stop(handle: *mut ServerHandle) {
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
