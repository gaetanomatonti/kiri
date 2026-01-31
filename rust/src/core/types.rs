use std::sync::Arc;
use tokio::sync::RwLock;

pub type HandlerId = u16;

#[derive(Clone)]
pub struct Route {
    pub method: u8,
    pub pattern: String,
    pub handler_id: HandlerId,
}

pub type SharedRoutes = Arc<RwLock<Vec<Route>>>;
