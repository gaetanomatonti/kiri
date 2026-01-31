use std::sync::atomic::AtomicU8;

use tokio::sync::{Mutex, oneshot};

pub const STATE_PENDING: u8 = 0;
pub const STATE_COMPLETED: u8 = 1;
pub const STATE_CANCELLED: u8 = 2;

/// Context containing the transmitter used to send the response of the handled request.
pub struct CompletionContext {
    /// The state of the request.
    /// Possible values:
    /// - STATE_PENDING = 0
    /// - STATE_COMPLETED = 1
    /// - STATE_CANCELLED = 2
    pub state: AtomicU8,
    /// Use this transmitter to send the response of the request handled by the Swift runtime.
    pub transmitter: Mutex<Option<oneshot::Sender<Vec<u8>>>>,
}
