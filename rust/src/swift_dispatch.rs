use std::slice;

use tokio::sync::oneshot;

use crate::types::HandlerId;

unsafe extern "C" {
    /// Kiri Swift exposes this function to allow other runtimes to dispatch request handling.
    fn swift_dispatch(
        handler_id: HandlerId,
        req_ptr: *const u8,
        req_len: usize,
        completion_ctx: *mut std::ffi::c_void,
    );
}

/// Context containing the transmitter used to send the response of the handled request.
struct CompletionContext {
    /// Use this transmitter to send the response of the request handled by the Swift runtime.
    transmitter: Option<oneshot::Sender<Vec<u8>>>,
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

    let mut boxed: Box<CompletionContext> =
        unsafe { Box::from_raw(completion_ctx as *mut CompletionContext) };

    let bytes = unsafe { slice::from_raw_parts(resp_ptr, resp_len) }.to_vec();

    if let Some(transmitter) = boxed.transmitter.take() {
        let _ = transmitter.send(bytes);
    }
}

/// Delegates the handling of the request to the Swift runtime.
pub async fn dispatch_to_swift(handler_id: HandlerId, req_frame: &[u8]) -> Result<Vec<u8>, ()> {
    let (transmitter, receiver) = oneshot::channel::<Vec<u8>>();

    // In this case, we use Box (single ownership) because only the Swift runtime is responsible for freeing the completion context.
    // This will be changed to Arc (shared ownership) when we introduce cancellation/timeout from Rust.
    let context = Box::new(CompletionContext {
        transmitter: Some(transmitter),
    });
    // We get the pointer to the Box, and pass it to the Swift runtime,
    // so that we can retrieve it back when Swift notifies the completion, and we can free the context inside the Box.
    let context_ptr = Box::into_raw(context) as *mut std::ffi::c_void;

    unsafe {
        swift_dispatch(handler_id, req_frame.as_ptr(), req_frame.len(), context_ptr);
    }

    receiver.await.map_err(|_| ())
}
