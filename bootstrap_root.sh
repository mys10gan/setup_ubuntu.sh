#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

require_root

DEFAULT_USERNAME="dev"
SKIP_USER_SETUP=false

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -u, --user <username>   Specify username (default: $DEFAULT_USERNAME)"
    echo "  -s, --skip-user         Skip user creation/password prompts (user must exist)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      # Interactive: prompts for username and password"
    echo "  $0 -u myuser            # Create user 'myuser' (prompts for password if new)"
    echo "  $0 -u myuser -s         # Skip user setup, just run installers for 'myuser'"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user)
                DEFAULT_USERNAME="$2"
                shift 2
                ;;
            -s|--skip-user)
                SKIP_USER_SETUP=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

on_error() {
    local line="$1"
    local cmd="$2"
    log ERROR "Bootstrap failed at line $line while running: $cmd"
    log ERROR "Check the log file for full details: ${LOG_FILE:-<no log file>}"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

print_banner() {
    echo -e "${PURPLE}${BOLD}"
    cat << 'EOF'
                      _
  _ __ ___  _   _ ___| |_
 | '_ ` _ \| | | / __| __|
 | | | | | | |_| \__ \ |_
 |_| |_| |_|\__, |___/\__|
            |___/
EOF
    echo -e "${NC}"
}

prompt_for_username() {
    local username
    read -r -p "Enter new username [${DEFAULT_USERNAME}]: " username || username=""
    username=${username:-$DEFAULT_USERNAME}

    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log ERROR "Invalid username: $username"
        exit 1
    fi

    echo "$username"
}

create_user_if_needed() {
    local username="$1"

    if id "$username" &>/dev/null; then
        log INFO "User '$username' already exists. Skipping creation."
        return 0
    fi

    log INFO "Creating user '$username'..."

    local password
    while true; do
        read -s -r -p "Enter password for $username: " password || password=""
        echo
        local password_confirm
        read -s -r -p "Confirm password for $username: " password_confirm || password_confirm=""
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            log WARN "Passwords do not match. Please try again."
        elif [[ -z "$password" ]]; then
            log WARN "Password cannot be empty. Please try again."
        else
            break
        fi
    done

    # Create user with home directory and bash as initial shell
    adduser --disabled-password --gecos "" "$username"
    echo "$username:$password" | chpasswd

    # Add to sudo group
    usermod -aG sudo "$username"

    log SUCCESS "User '$username' created and added to sudo group."
}

copy_authorized_keys() {
    local username="$1"

    local source_user
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        source_user="$SUDO_USER"
    else
        source_user="root"
    fi

    local source_home
    if [[ "$source_user" == "root" ]]; then
        source_home="/root"
    else
        source_home="/home/$source_user"
    fi

    local src_auth="$source_home/.ssh/authorized_keys"
    local target_home="/home/$username"
    local target_ssh="$target_home/.ssh"
    local target_auth="$target_ssh/authorized_keys"

    if [[ ! -f "$src_auth" ]]; then
        log WARN "No authorized_keys found at $src_auth. SSH key copying skipped."
        return 0
    fi

    log INFO "Copying SSH authorized_keys from $source_user to $username..."

    mkdir -p "$target_ssh"
    chmod 700 "$target_ssh"
    cp "$src_auth" "$target_auth"
    chmod 600 "$target_auth"
    chown -R "$username:$username" "$target_ssh"

    log SUCCESS "SSH authorized_keys copied to $target_auth."
}

copy_repo_to_user_home() {
    local username="$1"
    local target_home="/home/$username"
    local target_dir="$target_home/setup_ubuntu.sh"

    log INFO "Copying setup repo to $target_dir..."

    rsync -a --delete "$ROOT_DIR/" "$target_dir/"
    chown -R "$username:$username" "$target_dir"

    log SUCCESS "Repo copied to $target_dir."
}

set_default_shell_to_fish() {
    local username="$1"

    if command -v fish &>/dev/null; then
        local fish_path
        fish_path="$(command -v fish)"
        if [[ "$(getent passwd "$username" | cut -d: -f7)" != "$fish_path" ]]; then
            log INFO "Setting default shell for '$username' to fish ($fish_path)..."
            chsh -s "$fish_path" "$username"
            log SUCCESS "Default shell for '$username' set to fish."
        else
            log INFO "User '$username' already has fish as default shell."
        fi
    else
        log WARN "fish shell not installed yet; default shell will remain bash."
    fi
}

run_user_install() {
    local username="$1"
    local target_home="/home/$username"
    local target_dir="$target_home/setup_ubuntu.sh"
    local user_script="$target_dir/scripts/install_as_user.sh"

    if [[ ! -x "$user_script" ]]; then
        if [[ -f "$user_script" ]]; then
            chmod +x "$user_script"
        else
            log ERROR "User install script not found at $user_script"
            exit 1
        fi
    fi

    log INFO "Running user-level installation as '$username'..."
    sudo -u "$username" -H bash "$user_script"
    log SUCCESS "User-level installation completed for '$username'."
}

verify_local_login() {
    local username="$1"
    log INFO "Verifying that we can start a login shell for '$username'..."

    if su - "$username" -c 'whoami' &>/dev/null; then
        log SUCCESS "Local login test for '$username' succeeded."
    else
        log WARN "Local login test for '$username' failed. Please check /etc/passwd and /etc/sudoers."
    fi
}

verify_docker_for_user() {
    local username="$1"
    if su - "$username" -c 'docker ps >/dev/null 2>&1' ; then
        log SUCCESS "Docker is usable by '$username' without sudo."
    else
        log WARN "Docker test for '$username' failed. This may fix itself after a fresh login (docker group)."
    fi
}

verify_lazydocker_for_user() {
    local username="$1"
    if su - "$username" -c 'command -v lazydocker >/dev/null 2>&1' ; then
        log SUCCESS "lazydocker is installed for '$username'."
    else
        log WARN "lazydocker not found for '$username'."
    fi
}

main() {
    parse_args "$@"

    print_banner
    log INFO "Bootstrap: creating user, configuring SSH, and running system + user setup."

    local username
    if [[ "$SKIP_USER_SETUP" == true ]]; then
        username="$DEFAULT_USERNAME"
        if ! id "$username" &>/dev/null; then
            log ERROR "User '$username' does not exist. Cannot use --skip-user."
            exit 1
        fi
        log INFO "Skipping user creation (--skip-user). Using existing user '$username'."
    else
        username="$(prompt_for_username)"
        create_user_if_needed "$username"
        copy_authorized_keys "$username"
    fi

    copy_repo_to_user_home "$username"

    log INFO "Running system-level setup as root (apt, Docker, fish)..."
    bash "$ROOT_DIR/scripts/install_system_packages.sh"
    bash "$ROOT_DIR/scripts/install_fish_root.sh"
    bash "$ROOT_DIR/scripts/install_docker_root.sh" "$username"

    verify_local_login "$username"

    run_user_install "$username"
    set_default_shell_to_fish "$username"
    verify_docker_for_user "$username"
    verify_lazydocker_for_user "$username"

    log SUCCESS "Bootstrap complete for user '$username'."
    echo
    log INFO "Next steps (IMPORTANT):"
    echo "  1) Exit this SSH session."
    echo "  2) SSH back in as: ssh ${username}@<your-server-ip>"
    echo "  3) On first login you should land in fish with starship prompt and have docker/lazydocker, uv, brew, node, etc."
    echo
    log INFO "If you have connection issues, ensure:"
    echo "  - /home/${username}/.ssh/authorized_keys contains your public key"
    echo "  - /etc/ssh/sshd_config allows PubkeyAuthentication and the user is not blocked"
    echo
    log INFO "A detailed log of this run is in: ${LOG_FILE:-<no log file>}"
}

main "$@"

