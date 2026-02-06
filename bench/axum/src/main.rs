use axum::{
    http::{header, StatusCode},
    response::IntoResponse,
    routing::get,
    Router,
};
use std::net::SocketAddr;
use tokio::net::TcpListener;

async fn noop() -> StatusCode {
    StatusCode::NO_CONTENT
}

async fn plaintext() -> impl IntoResponse {
    (
        [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
        "Hello, World!",
    )
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/noop", get(noop))
        .route("/plaintext", get(plaintext));

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    let listener = TcpListener::bind(addr)
        .await
        .expect("failed to bind on 0.0.0.0:8080");

    println!("Server running on port: {}", addr.port());

    axum::serve(listener, app)
        .await
        .expect("axum server failed");
}
