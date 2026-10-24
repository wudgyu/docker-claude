#!/usr/bin/env bash
set -euo pipefail
umask 077

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_DOCKER_CONFIG_DIR:-${HOME}/.claude-docker}"
HOST_CLAUDE_DIR="${HOST_CLAUDE_DIR:-${HOME}/.claude}"
SRC_SETTINGS="${HOST_CLAUDE_DIR}/settings.json"
SRC_GLOBAL="${HOME}/.claude.json"
FORCE="${1:-}"

mkdir -p "${CONFIG_DIR}"
chmod 700 "${CONFIG_DIR}"

if command -v jq >/dev/null 2>&1 && [[ -f "${SRC_SETTINGS}" ]]; then
  jq '
    (.permissions = ((((.permissions // {})
      | del(.blockReadsOutsideWorkingDirectories, .disableBypassPermissionsMode))
      + {"defaultMode": "bypassPermissions"})))
    | .skipDangerousModePermissionPrompt = true
    | .autoMemoryEnabled = (.autoMemoryEnabled // true)
    | (if .env then .env |= del(.CLAUDE_CONFIG_DIR) else . end)
  ' "${SRC_SETTINGS}" > "${CONFIG_DIR}/settings.json"
  echo "merged ${SRC_SETTINGS} -> ${CONFIG_DIR}/settings.json (bypassPermissions forced)"
else
  cp "${HERE}/config/settings.json" "${CONFIG_DIR}/settings.json"
  echo "warn: jq or ${SRC_SETTINGS} missing; installed default settings" >&2
fi

for f in CLAUDE.md AGENTS.md keybindings.json; do
  src="${HOST_CLAUDE_DIR}/${f}"
  dst="${CONFIG_DIR}/${f}"
  [[ -f "${src}" ]] || continue
  if [[ -d "${dst}" && ! -L "${dst}" ]]; then
    echo "warn: ${dst} is a directory, skipping symlink" >&2
    continue
  fi
  rm -f "${dst}"
  ln -s "/host-claude/${f}" "${dst}"
  echo "linked ${dst} -> /host-claude/${f}"
done

if command -v jq >/dev/null 2>&1 && [[ -f "${SRC_SETTINGS}" ]]; then
  jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "${SRC_SETTINGS}" \
    > "${CONFIG_DIR}/claude.env"
  echo "exported $(wc -l < "${CONFIG_DIR}/claude.env") env vars from ${SRC_SETTINGS}"
elif [[ ! -f "${CONFIG_DIR}/claude.env" ]]; then
  cp "${HERE}/claude.env.example" "${CONFIG_DIR}/claude.env"
  echo "warn: jq or ${SRC_SETTINGS} missing; created ${CONFIG_DIR}/claude.env from example, edit it" >&2
fi
chmod 600 "${CONFIG_DIR}/claude.env"

if [[ -f "${SRC_GLOBAL}" ]] && { [[ "${FORCE}" == "--force" ]] || [[ ! -f "${CONFIG_DIR}/.claude.json" ]]; }; then
  cp "${SRC_GLOBAL}" "${CONFIG_DIR}/.claude.json"
  if command -v jq >/dev/null 2>&1; then
    tmp="${CONFIG_DIR}/.claude.json.tmp"
    jq '.hasCompletedOnboarding = true' "${CONFIG_DIR}/.claude.json" > "${tmp}" \
      && mv "${tmp}" "${CONFIG_DIR}/.claude.json"
  fi
  chmod 600 "${CONFIG_DIR}/.claude.json"
  echo "copied ${SRC_GLOBAL} -> ${CONFIG_DIR}/.claude.json"
fi

echo "done. run ./run.sh to start claude."
