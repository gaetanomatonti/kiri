use std::sync::atomic::{AtomicBool, Ordering};

use tokio::sync::RwLock;

use crate::core::types::Route;

pub struct RouterHandle {
    pub routes: RwLock<Vec<Route>>,
    pub frozen: AtomicBool,
}

impl RouterHandle {
    pub fn new() -> RouterHandle {
        RouterHandle {
            routes: RwLock::new(Vec::new()),
            frozen: AtomicBool::new(false),
        }
    }

    /// Freezes the routes.
    /// Returns true if we froze now, false if already frozen.
    pub fn freeze(&self) -> bool {
        !self.frozen.swap(true, Ordering::AcqRel)
    }

    pub fn is_frozen(&self) -> bool {
        self.frozen.load(Ordering::Acquire)
    }
}
