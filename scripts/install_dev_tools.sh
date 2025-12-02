#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"

ensure_fish_config() {
  mkdir -p "$FISH_CONFIG_DIR"
  touch "$FISH_CONFIG_FILE"
}

append_if_missing() {
  local line="$1"
  local file="$2"

  grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >>"$file"
}

install_uv() {
  if command -v uv &>/dev/null; then
    log INFO "uv already installed."
    return
  fi

  log INFO "Installing uv (Python package manager/runtime)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh

  ensure_fish_config
  append_if_missing 'set -gx PATH $HOME/.local/bin $PATH' "$FISH_CONFIG_FILE"

  log SUCCESS "uv installed and added to PATH in fish."
}

install_node_with_fnm() {
  if command -v node &>/dev/null; then
    log INFO "Node.js already available (skipping fnm)."
    return
  fi

  if ! command -v fnm &>/dev/null; then
    log INFO "Installing fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    log SUCCESS "fnm installed."
  fi

  ensure_fish_config
  append_if_missing 'set -gx PATH $HOME/.local/share/fnm $PATH' "$FISH_CONFIG_FILE"
  append_if_missing 'fnm env --use-on-cd --shell fish | source' "$FISH_CONFIG_FILE"

  export PATH="$HOME/.local/share/fnm:$PATH"
  # shellcheck disable=SC1091
  eval "$(fnm env --shell bash)" || true

  log INFO "Installing latest LTS Node.js via fnm..."
  fnm install --lts
  fnm default "$(fnm ls | grep -i lts | tail -n 1 | awk '{print $1}')" || true

  log SUCCESS "Node.js installed with fnm."
}

install_pyenv_optional() {
  if command -v pyenv &>/dev/null; then
    log INFO "pyenv already installed."
    return
  fi

  if ! confirm "Install pyenv as an optional Python version manager as well?" "n"; then
    log INFO "Skipping pyenv installation."
    return
  fi

  log INFO "Installing pyenv..."
  curl https://pyenv.run | bash

  # Bash config
  if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q 'PYENV_ROOT' "$HOME/.bashrc"; then
      {
        echo 'export PYENV_ROOT="$HOME/.pyenv"'
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
        echo 'eval "$(pyenv init --path)"'
        echo 'eval "$(pyenv init -)"'
      } >>"$HOME/.bashrc"
    fi
  fi

  # Fish config
  ensure_fish_config
  append_if_missing 'set -gx PYENV_ROOT $HOME/.pyenv' "$FISH_CONFIG_FILE"
  append_if_missing 'set -gx PATH $PYENV_ROOT/bin $PATH' "$FISH_CONFIG_FILE"
  append_if_missing 'pyenv init - | source' "$FISH_CONFIG_FILE"

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)" || true

  local latest_python
  latest_python="$(pyenv install --list | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tr -d ' ' | tail -1)"
  log INFO "Installing latest Python via pyenv: $latest_python"
  pyenv install -s "$latest_python"
  pyenv global "$latest_python"

  log SUCCESS "pyenv installed with Python $latest_python."
}

install_tldr() {
  if command -v tldr &>/dev/null; then
    log INFO "tldr already installed."
    return
  fi

  if command -v npm &>/dev/null; then
    log INFO "Installing tldr (npm)..."
    npm install -g tldr
    log SUCCESS "tldr installed."
  elif command -v brew &>/dev/null; then
    log INFO "Installing tldr (Homebrew)..."
    brew install tldr
    log SUCCESS "tldr installed."
  else
    log WARN "npm/brew not available; skipping tldr."
  fi
}

install_uv
install_node_with_fnm
install_pyenv_optional
install_tldr

log SUCCESS "Developer tools installation complete (uv, Node.js via fnm, optional pyenv, tldr)."


