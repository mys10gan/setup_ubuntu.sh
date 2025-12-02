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

  # Ensure the current shell session can see ~/.local/bin (needed for preset commands).
  if [[ ":${PATH}:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
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
    log WARN "brew not available; skipping eza installation."
    # We continue to writing aliases even if eza isn't found yet,
    # because the aliases are guarded by 'if command -v eza' in fish.
  fi

  # Install fzf and bat (batcat) for rich aliases
  log INFO "Installing fzf and bat for rich shell features..."
  if command -v brew &>/dev/null; then
    brew install fzf bat
  else
    sudo apt-get install -y fzf bat
  fi

  ensure_fish_dirs

  # Write comprehensive Omakub-style configuration
  cat > "$FISH_CONF_D_DIR/omakub_aliases.fish" << 'EOF'
# ============================================
# Omakub-inspired Aliases & Functions (Tailored)
# ============================================

# File System Aliases
if command -v eza >/dev/null
    alias ls 'eza -lh --group-directories-first --icons=auto'
    alias lsa 'ls -a'
    alias lt 'eza --tree --level=2 --long --icons --git'
    alias lta 'lt -a'
end

# Navigation
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'

# Tool Aliases
if command -v batcat >/dev/null
    alias bat 'batcat'
    alias cat 'batcat'
else if command -v bat >/dev/null
    alias cat 'bat'
end

alias lzd 'lazydocker'
alias g 'git'
alias d 'docker'

# Git
alias gcm 'git commit -m'
alias gcam 'git commit -a -m'
alias gcad 'git commit -a --amend'
alias gst 'git status'
alias gl 'git pull'
alias gp 'git push'

# Interactive FZF
if command -v fzf >/dev/null
    if command -v batcat >/dev/null
        alias ff "fzf --preview 'batcat --style=numbers --color=always {}'"
    else if command -v bat >/dev/null
        alias ff "fzf --preview 'bat --style=numbers --color=always {}'"
    end
end

# Functions

# Neovim - open current dir if no args
if command -v nvim >/dev/null
    function n
        if test (count $argv) -eq 0
            nvim .
        else
            nvim $argv
        end
    end
end
EOF

  log SUCCESS "Omakub-style aliases configured in conf.d/omakub_aliases.fish"
}

install_starship_theme() {
  local config_dir="$HOME/.config"
  mkdir -p "$config_dir"
  local config_file="$config_dir/starship.toml"

  local preset_url="https://starship.rs/presets/toml/jetpack.toml"

  log INFO "Applying Starship 'Jetpack' preset (clean minimal right-prompt) from $preset_url ..."
  if curl -fsSL "$preset_url" -o "$config_file"; then
    log SUCCESS "Jetpack preset downloaded and applied to $config_file."
  else
    log WARN "Failed to download Jetpack preset; using bundled fallback."
    cat > "$config_file" << 'EOF'
# Fallback: Jetpack-inspired preset (subset) for starship
add_newline = true
continuation_prompt = "[▸▹ ](dimmed white)"

format = """
($nix_shell$container$fill$git_metrics\n)$cmd_duration\
$hostname\
$username\
$character"""

right_format = """
$directory\
$git_branch\
$git_status\
$docker_context\
$nodejs\
$python\
$rust\
$package\
$time"""

[fill]
symbol = ' '

[character]
format = "$symbol "
success_symbol = "[◎](bold italic bright-yellow)"
error_symbol = "[○](italic purple)"

[username]
style_user = "bright-yellow bold italic"
style_root = "purple bold italic"
format = "[⭘ $user]($style) "

[directory]
home_symbol = "⌂"
truncation_length = 2
truncation_symbol = "…/"
read_only = " "
style = "italic blue"

[git_branch]
format = " [$branch]($style)"
symbol = "[△](bold italic bright-blue)"
style = "italic bright-blue"
truncation_symbol = "⋯"

[git_status]
style = "bold italic bright-blue"
format = "([⎪$ahead_behind$staged$modified$untracked⎥]($style))"
conflicted = "[◪◦](italic bright-magenta)"
ahead = "[▴│${count}│](italic green)"
behind = "[▿│${count}│](italic red)"
untracked = "[◌◦](italic bright-yellow)"
modified = "[●◦](italic yellow)"
staged = "[▪│$count│](italic bright-cyan)"

[cmd_duration]
format = "[◄ $duration ](italic white)"

[nodejs]
format = " [node](italic) [◫ ($version)](bold bright-green)"
detect_files = ["package-lock.json", "yarn.lock"]

[python]
format = " [py](italic) [⌉${version}⌊](bold bright-yellow)"

[rust]
format = " [rs](italic) [⊃ $version](bold red)"

[docker_context]
symbol = "◧ "
format = " [$symbol$context](bold blue)"

[package]
format = " [pkg](italic dimmed) [◨ $version](dimmed yellow italic bold)"

[time]
disabled = false
format = "[ $time](italic dimmed white)"
time_format = "%R"
EOF
    log SUCCESS "Fallback Jetpack-inspired preset written to $config_file."
  fi

  log SUCCESS "Starship theme ready at $config_file"
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


