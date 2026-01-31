#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Tests that the process is not leaking the port.
for i in {1..50}; do
  $SCRIPT_DIR/../swift/.build/debug/KiriBench & pid=$!
  sleep 0.2
  curl -s http://127.0.0.1:8080/ok >/dev/null
  kill -INT $pid
  wait $pid
done
