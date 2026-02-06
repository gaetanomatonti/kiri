#!/usr/bin/env bash

# If invoked with `sh`, restart with bash so arrays and other bash features work.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

OUT_DIR="scripts/bench/.out"
MODE="${1:-full}"
FRAMEWORK="${2:-all}"

case "$MODE" in
  light) RUNS=1 ;;
  full) RUNS=3 ;;
  *)
    echo "Usage: $0 [light|full] [all|kiri|axum|vapor]"
    exit 1
    ;;
esac

case "$FRAMEWORK" in
  all|kiri|axum|vapor) ;;
  *)
    echo "Usage: $0 [light|full] [all|kiri|axum|vapor]"
    exit 1
    ;;
esac

# same configuration as Web Frameworks Benchmark
THREADS_LIST=(8)
CONNS_LIST=(64 256 512)
DURATION=15

BASE_URL="http://127.0.0.1:8080"

KIRI_ENDPOINTS=(
  "kiri-rust:plaintext:/__rust/plaintext"
  "kiri-rust:noop:/__rust/noop"
  "kiri-swift:plaintext:/plaintext"
  "kiri-swift:noop:/noop"
)

AXUM_ENDPOINTS=(
  "axum:plaintext:/plaintext"
  "axum:noop:/noop"
)

VAPOR_ENDPOINTS=(
  "vapor:plaintext:/plaintext"
  "vapor:noop:/noop"
)

mkdir -p "$OUT_DIR"
SERVER_PID=""

stop_server() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

trap stop_server EXIT

wait_for_server() {
  local path="$1"
  local tries=30
  local i
  for i in $(seq 1 "$tries"); do
    if curl -fsS "${BASE_URL}${path}" > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Server did not become ready on ${BASE_URL}${path}"
  return 1
}

build_kiri() {
  scripts/build-rust.sh bench
  # Force relink against updated artifacts/libkiri_ffi.a.
  swift package --package-path swift clean
  swift build --package-path swift -c release --product KiriBench
}

start_kiri() {
  local bin="swift/.build/release/KiriBench"

  if [[ ! -x "$bin" ]]; then
    bin="$(find swift/.build -type f -path "*/release/KiriBench" | head -n1)"
  fi
  if [[ -z "$bin" || ! -x "$bin" ]]; then
    echo "Could not find KiriBench release binary"
    exit 1
  fi

  "$bin" &
  SERVER_PID=$!
}

build_axum() {
  cargo build --release --manifest-path bench/axum/Cargo.toml
}

start_axum() {
  bench/axum/target/release/axum-bench &
  SERVER_PID=$!
}

build_vapor() {
  swift build --package-path bench/vapor/app -c release --product VaporBench
}

start_vapor() {
  local bin="bench/vapor/app/.build/release/VaporBench"
  if [[ ! -x "$bin" ]]; then
    bin="$(find bench/vapor/app/.build -type f -path "*/release/VaporBench" | head -n1)"
  fi
  if [[ -z "$bin" || ! -x "$bin" ]]; then
    echo "Could not find VaporBench release binary"
    exit 1
  fi

  "$bin" &
  SERVER_PID=$!
}

run_wrk () {
  local impl="$1"
  local endpoint="$2"
  local path="$3"
  local threads="$4"
  local conns="$5"
  local run="$6"

  local file="${OUT_DIR}/wrk__${impl}__${endpoint}__t${threads}__c${conns}__d${DURATION}__run${run}.txt"

  echo ">> wrk ${impl}/${endpoint} t=${threads} c=${conns} run=${run}"
  # capture everything
  wrk -t"$threads" -c"$conns" -d"${DURATION}s" "${BASE_URL}${path}" > "$file" 2>&1
}

run_framework() {
  local framework="$1"
  local build_fn="$2"
  local start_fn="$3"
  local endpoints_var="$4"
  local endpoints=()

  case "$endpoints_var" in
    KIRI_ENDPOINTS) endpoints=("${KIRI_ENDPOINTS[@]}") ;;
    AXUM_ENDPOINTS) endpoints=("${AXUM_ENDPOINTS[@]}") ;;
    VAPOR_ENDPOINTS) endpoints=("${VAPOR_ENDPOINTS[@]}") ;;
    *)
      echo "Unknown endpoint set: ${endpoints_var}"
      exit 1
      ;;
  esac

  echo "== Benchmarking ${framework} (mode=${MODE}, runs=${RUNS}) =="

  "$build_fn"
  "$start_fn"
  echo "Server PID: ${SERVER_PID}"

  local warmup_path=""
  IFS=":" read -r _ _ warmup_path <<< "${endpoints[0]}"
  wait_for_server "$warmup_path"

  # Optional: quick warmup
  wrk -t2 -c32 -d5s "${BASE_URL}${warmup_path}" > /dev/null 2>&1 || true

  for t in "${THREADS_LIST[@]}"; do
    for c in "${CONNS_LIST[@]}"; do
      for n in $(seq 1 "$RUNS"); do
        for e in "${endpoints[@]}"; do
          IFS=":" read -r impl endpoint path <<< "$e"
          run_wrk "$impl" "$endpoint" "$path" "$t" "$c" "$n"
        done
      done
    done
  done

  stop_server
}

case "$FRAMEWORK" in
  all)
    run_framework "KiriBench" build_kiri start_kiri KIRI_ENDPOINTS
    run_framework "Axum" build_axum start_axum AXUM_ENDPOINTS
    run_framework "Vapor" build_vapor start_vapor VAPOR_ENDPOINTS
    ;;
  kiri)
    run_framework "KiriBench" build_kiri start_kiri KIRI_ENDPOINTS
    ;;
  axum)
    run_framework "Axum" build_axum start_axum AXUM_ENDPOINTS
    ;;
  vapor)
    run_framework "Vapor" build_vapor start_vapor VAPOR_ENDPOINTS
    ;;
esac

echo "All wrk outputs are in ${OUT_DIR}/"

python3 scripts/bench/parse-wrk.py
python3 scripts/bench/plot-bench.py
