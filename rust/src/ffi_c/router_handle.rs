use std::{os::raw::c_void, sync::Arc};

use crate::core::{
    arc::arc_from_borrowed_ptr,
    router_handle::RouterHandle,
    types::{HandlerId, Route},
};

#[unsafe(no_mangle)]
pub extern "C" fn kiri_router_create() -> *mut c_void {
    let router = Arc::new(RouterHandle::new());
    Arc::into_raw(router) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn kiri_router_free(router: *const c_void) {
    if router.is_null() {
        return;
    }

    unsafe {
        drop(Arc::from_raw(router as *const RouterHandle));
    }
}

/// Returns 0 on success, non-zero on failures.
#[unsafe(no_mangle)]
pub extern "C" fn kiri_router_register_route(
    router: *const c_void,
    method: u8,
    pattern_ptr: *const u8,
    pattern_len: usize,
    handler_id: HandlerId,
) -> i32 {
    if router.is_null() || pattern_ptr.is_null() {
        return 1;
    }

    // Swift owns the Router, so we borrow the pointer and avoid dropping it.
    let router = unsafe { arc_from_borrowed_ptr(router as *const RouterHandle) };

    if router.is_frozen() {
        return 2;
    }

    let pattern_bytes = unsafe { std::slice::from_raw_parts(pattern_ptr, pattern_len) };
    let pattern = match std::str::from_utf8(pattern_bytes) {
        Ok(s) => s.to_string(),
        Err(_e) => {
            return 3;
        }
    };

    let mut routes = router.routes.blocking_write();
    routes.push(Route {
        method,
        pattern,
        handler_id,
    });

    return 0;
}
