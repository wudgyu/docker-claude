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
export HOST_CLAUDE_DIR="${HOST_CLAUDE_DIR:-${HOME}/.claude}"

mkdir -p "${HOST_CLAUDE_DIR}"
for dir in skills agents commands output-styles rules themes workflows routines plugins; do
  mkdir -p "${HOST_CLAUDE_DIR}/${dir}"
done

WORKSPACE_HOST_DIR="${WORKSPACE_HOST_DIR:-${HOME}/workspace}"
mkdir -p "${WORKSPACE_HOST_DIR}"
export WORKSPACE_HOST_DIR="$(cd "${WORKSPACE_HOST_DIR}" && pwd -P)"

# 每次启动都刷新：同步宿主机 settings/env、技能链接和配置目录
"${HERE}/init-host.sh"

if ! docker image inspect claude-code:local >/dev/null 2>&1; then
  "${COMPOSE[@]}" build
fi

exec "${COMPOSE[@]}" run --rm claude "$@"
