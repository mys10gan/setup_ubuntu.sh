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

install_starship() {
  if command -v starship &>/dev/null; then
    log INFO "starship already installed."
  else
    log INFO "Installing starship prompt to ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    # Install to user's local bin (no sudo), force yes
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    log SUCCESS "starship installed to ~/.local/bin."
  fi

  ensure_fish_config
  # Ensure ~/.local/bin is on PATH (before starship init)
  append_if_missing 'set -gx PATH $HOME/.local/bin $PATH' "$FISH_CONFIG_FILE"
  append_if_missing 'starship init fish | source' "$FISH_CONFIG_FILE"
  log SUCCESS "starship integrated with fish."
}

install_zoxide() {
  if command -v zoxide &>/dev/null; then
    log INFO "zoxide already installed."
  else
    log INFO "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    log SUCCESS "zoxide installed."
  fi

  ensure_fish_config
  append_if_missing 'set -gx PATH $HOME/.local/bin $PATH' "$FISH_CONFIG_FILE"
  append_if_missing 'zoxide init fish | source' "$FISH_CONFIG_FILE"
  log SUCCESS "zoxide integrated with fish."
}

install_brew() {
  # Check if brew is already available
  if command -v brew &>/dev/null; then
    log INFO "Homebrew already installed."
    return
  fi

  # Also check the standard linuxbrew path
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    log INFO "Homebrew already installed (adding to current session)."
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    log INFO "Installing Homebrew for Linux..."
    # Run from home directory to avoid "current working directory must exist" error
    cd "$HOME"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Add to current shell session
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  # Add to bashrc if present
  if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "brew shellenv" "$HOME/.bashrc"; then
      {
        echo
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
      } >>"$HOME/.bashrc"
    fi
  fi

  # Add to fish config
  ensure_fish_config
  append_if_missing 'if test -x /home/linuxbrew/.linuxbrew/bin/brew; eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv); end' "$FISH_CONFIG_FILE"

  log SUCCESS "Homebrew installed and configured."
}

install_eza_and_aliases() {
  # Ensure brew is in current PATH
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
  fi

  # Install eza via brew if needed
  if command -v eza &>/dev/null; then
    log INFO "eza already installed."
  elif command -v brew &>/dev/null; then
    log INFO "Installing eza (modern ls replacement) via Homebrew..."
    cd "$HOME"  # Ensure we're in a valid directory
    brew install eza
    log SUCCESS "eza installed."
  else
    log WARN "brew not available; skipping eza installation. ls aliases will not be set."
    return
  fi

  ensure_fish_config
  append_if_missing 'alias ls "eza --group-directories-first --icons --header"' "$FISH_CONFIG_FILE"
  append_if_missing 'alias ll "eza -lh --group-directories-first --icons --header"' "$FISH_CONFIG_FILE"
  append_if_missing 'alias la "eza -lha --group-directories-first --icons --header"' "$FISH_CONFIG_FILE"

  log SUCCESS "fish ls aliases configured to use eza with icons and headers."
}

install_starship
install_zoxide
install_brew
install_eza_and_aliases

log SUCCESS "Shell and CLI configuration complete (starship, zoxide, brew, eza ls aliases)."

