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
alias bat 'batcat'
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
    alias ff "fzf --preview 'batcat --style=numbers --color=always {}'"
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

# Create desktop launcher for web app
function web2app
    if test (count $argv) -ne 3
        echo "Usage: web2app <AppName> <AppURL> <IconURL>"
        echo "(IconURL must be PNG)"
        return 1
    end
    set APP_NAME $argv[1]
    set APP_URL $argv[2]
    set ICON_URL $argv[3]
    set ICON_DIR "$HOME/.local/share/applications/icons"
    set DESKTOP_FILE "$HOME/.local/share/applications/$APP_NAME.desktop"
    set ICON_PATH "$ICON_DIR/$APP_NAME.png"
    mkdir -p "$ICON_DIR"
    if not curl -sL -o "$ICON_PATH" "$ICON_URL"
        echo "Error: Failed to download icon."
        return 1
    end
    echo "[Desktop Entry]
Version=1.0
Name=$APP_NAME
Comment=$APP_NAME
Exec=google-chrome --app=\"$APP_URL\" --name=\"$APP_NAME\" --class=\"$APP_NAME\"
Terminal=false
Type=Application
Icon=$ICON_PATH
Categories=GTK;
MimeType=text/html;text/xml;application/xhtml_xml;
StartupNotify=true" > "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "App created: $APP_NAME"
end
EOF

  log SUCCESS "Omakub-style aliases configured in conf.d/omakub_aliases.fish"
}

install_starship_theme() {
  local config_dir="$HOME/.config"
  mkdir -p "$config_dir"
  local config_file="$config_dir/starship.toml"

  # Always overwrite with the cleaner theme requested
  log INFO "Applying 'clean' starship theme..."

  cat > "$config_file" << 'EOF'
# Clean/Minimal Starship Preset (No powerline blocks)
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
read_only = " "

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = " "
"Pictures" = " "

[git_branch]
symbol = " "
style = "bold purple"

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

[php]
symbol = " "
style = "blue dimmed"
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


