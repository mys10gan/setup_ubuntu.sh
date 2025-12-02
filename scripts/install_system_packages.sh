#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

require_root

log INFO "==> Step: Updating apt package index and upgrading system"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

ESSENTIAL_PKGS=(
  curl
  wget
  git
  htop
  neofetch
  ca-certificates
  gnupg
  lsb-release
  software-properties-common
)

ADDITIONAL_PKGS=(
  tmux
  ncdu
  bat
  unzip
  build-essential
  pkg-config
)

install_pkgs() {
  local label="$1"
  shift
  local pkgs=("$@")

  log INFO "Installing $label packages: ${pkgs[*]}..."
  apt-get install -y "${pkgs[@]}"
  log SUCCESS "$label packages installed."
}

install_pkgs "essential" "${ESSENTIAL_PKGS[@]}"
install_pkgs "additional" "${ADDITIONAL_PKGS[@]}"

log SUCCESS "System package installation complete."


