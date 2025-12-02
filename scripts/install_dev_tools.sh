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

install_uv() {
  if command -v uv &>/dev/null; then
    log INFO "uv already installed."
    return
  fi

  log INFO "Installing uv (Python package manager/runtime)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh

  ensure_fish_dirs

  # uv doesn't strictly need a conf.d file if ~/.local/bin is already on PATH
  # but let's add one to be safe and explicit
  cat > "$FISH_CONF_D_DIR/uv.fish" << 'EOF'
# uv
if test -d "$HOME/.local/bin"
    if not contains "$HOME/.local/bin" $PATH
        set -gx PATH $HOME/.local/bin $PATH
    end
end
# uv command completion
if command -v uv >/dev/null
    uv generate-shell-completion fish | source
end
EOF

  log SUCCESS "uv installed and configured in conf.d/uv.fish"
}

install_node_with_fnm() {
  # Add fnm to PATH if it exists (for script execution)
  if [[ -d "$HOME/.local/share/fnm" ]]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --shell bash 2>/dev/null)" || true
  fi

  if command -v node &>/dev/null; then
    log INFO "Node.js already available (skipping fnm)."
  else
    if ! command -v fnm &>/dev/null; then
      log INFO "Installing fnm (Fast Node Manager)..."
      curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
      log SUCCESS "fnm installed."
      export PATH="$HOME/.local/share/fnm:$PATH"
    fi

    ensure_fish_dirs

    cat > "$FISH_CONF_D_DIR/fnm.fish" << 'EOF'
# fnm
if test -d "$HOME/.local/share/fnm"
    if not contains "$HOME/.local/share/fnm" $PATH
        set -gx PATH $HOME/.local/share/fnm $PATH
    end
end
if command -v fnm >/dev/null
    fnm env --use-on-cd --shell fish | source
end
EOF
    log SUCCESS "fnm configured in conf.d/fnm.fish"

    # Initialize fnm for current session to install Node
    eval "$(fnm env --shell bash)" || true

    log INFO "Installing latest LTS Node.js via fnm..."
    fnm install --lts

    # Set default version
    local installed_version
    installed_version="$(fnm list | grep -i lts | head -n 1 | sed 's/.*\(v[0-9]*\.[0-9]*\.[0-9]*\).*/\1/' | tr -d ' ')" || true

    if [[ -n "$installed_version" ]]; then
      fnm default "$installed_version"
      log SUCCESS "Node.js $installed_version installed and set as default."
    else
      fnm default "$(fnm list | head -n 1 | awk '{print $2}')" 2>/dev/null || true
      log SUCCESS "Node.js installed with fnm."
    fi
  fi
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

  # Bash config (legacy support)
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

  ensure_fish_dirs

  cat > "$FISH_CONF_D_DIR/pyenv.fish" << 'EOF'
# pyenv
set -gx PYENV_ROOT $HOME/.pyenv
if test -d "$PYENV_ROOT/bin"
    if not contains "$PYENV_ROOT/bin" $PATH
        set -gx PATH $PYENV_ROOT/bin $PATH
    end
end
if command -v pyenv >/dev/null
    pyenv init - | source
end
EOF

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


