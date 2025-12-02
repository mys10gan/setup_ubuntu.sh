#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

install_lazydocker_user() {
  if command -v lazydocker &>/dev/null; then
    log INFO "lazydocker already installed."
    return
  fi

  log INFO "==> Step: Installing lazydocker for user $(whoami)"

  local dir="$HOME/.local/bin"
  mkdir -p "$dir"

  local arch
  case "$(uname -m)" in
    x86_64) arch="x86_64" ;;
    i686|i386) arch="x86" ;;
    armv6*) arch="armv6" ;;
    armv7*) arch="armv7" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      log ERROR "Unsupported architecture: $(uname -m)"
      return 1
      ;;
  esac

  local os
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"

  local version
  version="$(curl -sL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep -Po '\"tag_name\": \"\K.*?(?=\")')"

  local url="https://github.com/jesseduffield/lazydocker/releases/download/${version}/lazydocker_${version#v}_${os}_${arch}.tar.gz"

  if curl -L -o /tmp/lazydocker.tar.gz "$url"; then
    tar -C /tmp -xzf /tmp/lazydocker.tar.gz lazydocker
    if [[ -f /tmp/lazydocker ]]; then
      install -Dm 755 /tmp/lazydocker -t "$dir"
      rm -f /tmp/lazydocker /tmp/lazydocker.tar.gz
      log SUCCESS "lazydocker installed to $dir."
    else
      log ERROR "Failed to extract lazydocker from archive."
      return 1
    fi
  else
    log ERROR "Failed to download lazydocker archive."
    return 1
  fi

  # Ensure PATH for fish
  local fish_config_dir="$HOME/.config/fish"
  local fish_config_file="$fish_config_dir/config.fish"
  mkdir -p "$fish_config_dir"
  touch "$fish_config_file"
  if ! grep -Fqx 'set -gx PATH $HOME/.local/bin $PATH' "$fish_config_file" 2>/dev/null; then
    echo 'set -gx PATH $HOME/.local/bin $PATH' >>"$fish_config_file"
  fi

  log SUCCESS "lazydocker will be available in fish after a new session."
}

install_lazydocker_user

log SUCCESS "User-level lazydocker installation step complete."


