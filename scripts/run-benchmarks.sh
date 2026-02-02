#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="scripts/bench/.out"
DURATION=30
RUNS=3

THREADS_LIST=(2 8)
CONNS_LIST=(64 256 512)

BASE_URL="http://127.0.0.1:8080"

ENDPOINTS=(
  "rust:plaintext:/__rust/plaintext"
  "swift:plaintext:/plaintext"
  "rust:noop:/__rust/noop"
  "swift:noop:/noop"
)

mkdir -p "$OUT_DIR"

build_and_run() {
  cargo build --release --features bench;
  swift build --package-path swift -c release --product KiriBench;

  LD_LIBRARY_PATH=\"$ZED_WORKTREE_ROOT/rust/target/release\";

  swift/.build/release/KiriBench & SERVER_PID=$!;
  sleep 1;
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

build_and_run

echo "Server PID: ${SERVER_PID}";

# Optional: quick warmup
wrk -t2 -c32 -d5s "${BASE_URL}/__rust/plaintext" > /dev/null 2>&1 || true

for t in "${THREADS_LIST[@]}"; do
  for c in "${CONNS_LIST[@]}"; do
    for n in $(seq 1 "$RUNS"); do
      for e in "${ENDPOINTS[@]}"; do
        IFS=":" read -r impl endpoint path <<< "$e"
        run_wrk "$impl" "$endpoint" "$path" "$t" "$c" "$n"
      done
    done
  done
done

kill $SERVER_PID

echo "All wrk outputs are in ${OUT_DIR}/"

python3 scripts/bench/parse-wrk.py
python3 scripts/bench/plot-bench.py
