# syntax=docker/dockerfile:1.7
FROM --platform=linux/arm64 rust:1.84-bookworm AS build
WORKDIR /workspace

COPY bench/axum ./bench/axum

RUN cargo build --release --manifest-path bench/axum/Cargo.toml

FROM --platform=linux/arm64 debian:bookworm-slim
WORKDIR /app
COPY --from=build /workspace/bench/axum/target/release/axum-bench /app/axum-bench

EXPOSE 8080
ENTRYPOINT ["/app/axum-bench"]
