#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

require_root

install_fish_root() {
  if command -v fish &>/dev/null; then
    log INFO "fish is already installed (root-level)."
    return
  fi

  log INFO "==> Step: Installing fish shell (root)"

  # Prefer upstream PPA when available
  if ! grep -q "fish-shell/release-3" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    apt-get update -y
    apt-get install -y software-properties-common
    apt-add-repository -y ppa:fish-shell/release-3 || log WARN "Failed to add fish PPA; falling back to distro fish."
  fi

  apt-get update -y
  apt-get install -y fish

  log SUCCESS "fish shell installed at $(command -v fish)."
}

install_fish_root

log SUCCESS "Root-level fish installation step complete."


