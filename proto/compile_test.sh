#!/usr/bin/env bash

set -e
cd "$(dirname "$0")"

echo "=== Protoc version ==="
protoc --version

echo "=== Compile Go ==="
protoc --go_out=. --go_opt=paths=source_relative trace.proto

echo "=== Compile Python (for PyTorch loader) ==="
protoc --python_out=. trace.proto

echo "✅ Schema compiles cleanly"