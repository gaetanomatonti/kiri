# syntax=docker/dockerfile:1.7
FROM --platform=linux/arm64 swift:6.2-jammy AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  pkg-config \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl -sSf https://sh.rustup.rs \
  | bash -s -- -y --profile minimal \
  && /root/.cargo/bin/rustup default stable

ENV PATH="/root/.cargo/bin:${PATH}"
WORKDIR /workspace

COPY . .

RUN bash scripts/build-rust.sh bench
RUN swift package --package-path swift clean
RUN swift build --package-path swift -c release --product KiriBench
RUN BIN="$(find swift/.build -type f -path '*/release/KiriBench' | head -n1)" \
  && cp "$BIN" /tmp/KiriBench

FROM --platform=linux/arm64 swift:6.2-jammy
WORKDIR /app
COPY --from=build /tmp/KiriBench /app/KiriBench

EXPOSE 8080
ENV KIRI_BIND_HOST=0.0.0.0

ENTRYPOINT ["/app/KiriBench"]
