#!/bin/bash
set -euo pipefail

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "Expected $file to contain: $expected" >&2
    exit 1
  fi
}

assert_contains Dockerfile 'ARG IMAGE_VARIANT=minimal'
assert_contains Dockerfile 'case "$IMAGE_VARIANT" in'
assert_contains Dockerfile 'ripgrep openssh-client nmap qrencode imagemagick ffmpeg nftables python3-debugpy'

assert_contains .github/workflows/build-and-publish.yml 'variant: [minimal, extras]'
assert_contains .github/workflows/build-and-publish.yml 'IMAGE_VARIANT=${{ matrix.variant }}'
assert_contains .github/workflows/build-and-publish.yml 'medzin/openclaw:${{ matrix.version }}-extras'
assert_contains .github/workflows/build-and-publish.yml 'medzin/openclaw:extras'

echo "Release variant checks passed."
