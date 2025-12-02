#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONF_D_DIR="$FISH_CONFIG_DIR/conf.d"
FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"

ensure_fish_dirs() {
  mkdir -p "$FISH_CONFIG_DIR"
  mkdir -p "$FISH_CONF_D_DIR"
  touch "$FISH_CONFIG_FILE"
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

  ensure_fish_dirs

  # Create dedicated config file
  cat > "$FISH_CONF_D_DIR/starship.fish" << 'EOF'
# Starship prompt
if test -d "$HOME/.local/bin"
    if not contains "$HOME/.local/bin" $PATH
        set -gx PATH $HOME/.local/bin $PATH
    end
end
starship init fish | source
EOF

  log SUCCESS "starship configured in conf.d/starship.fish"
}

install_zoxide() {
  if command -v zoxide &>/dev/null; then
    log INFO "zoxide already installed."
  else
    log INFO "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    log SUCCESS "zoxide installed."
  fi

  ensure_fish_dirs

  cat > "$FISH_CONF_D_DIR/zoxide.fish" << 'EOF'
# zoxide
if test -d "$HOME/.local/bin"
    if not contains "$HOME/.local/bin" $PATH
        set -gx PATH $HOME/.local/bin $PATH
    end
end
zoxide init fish | source
EOF

  log SUCCESS "zoxide configured in conf.d/zoxide.fish"
}

install_brew() {
  # Check if brew is already available
  if command -v brew &>/dev/null; then
    log INFO "Homebrew already installed."
  else
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
  fi

  # Add to current shell session
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  # Add to bashrc if present (for bash compatibility)
  if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "brew shellenv" "$HOME/.bashrc"; then
      {
        echo
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
      } >>"$HOME/.bashrc"
    fi
  fi

  ensure_fish_dirs

  cat > "$FISH_CONF_D_DIR/brew.fish" << 'EOF'
# Homebrew
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end
EOF

  log SUCCESS "Homebrew configured in conf.d/brew.fish"
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

  ensure_fish_dirs

  cat > "$FISH_CONF_D_DIR/eza_aliases.fish" << 'EOF'
# eza aliases
if command -v eza >/dev/null
    alias ls "eza --group-directories-first --icons --header"
    alias ll "eza -lh --group-directories-first --icons --header"
    alias la "eza -lha --group-directories-first --icons --header"
end
EOF

  log SUCCESS "eza aliases configured in conf.d/eza_aliases.fish"
}

install_starship_theme() {
  local config_dir="$HOME/.config"
  mkdir -p "$config_dir"
  local config_file="$config_dir/starship.toml"

  if [[ -f "$config_file" ]]; then
    log INFO "starship.toml already exists. Skipping theme overwrite."
    return
  fi

  log INFO "Applying 'myst' starship theme..."
  # A clean, preset-style config inspired by various popular themes
  cat > "$config_file" << 'EOF'
# myst starship preset
add_newline = true

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[package]
disabled = true

[directory]
truncation_length = 3
truncate_to_repo = false
style = "bold cyan"

[git_branch]
style = "bold purple"
symbol = " "

[git_status]
style = "bold red"

[docker_context]
symbol = " "
style = "blue dimmed"

[python]
symbol = "🐍 "
style = "yellow dimmed"

[nodejs]
symbol = "⬢ "
style = "green dimmed"

[rust]
symbol = "🦀 "
style = "red dimmed"

[golang]
symbol = "🐹 "
style = "cyan dimmed"
EOF
  log SUCCESS "Starship theme configured at ~/.config/starship.toml"
}

cleanup_legacy_config() {
  # Remove lines we previously appended to config.fish, since we now use conf.d
  if [[ -f "$FISH_CONFIG_FILE" ]]; then
    log INFO "Cleaning up legacy entries from config.fish..."
    # We use a temporary file to filter out lines we know we added
    grep -vE "starship init fish" "$FISH_CONFIG_FILE" | \
    grep -vE "zoxide init fish" | \
    grep -vE "brew shellenv" | \
    grep -vE "fnm env" | \
    grep -vE "set -gx PATH .*local/bin" | \
    grep -vE "set -gx PATH .*fnm" | \
    grep -vE "alias l[sla].*eza" > "${FISH_CONFIG_FILE}.tmp"

    mv "${FISH_CONFIG_FILE}.tmp" "$FISH_CONFIG_FILE"
    log SUCCESS "Cleaned up legacy config.fish entries."
  fi
}

install_starship
install_starship_theme
install_zoxide
install_brew
install_eza_and_aliases
cleanup_legacy_config


