#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"

if [[ "$(id -u)" -eq 0 ]]; then
  cat >&2 <<'EOF'
error: do not run this script with sudo/root.

Claude Code refuses --dangerously-skip-permissions when running as root,
and UID/GID 0 cannot be used as build args.

Fix Docker access instead:
  sudo usermod -aG docker "$USER" && newgrp docker
EOF
  exit 1
fi

if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
elif docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
else
  echo "error: docker compose not found" >&2
  exit 1
fi

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"
export CONTAINER_USER="${CONTAINER_USER:-claude}"
export CLAUDE_DOCKER_CONFIG_DIR="${CLAUDE_DOCKER_CONFIG_DIR:-${HOME}/.claude-docker}"

WORKSPACE_HOST_DIR="${WORKSPACE_HOST_DIR:-${HOME}/workspace}"
mkdir -p "${WORKSPACE_HOST_DIR}"
export WORKSPACE_HOST_DIR="$(cd "${WORKSPACE_HOST_DIR}" && pwd -P)"

if [[ ! -f "${CLAUDE_DOCKER_CONFIG_DIR}/settings.json" || ! -f "${CLAUDE_DOCKER_CONFIG_DIR}/claude.env" ]]; then
  "${HERE}/init-host.sh"
fi

if ! docker image inspect claude-code:local >/dev/null 2>&1; then
  "${COMPOSE[@]}" build
fi

exec "${COMPOSE[@]}" run --rm claude "$@"
