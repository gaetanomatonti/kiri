use std::sync::{
    Arc,
    atomic::{AtomicU8, Ordering},
};

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

/// A type that cancels the request in the context when dropped.
pub struct CancelOnDrop {
    pub context: Arc<CompletionContext>,
}

impl Drop for CancelOnDrop {
    fn drop(&mut self) {
        // If PENDING transition to CANCELLED.
        let _ = self.context.state.compare_exchange(
            STATE_PENDING,
            STATE_CANCELLED,
            Ordering::AcqRel,
            Ordering::Acquire,
        );
        // There is no need to take the transmitter inside the context,
        // as the future will drop anyway on disconnect, so there is nothing to unblock.
    }
}
