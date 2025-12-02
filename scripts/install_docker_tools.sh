#!/usr/bin/env bash

# Backwards-compatible wrapper around new Docker scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  log INFO "Running legacy docker tools script in root mode -> calling install_docker_root.sh"
  bash "$SCRIPT_DIR/install_docker_root.sh" "${1:-}"
else
  log INFO "Running legacy docker tools script in user mode -> calling install_lazydocker.sh"
  bash "$SCRIPT_DIR/install_lazydocker.sh"
fi

log SUCCESS "Docker tools wrapper complete."

