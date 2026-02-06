# syntax=docker/dockerfile:1.7
FROM --platform=linux/arm64 swift:6.2-jammy AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY bench/vapor/app ./bench/vapor/app

RUN swift build --package-path bench/vapor/app -c release --product VaporBench
RUN BIN="$(find bench/vapor/app/.build -type f -path '*/release/VaporBench' | head -n1)" \
  && cp "$BIN" /tmp/VaporBench

FROM --platform=linux/arm64 swift:6.2-jammy
WORKDIR /app
COPY --from=build /tmp/VaporBench /app/VaporBench

EXPOSE 8080
ENTRYPOINT ["/app/VaporBench"]
