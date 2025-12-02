#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

log INFO "Running user-level install scripts as $(whoami)..."

# System-level (apt, docker) are run from bootstrap_root.sh as root.
# Here we only run user-safe installers.

bash "$SCRIPT_DIR/install_shell_and_cli.sh"
bash "$SCRIPT_DIR/install_dev_tools.sh"
bash "$SCRIPT_DIR/install_lazydocker.sh"

log SUCCESS "All user-level installation steps completed."

