#!/bin/bash
set -e

# Set up environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export script_path="${SCRIPT_DIR}"

# Check if we're running inside Docker
if [ -f /.dockerenv ]; then
  echo "Running tests inside Docker container..."
  shellspec --format tap
else
  echo "Running tests in local environment..."
  echo "Note: Some tests may be skipped if required tools are not installed"
  shellspec --format tap
fi
