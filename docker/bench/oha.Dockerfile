# syntax=docker/dockerfile:1.7
FROM --platform=linux/arm64 rust:1-bookworm AS build

RUN cargo install --locked oha

FROM --platform=linux/arm64 debian:bookworm-slim
COPY --from=build /usr/local/cargo/bin/oha /usr/local/bin/oha

ENTRYPOINT ["/usr/local/bin/oha"]
