use std::sync::{
    Arc,
    atomic::{AtomicU8, Ordering},
};

use tokio::sync::{Mutex, oneshot};

use crate::{core::types::HandlerId, runtime::completion::*};

pub enum DispatchErr {
    Timeout,
    SwiftDropped,
}

unsafe extern "C" {
    /// Kiri Swift exposes this function to allow other runtimes to dispatch request handling.
    fn swift_dispatch(
        handler_id: HandlerId,
        req_ptr: *const u8,
        req_len: usize,
        completion_ctx: *mut std::ffi::c_void,
        cancellation_handle: *mut std::ffi::c_void,
    );
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
    let cancellation_ptr = Arc::into_raw(context.clone()) as *mut std::ffi::c_void;

    unsafe {
        swift_dispatch(
            handler_id,
            req_frame.as_ptr(),
            req_frame.len(),
            context_ptr,
            cancellation_ptr,
        );
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
