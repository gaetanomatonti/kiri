use std::slice;

use tokio::sync::oneshot;

unsafe extern "C" {
    fn swift_dispatch(
        handler_id: u16,
        req_ptr: *const u8,
        req_len: usize,
        completion_ctx: *mut std::ffi::c_void,
    );
}

struct CompletionContext {
    tx: Option<oneshot::Sender<Vec<u8>>>,
}

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

    if let Some(tx) = boxed.tx.take() {
        let _ = tx.send(bytes);
    }
}

pub async fn dispatch_to_swift(handler_id: u16, req_frame: &[u8]) -> Result<Vec<u8>, ()> {
    let (tx, rx) = oneshot::channel::<Vec<u8>>();
    let context = Box::new(CompletionContext { tx: Some(tx) });
    let context_ptr = Box::into_raw(context) as *mut std::ffi::c_void;

    unsafe {
        swift_dispatch(handler_id, req_frame.as_ptr(), req_frame.len(), context_ptr);
    }

    rx.await.map_err(|_| ())
}
