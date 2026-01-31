#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

echo "Building libkiri_ffi."

cargo build --release

LIB_PATH="$SCRIPT_DIR/../target/release/libkiri_ffi.a"
TARGET_PATH="$SCRIPT_DIR/../artifacts/"

mkdir -p "$TARGET_PATH"
cp -r "$LIB_PATH" "$TARGET_PATH"

echo "Built libkiri_ffi."
