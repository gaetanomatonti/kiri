use std::{
    slice,
    sync::{Arc, atomic::Ordering},
};

use crate::runtime::completion::*;

/// Swift calls this to check if a request has been cancelled.
#[unsafe(no_mangle)]
pub extern "C" fn kiri_request_is_cancelled(context: *const std::ffi::c_void) -> bool {
    if context.is_null() {
        return true;
    }

    let context = unsafe { Arc::from_raw(context as *const CompletionContext) };
    let cancelled = context.state.load(Ordering::Acquire) == STATE_CANCELLED;
    // We explicitly tell the Arc to not dereference inner.
    // This is necessary for the context to outlive the scope of this functions,
    // and be able to reach the Swift runtime for completion/handling.
    std::mem::forget(context);
    // We could also just peek inside the Inner pointer without Arc to avoid reference counting.
    // let inner: &Inner = unsafe { &*(context as *const Inner) };

    return cancelled;
}

#[unsafe(no_mangle)]
pub extern "C" fn kiri_request_free(context: *const std::ffi::c_void) {
    if context.is_null() {
        return;
    }
    unsafe {
        drop(Arc::from_raw(context as *const CompletionContext));
    }
}

/// This function is called by the Swift runtime to signal that a request has been completed,
/// by passing the completion context, and the response content.
/// **Must be called exactly once.**
#[unsafe(no_mangle)]
pub extern "C" fn kiri_request_complete(
    completion_ctx: *mut std::ffi::c_void,
    resp_ptr: *const u8,
    resp_len: usize,
) {
    if completion_ctx.is_null() || resp_ptr.is_null() {
        return;
    }

    let context = unsafe { Arc::from_raw(completion_ctx as *const CompletionContext) };

    // If the current state of the request is pending, we can safely complete the request.
    let previous_state = context.state.compare_exchange(
        STATE_PENDING,
        STATE_COMPLETED,
        Ordering::AcqRel,
        Ordering::Acquire,
    );

    // If request was already completed or cancelled, we drop the reference.
    if previous_state.is_err() {
        return;
    }

    let bytes = unsafe { slice::from_raw_parts(resp_ptr, resp_len) }.to_vec();

    let mut guard = context.transmitter.blocking_lock();
    if let Some(transmitter) = guard.take() {
        let _ = transmitter.send(bytes);
    }
}
