#!/bin/sh
set -eu

PUID="${PUID:-99}"
PGID="${PGID:-100}"
OPENCLAW_HOME="${OPENCLAW_HOME:-/home/node}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/home/node/.openclaw}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-/home/node/.openclaw/openclaw.json}"
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-/home/node/.openclaw}"
APP_WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}"
AUTH_PROFILE_SECRET_DIR="${OPENCLAW_AUTH_PROFILE_SECRET_DIR:-/home/node/.config/openclaw}"
TAILSCALE_STATE_DIR="${TAILSCALE_STATE_DIR:-/home/node/.openclaw/.tailscale_state}"
UMASK="${UMASK:-022}"

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

if ! is_uint "$PUID"; then
  echo "ERROR: PUID must be a numeric user id, got: $PUID" >&2
  exit 64
fi

if ! is_uint "$PGID"; then
  echo "ERROR: PGID must be a numeric group id, got: $PGID" >&2
  exit 64
fi

if [ "$(id -u)" != "0" ]; then
  echo "ERROR: OpenClaw Unraid wrapper must start as root so setup and Tailscale hooks can run." >&2
  exit 65
fi

echo "Starting OpenClaw..."
echo "UMASK set to $UMASK"
echo "PUID set to $PUID"
echo "PGID set to $PGID"

umask "$UMASK"

if [ "$(id -u node)" != "$PUID" ] || [ "$(id -g node)" != "$PGID" ]; then
  echo "Updating node user id to $PUID and group id to $PGID..."
  groupmod -o -g "$PGID" node
  usermod -o -u "$PUID" -g "$PGID" node
fi

echo "Fixing permissions for /home/node..."
mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" "$OPENCLAW_CONFIG_DIR" "$APP_WORKSPACE" "$AUTH_PROFILE_SECRET_DIR" "$TAILSCALE_STATE_DIR" /home/node/.cache
chown -R node:node /home/node

export HOME=/home/node
export OPENCLAW_HOME
export OPENCLAW_STATE_DIR
export OPENCLAW_CONFIG_PATH
export OPENCLAW_CONFIG_DIR
export OPENCLAW_WORKSPACE_DIR="$APP_WORKSPACE"
export OPENCLAW_AUTH_PROFILE_SECRET_DIR="$AUTH_PROFILE_SECRET_DIR"
export TAILSCALE_STATE_DIR

echo "Executing OpenClaw command: $*"
exec gosu node "$@"
