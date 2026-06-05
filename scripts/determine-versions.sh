#!/bin/bash
set -euo pipefail

UPSTREAM_IMAGE="openclaw/openclaw"
DOCKER_REPO="medzin/openclaw"
SEMVER_RE='^[0-9]+\.[0-9]+(\.[0-9]+)?$'

fetch_upstream_tag_names() {
  local body_file
  local headers_file
  local next_path
  local token
  local url

  token="$(curl -fsSL "https://ghcr.io/token?service=ghcr.io&scope=repository:$UPSTREAM_IMAGE:pull" | jq -r '.token')"
  url="https://ghcr.io/v2/$UPSTREAM_IMAGE/tags/list?n=1000"
  body_file="$(mktemp)"
  headers_file="$(mktemp)"
  trap 'rm -f "$body_file" "$headers_file"' RETURN

  while [ -n "$url" ]; do
    curl -fsSL \
      -D "$headers_file" \
      -o "$body_file" \
      -H "Authorization: Bearer $token" \
      "$url"

    jq -r '.tags[]?' "$body_file"

    next_path="$(awk -F'[<>]' 'tolower($0) ~ /^link:/ && $0 ~ /rel="next"/ { print $2; exit }' "$headers_file")"
    if [ -n "$next_path" ]; then
      url="https://ghcr.io$next_path"
    else
      url=""
    fi
  done
}

semantic_upstream_tags() {
  fetch_upstream_tag_names \
    | { grep -E "$SEMVER_RE" || true; } \
    | sort -V
}

fetch_dockerhub_tag_names() {
  local response_file
  local url

  url="https://hub.docker.com/v2/repositories/$DOCKER_REPO/tags/?page_size=100"
  response_file="$(mktemp)"
  trap 'rm -f "$response_file"' RETURN

  while [ -n "$url" ]; do
    curl -fsSL -o "$response_file" "$url"
    jq -r '.results[].name?' "$response_file"
    url="$(jq -r '.next // ""' "$response_file")"
  done
}

echo "Fetching OpenClaw image tags from GHCR..." >&2

OPENCLAW_TAGS="$(semantic_upstream_tags)"
LATEST_UPSTREAM="${OPENCLAW_TAGS:+$(echo "$OPENCLAW_TAGS" | tail -n 1)}"

if [ "${1:-}" = "--latest-upstream" ]; then
  if [ -z "$LATEST_UPSTREAM" ]; then
    echo "latest"
  else
    echo "$LATEST_UPSTREAM"
  fi
  exit 0
fi

if [ -z "$OPENCLAW_TAGS" ]; then
  echo "No semantic OpenClaw image tags found. Falling back to latest." >&2
  jq --compact-output --null-input '$ARGS.positional' --args latest
  exit 0
fi

echo "Fetching existing tags from Docker Hub for $DOCKER_REPO..." >&2
DH_TAGS="$(fetch_dockerhub_tag_names || true)"

TO_BUILD=()

if [ -z "$DH_TAGS" ]; then
  echo "No existing Docker Hub tags found. Selecting latest stable only." >&2
  TO_BUILD+=("$LATEST_UPSTREAM")
else
  LATEST_LOCAL="$(echo "$DH_TAGS" | grep -E "$SEMVER_RE" | sort -V | tail -n 1 || true)"

  if [ -z "$LATEST_LOCAL" ]; then
    echo "No version-like Docker Hub tags found. Selecting latest stable only." >&2
    TO_BUILD+=("$LATEST_UPSTREAM")
  else
    echo "Latest Docker Hub version: $LATEST_LOCAL" >&2
    for VER in $OPENCLAW_TAGS; do
      if [ "$(printf '%s\n%s\n' "$LATEST_LOCAL" "$VER" | sort -V | tail -n 1)" = "$VER" ] && [ "$LATEST_LOCAL" != "$VER" ]; then
        TO_BUILD+=("$VER")
      fi
    done

    if ! echo "$DH_TAGS" | grep -Fxq "$LATEST_UPSTREAM-extras"; then
      TO_BUILD+=("$LATEST_UPSTREAM")
    fi
  fi
fi

if [ "${#TO_BUILD[@]}" -gt 0 ]; then
  mapfile -t SORTED_BUILD < <(printf '%s\n' "${TO_BUILD[@]}" | sort -Vu)
else
  SORTED_BUILD=()
fi

echo "Versions to build: ${SORTED_BUILD[*]}" >&2
jq --compact-output --null-input '$ARGS.positional' --args "${SORTED_BUILD[@]}"
