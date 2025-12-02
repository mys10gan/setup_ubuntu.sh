#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

require_root

TARGET_USER="${1:-}"

install_docker_engine() {
  if command -v docker &>/dev/null; then
    log INFO "Docker already installed."
    return
  fi

  log INFO "==> Step: Installing Docker Engine (root)"

  # Remove old versions
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    if dpkg -l | grep -q "^ii\s\+$pkg"; then
      apt-get remove -y "$pkg"
    fi
  done

  apt-get update -y
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local codename
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $codename stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  log SUCCESS "Docker Engine installed and service started."
}

add_user_to_docker_group() {
  if [[ -z "$TARGET_USER" ]]; then
    log WARN "No target user specified for docker group membership; skipping usermod."
    return
  fi

  if ! id "$TARGET_USER" &>/dev/null; then
    log WARN "Target user '$TARGET_USER' does not exist; cannot add to docker group."
    return
  fi

  log INFO "Adding '$TARGET_USER' to docker group..."
  usermod -aG docker "$TARGET_USER"
  log SUCCESS "User '$TARGET_USER' added to docker group. A new login is required for this to take effect."
}

install_docker_engine
add_user_to_docker_group

log SUCCESS "Root-level Docker installation step complete."


