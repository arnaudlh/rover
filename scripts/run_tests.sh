#!/bin/bash
set -e

# Check if we're running inside Docker
if [ -f /.dockerenv ]; then
  echo "Running tests inside Docker container..."
  shellspec --format tap
else
  echo "Running tests in local environment..."
  echo "Note: Some tests may be skipped if required tools are not installed"
  shellspec --format tap
fi
