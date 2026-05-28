#!/bin/bash
set -euo pipefail

IMAGE_NAME="${1:-medzin/openclaw:test}"
SKIP_BUILD="${2:-false}"
TEST_DIR="$(pwd)/openclaw-test-data"
TEST_FILE="$TEST_DIR/ownership-test"

CURRENT_UID="$(id -u)"
CURRENT_GID="$(id -g)"

echo "Current User: $CURRENT_UID:$CURRENT_GID"

if [ "$SKIP_BUILD" != "skip-build" ]; then
  echo "Building Docker image..."
  docker build -t "$IMAGE_NAME" .
else
  echo "Skipping Docker build..."
fi

echo "Creating test directory: $TEST_DIR"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo "Running permission check..."
docker run --rm \
  -e PUID="$CURRENT_UID" \
  -e PGID="$CURRENT_GID" \
  -v "$TEST_DIR":/home/node/.openclaw \
  --entrypoint /docker-entrypoint.sh \
  "$IMAGE_NAME" \
  sh -lc 'touch "$OPENCLAW_STATE_DIR/ownership-test" && stat -c "%u:%g" "$OPENCLAW_STATE_DIR/ownership-test"'

FILE_UID="$(stat -c '%u' "$TEST_FILE")"
FILE_GID="$(stat -c '%g' "$TEST_FILE")"

echo "File UID: $FILE_UID (Expected: $CURRENT_UID)"
echo "File GID: $FILE_GID (Expected: $CURRENT_GID)"

if [ "$FILE_UID" -ne "$CURRENT_UID" ] || [ "$FILE_GID" -ne "$CURRENT_GID" ]; then
  echo "FAILURE: Permissions do not match." >&2
  exit 1
fi

echo "SUCCESS: Permissions are correct."
rm -rf "$TEST_DIR" || echo "Warning: Could not remove test directory. You might need sudo."
