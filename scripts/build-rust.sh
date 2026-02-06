#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${1:-release}"

PROFILE="release"
CARGO_FLAGS=()

case "$MODE" in
  release)
    PROFILE="release"
    CARGO_FLAGS=(--release)
    ;;
  debug)
    PROFILE="debug"
    CARGO_FLAGS=()
    ;;
  bench)
    PROFILE="release"
    CARGO_FLAGS=(--release --features bench)
    ;;
  *)
    echo "Usage: $0 [release|debug|bench]"
    exit 1
    ;;
esac

echo "Building libkiri_ffi (${MODE})."

(
  cd "$ROOT_DIR"
  cargo build "${CARGO_FLAGS[@]}"
)

LIB_PATH="${ROOT_DIR}/target/${PROFILE}/libkiri_ffi.a"
TARGET_PATH="${ROOT_DIR}/artifacts"

mkdir -p "$TARGET_PATH"
cp -f "$LIB_PATH" "${TARGET_PATH}/libkiri_ffi.a"

echo "Built ${TARGET_PATH}/libkiri_ffi.a from ${MODE} (${PROFILE}) build."
