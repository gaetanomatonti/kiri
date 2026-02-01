use std::sync::Arc;
use tokio::sync::RwLock;

pub type Port = u16;
pub type StatusCode = u16;
pub type HandlerId = u64;

#[derive(Clone)]
pub struct Route {
    pub method: u8,
    pub pattern: String,
    pub handler_id: HandlerId,
}

pub type SharedRoutes = Arc<RwLock<Vec<Route>>>;
