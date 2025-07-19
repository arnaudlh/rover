#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROVER_BINARY="${SCRIPT_DIR}/../target/release/rover"

if [ ! -f "$ROVER_BINARY" ]; then
    echo "Error: Rover Rust binary not found at $ROVER_BINARY"
    echo "Please build the project with: cargo build --release"
    exit 1
fi

exec "$ROVER_BINARY" "$@"
