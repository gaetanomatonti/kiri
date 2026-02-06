# syntax=docker/dockerfile:1.7
FROM --platform=linux/arm64 golang:1.22-bookworm AS build
WORKDIR /workspace

COPY bench/gin ./bench/gin

RUN go build -C bench/gin -o /tmp/gin-bench .

FROM --platform=linux/arm64 debian:bookworm-slim
WORKDIR /app
COPY --from=build /tmp/gin-bench /app/gin-bench

EXPOSE 8080
ENTRYPOINT ["/app/gin-bench"]
