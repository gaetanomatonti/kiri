#!/usr/bin/env bash

# If invoked with `sh`, restart with bash so arrays and other bash features work.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="scripts/bench/.out"
COMPOSE_FILE="${ROOT_DIR}/docker/bench/docker-compose.yml"

MODE="${1:-full}"
FRAMEWORK="${2:-all}"
TARGET="${3:-local}"

case "$MODE" in
  light) RUNS=1 ;;
  full) RUNS=3 ;;
  *)
    echo "Usage: $0 [light|full] [all|kiri|axum|vapor|gin] [local|docker]"
    exit 1
    ;;
esac

case "$FRAMEWORK" in
  all|kiri|axum|vapor|gin) ;;
  *)
    echo "Usage: $0 [light|full] [all|kiri|axum|vapor|gin] [local|docker]"
    exit 1
    ;;
esac

case "$TARGET" in
  local|docker) ;;
  *)
    echo "Usage: $0 [light|full] [all|kiri|axum|vapor|gin] [local|docker]"
    exit 1
    ;;
esac

echo "Benchmark config: mode=${MODE} framework=${FRAMEWORK} target=${TARGET}"

# oha does not expose wrk-style thread controls; keep a single slot for report shape.
THREADS_LIST=(1)
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

GIN_ENDPOINTS=(
  "gin:plaintext:/plaintext"
  "gin:noop:/noop"
)

mkdir -p "$OUT_DIR"
SERVER_PID=""
CURRENT_SERVICE=""
ENDPOINTS_SELECTED=()

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

stop_server() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

stop_service() {
  if [[ -n "${CURRENT_SERVICE}" ]]; then
    compose stop "${CURRENT_SERVICE}" >/dev/null 2>&1 || true
    compose rm -f "${CURRENT_SERVICE}" >/dev/null 2>&1 || true
    CURRENT_SERVICE=""
  fi
}

cleanup() {
  stop_server
  stop_service
}

trap cleanup EXIT

resolve_endpoints() {
  local endpoints_var="$1"
  case "$endpoints_var" in
    KIRI_ENDPOINTS) ENDPOINTS_SELECTED=("${KIRI_ENDPOINTS[@]}") ;;
    AXUM_ENDPOINTS) ENDPOINTS_SELECTED=("${AXUM_ENDPOINTS[@]}") ;;
    VAPOR_ENDPOINTS) ENDPOINTS_SELECTED=("${VAPOR_ENDPOINTS[@]}") ;;
    GIN_ENDPOINTS) ENDPOINTS_SELECTED=("${GIN_ENDPOINTS[@]}") ;;
    *)
      echo "Unknown endpoint set: ${endpoints_var}"
      exit 1
      ;;
  esac
}

show_service_logs() {
  if [[ -n "${CURRENT_SERVICE}" ]]; then
    echo "-- ${CURRENT_SERVICE} container logs (tail) --"
    compose logs --tail=120 "${CURRENT_SERVICE}" || true
    echo "-- end of ${CURRENT_SERVICE} logs --"
  fi
}

wait_for_server() {
  local path="$1"
  local tries="$2"
  local i
  for i in $(seq 1 "$tries"); do
    if curl -fsS "${BASE_URL}${path}" > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Server did not become ready on ${BASE_URL}${path}"
  show_service_logs
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

build_gin() {
  mkdir -p bench/gin/.build
  go build -C bench/gin -o .build/gin-bench .
}

start_gin() {
  local bin="bench/gin/.build/gin-bench"
  if [[ ! -x "$bin" ]]; then
    echo "Could not find gin benchmark binary"
    exit 1
  fi

  "$bin" &
  SERVER_PID=$!
}

run_oha() {
  local target_base_url="$1"
  local impl="$2"
  local endpoint="$3"
  local path="$4"
  local threads="$5"
  local conns="$6"
  local run="$7"

  local url="${target_base_url}${path}"
  local file="${OUT_DIR}/oha__${impl}__${endpoint}__t${threads}__c${conns}__d${DURATION}__run${run}.json"

  echo ">> oha ${impl}/${endpoint} t=${threads} c=${conns} run=${run}"
  if ! compose run --rm -T oha -c "$conns" -z "${DURATION}s" --output-format json "$url" > "$file" 2>&1; then
    echo "oha failed for ${impl}/${endpoint} (run=${run}, c=${conns}, d=${DURATION}s)"
    echo "Saved output: ${file}"
    echo "-- oha output (tail) --"
    tail -n 120 "$file" || true
    echo "-- end oha output --"
    show_service_logs
    return 1
  fi
}

run_local_framework() {
  local framework="$1"
  local build_fn="$2"
  local start_fn="$3"
  local endpoints_var="$4"

  resolve_endpoints "$endpoints_var"

  echo "== Benchmarking ${framework} locally (mode=${MODE}, runs=${RUNS}) =="

  "$build_fn"
  "$start_fn"
  echo "Server PID: ${SERVER_PID}"

  local warmup_path=""
  IFS=":" read -r _ _ warmup_path <<< "${ENDPOINTS_SELECTED[0]}"
  wait_for_server "$warmup_path" 30

  if ! compose run --rm -T oha -c 32 -z 5s "http://host.docker.internal:8080${warmup_path}" > /dev/null 2>&1; then
    echo "warning: local warmup failed for ${framework} (${warmup_path})"
  fi

  for t in "${THREADS_LIST[@]}"; do
    for c in "${CONNS_LIST[@]}"; do
      for n in $(seq 1 "$RUNS"); do
        for e in "${ENDPOINTS_SELECTED[@]}"; do
          IFS=":" read -r impl endpoint path <<< "$e"
          run_oha "http://host.docker.internal:8080" "$impl" "$endpoint" "$path" "$t" "$c" "$n"
        done
      done
    done
  done

  stop_server
}

run_docker_framework() {
  local framework="$1"
  local service="$2"
  local endpoints_var="$3"

  resolve_endpoints "$endpoints_var"

  echo "== Benchmarking ${framework} in Docker (mode=${MODE}, runs=${RUNS}) =="

  compose up -d --build "${service}"
  CURRENT_SERVICE="${service}"

  local warmup_path=""
  IFS=":" read -r _ _ warmup_path <<< "${ENDPOINTS_SELECTED[0]}"
  wait_for_server "${warmup_path}" 60

  if ! compose run --rm -T oha -c 32 -z 5s "http://${service}:8080${warmup_path}" > /dev/null 2>&1; then
    echo "warning: docker warmup failed for ${framework} (${warmup_path})"
    show_service_logs
  fi

  for t in "${THREADS_LIST[@]}"; do
    for c in "${CONNS_LIST[@]}"; do
      for n in $(seq 1 "${RUNS}"); do
        for e in "${ENDPOINTS_SELECTED[@]}"; do
          IFS=":" read -r impl endpoint path <<< "${e}"
          run_oha "http://${service}:8080" "$impl" "$endpoint" "$path" "$t" "$c" "$n"
        done
      done
    done
  done

  stop_service
}

run_all_local() {
  case "$FRAMEWORK" in
    all)
      run_local_framework "KiriBench" build_kiri start_kiri KIRI_ENDPOINTS
      run_local_framework "Axum" build_axum start_axum AXUM_ENDPOINTS
      run_local_framework "Vapor" build_vapor start_vapor VAPOR_ENDPOINTS
      run_local_framework "Gin" build_gin start_gin GIN_ENDPOINTS
      ;;
    kiri)
      run_local_framework "KiriBench" build_kiri start_kiri KIRI_ENDPOINTS
      ;;
    axum)
      run_local_framework "Axum" build_axum start_axum AXUM_ENDPOINTS
      ;;
    vapor)
      run_local_framework "Vapor" build_vapor start_vapor VAPOR_ENDPOINTS
      ;;
    gin)
      run_local_framework "Gin" build_gin start_gin GIN_ENDPOINTS
      ;;
  esac
}

run_all_docker() {
  # Ensure no stale service is holding port 8080.
  compose down --remove-orphans >/dev/null 2>&1 || true

  case "$FRAMEWORK" in
    all)
      run_docker_framework "KiriBench" "kiri" KIRI_ENDPOINTS
      run_docker_framework "Axum" "axum" AXUM_ENDPOINTS
      run_docker_framework "Vapor" "vapor" VAPOR_ENDPOINTS
      run_docker_framework "Gin" "gin" GIN_ENDPOINTS
      ;;
    kiri)
      run_docker_framework "KiriBench" "kiri" KIRI_ENDPOINTS
      ;;
    axum)
      run_docker_framework "Axum" "axum" AXUM_ENDPOINTS
      ;;
    vapor)
      run_docker_framework "Vapor" "vapor" VAPOR_ENDPOINTS
      ;;
    gin)
      run_docker_framework "Gin" "gin" GIN_ENDPOINTS
      ;;
  esac
}

if [[ "$TARGET" == "docker" ]]; then
  run_all_docker
else
  # Ensure no stale docker framework container is holding port 8080.
  compose down --remove-orphans >/dev/null 2>&1 || true
  run_all_local
fi

echo "All oha outputs are in ${OUT_DIR}/"

python3 scripts/bench/parse-wrk.py
python3 scripts/bench/plot-bench.py
