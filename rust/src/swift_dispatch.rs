use std::{
    slice,
    sync::{
        Arc,
        atomic::{AtomicU8, Ordering},
    },
};

use tokio::sync::{Mutex, oneshot};

use crate::types::HandlerId;

const STATE_PENDING: u8 = 0;
const STATE_COMPLETED: u8 = 1;
const STATE_CANCELLED: u8 = 2;

pub enum DispatchErr {
    Timeout,
    SwiftDropped,
}

/// Context containing the transmitter used to send the response of the handled request.
struct CompletionContext {
    /// The state of the request.
    /// Possible values:
    /// - STATE_PENDING = 0
    /// - STATE_COMPLETED = 1
    /// - STATE_CANCELLED = 2
    state: AtomicU8,
    /// Use this transmitter to send the response of the request handled by the Swift runtime.
    transmitter: Mutex<Option<oneshot::Sender<Vec<u8>>>>,
}

unsafe extern "C" {
    /// Kiri Swift exposes this function to allow other runtimes to dispatch request handling.
    fn swift_dispatch(
        handler_id: HandlerId,
        req_ptr: *const u8,
        req_len: usize,
        completion_ctx: *mut std::ffi::c_void,
    );
}

/// Swift calls this to check if a request has been cancelled.
#[unsafe(no_mangle)]
pub extern "C" fn rust_is_cancelled(context: *const std::ffi::c_void) -> bool {
    if context.is_null() {
        return true;
    }

    let inner = unsafe { Arc::from_raw(context as *const CompletionContext) };
    let cancelled = inner.state.load(Ordering::Acquire) == STATE_CANCELLED;
    // We explicitly tell the Arc to not dereference inner.
    // This is necessary for the context to outlive the scope of this functions,
    // and be able to reach the Swift runtime for completion/handling.
    std::mem::forget(inner);
    // We could also just peek inside the Inner pointer without Arc to avoid reference counting.
    // let inner: &Inner = unsafe { &*(context as *const Inner) };

    return cancelled;
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_release(context: *const std::ffi::c_void) {
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
pub extern "C" fn rust_complete(
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

/// Delegates the handling of the request to the Swift runtime.
pub async fn dispatch_to_swift(
    handler_id: HandlerId,
    req_frame: &[u8],
) -> Result<Vec<u8>, DispatchErr> {
    let (transmitter, receiver) = oneshot::channel::<Vec<u8>>();

    let context = Arc::new(CompletionContext {
        state: AtomicU8::new(STATE_PENDING),
        transmitter: Mutex::new(Some(transmitter)),
    });

    // Clone the context so that Rust keeps owning it, while passing a reference to Swift as well.
    // This is needed because into_raw would move the context variable,
    // and we wouldn't be able to use the context for cancellation logic from Rust.
    let context_ptr = Arc::into_raw(context.clone()) as *mut std::ffi::c_void;

    unsafe {
        swift_dispatch(handler_id, req_frame.as_ptr(), req_frame.len(), context_ptr);
    }

    let timeout = std::time::Duration::from_secs(5);
    let tokio_response = tokio::time::timeout(timeout, receiver).await;

    if let Err(_elapsed) = tokio_response {
        context.state.store(STATE_CANCELLED, Ordering::Release);

        let mut guard = context.transmitter.lock().await;
        let _ = guard.take();
        return Err(DispatchErr::Timeout);
    } else {
        let response = tokio_response.unwrap();
        match response {
            Ok(bytes) => Ok(bytes),
            Err(_recv_closed) => Err(DispatchErr::SwiftDropped),
        }
    }
}
