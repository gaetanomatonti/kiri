use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct Route {
    pub method: u8,
    pub pattern: String,
    pub handler_id: u16,
}

pub type SharedRoutes = Arc<RwLock<Vec<Route>>>;
