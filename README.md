# myst • setup_ubuntu.sh

> Opinionated, one-command Ubuntu bootstrap for fresh cloud servers.

```
                     _
  _ __ ___  _   ____| |_
 | '_ ` _ \| | | / __| __|
 | | | | | | |_| \__ \ |_
 |_| |_| |_|\__, |___/\__|
            |___/
```

---

## ⚡ Quick Start

SSH into your fresh Ubuntu server and run:

```bash
git clone https://github.com/mys10gan/setup_ubuntu.sh.git
cd ~/setup_ubuntu.sh && sudo bash bootstrap_root.sh
```

Follow the prompts (username + password), then **exit and re-SSH as the new user**. Done.

---

## What You Get

| Category | Tools |
|----------|-------|
| **Shell** | fish (default), starship prompt, zoxide (`z`), modern `ls` via eza |
| **Dev Tools** | uv (Python), fnm + Node.js LTS, optional pyenv, tldr |
| **Containers** | Docker CE (no sudo), docker-compose, lazydocker |
| **CLI Essentials** | git, curl, wget, htop, tmux, bat, ncdu, neofetch |
| **Package Managers** | Homebrew for Linux, apt |

All tools are pre-configured for **fish shell** with proper PATH and init hooks.

---

## Detailed Guide

### Prerequisites

- Fresh **Ubuntu** server (22.04 LTS or newer recommended)
- SSH access as `root` or a user with `sudo` privileges
- Your SSH public key in `~/.ssh/authorized_keys` (for key copying to new user)

### How It Works

1. **You run `bootstrap_root.sh` as root** — it handles everything:
   - Creates a new non-root user with sudo access
   - Copies your SSH keys to the new user
   - Installs system packages, Docker, and fish shell (root-level)
   - Switches to the new user and installs dev tools, shell config, lazydocker
   - Sets fish as the default shell

2. **You exit and SSH back as the new user** — you land in a fully configured fish shell.

### What Gets Installed

#### System & CLI (root-level)
- `curl`, `wget`, `git`, `htop`, `neofetch`, `tmux`, `ncdu`, `bat`, `unzip`
- `build-essential`, `pkg-config`, `ca-certificates`, `gnupg`

#### Shell & Prompt (user-level)
- **fish** shell — set as default for the new user
- **starship** prompt — minimal, fast, customizable
- **zoxide** — smarter `cd` (`z` command)
- **eza** — modern `ls` replacement with icons and colors

Fish aliases configured:
```fish
ls  → eza --group-directories-first --icons --header
ll  → eza -lh --group-directories-first --icons --header
la  → eza -lha --group-directories-first --icons --header
```

#### Package Managers & Runtimes (user-level)
- **Homebrew** for Linux — with fish integration
- **uv** — fast Python package/venv manager from Astral
- **fnm** — fast Node.js version manager (installs latest LTS)
- **pyenv** — optional, prompted during install

#### Docker (root-level install, user-level access)
- **Docker CE** + Docker Compose plugin
- User added to `docker` group — **no sudo required**
- **lazydocker** — terminal UI for Docker

### File Structure

```
setup_ubuntu.sh/
├── bootstrap_root.sh          # Main entry point (run as root)
├── lib/
│   └── common.sh              # Shared logging & helpers
├── scripts/
│   ├── install_system_packages.sh   # apt packages (root)
│   ├── install_fish_root.sh         # fish shell (root)
│   ├── install_docker_root.sh       # Docker CE (root)
│   ├── install_as_user.sh           # orchestrator (user)
│   ├── install_shell_and_cli.sh     # starship, zoxide, brew, eza (user)
│   ├── install_dev_tools.sh         # uv, fnm, pyenv, tldr (user)
│   └── install_lazydocker.sh        # lazydocker (user)
└── README.md
```

### Logging & Troubleshooting

All scripts use structured logging with timestamps:
- **Root log**: `/var/log/myst-setup.log`
- **User log**: `~/.myst_setup.log`

If something fails, check these logs for the exact error and line number.

### Re-running Individual Scripts

Already set up but want to add/update something? SSH as your user and run:

```bash
cd ~/setup_ubuntu.sh/scripts

# User-level scripts (run as your user)
bash install_shell_and_cli.sh
bash install_dev_tools.sh
bash install_lazydocker.sh

# Root-level scripts (need sudo)
sudo bash install_system_packages.sh
sudo bash install_fish_root.sh
sudo bash install_docker_root.sh <username>
```

All scripts are **idempotent** — safe to re-run.

### Verifying the Setup

After SSH-ing as the new user:

```bash
# Should show fish
echo $SHELL

# Docker without sudo
docker ps

# All tools available
which uv node brew lazydocker starship zoxide eza
```

### SSH Troubleshooting

If you can't SSH as the new user:

1. Check keys exist: `cat /home/<user>/.ssh/authorized_keys`
2. Check permissions: `ls -la /home/<user>/.ssh/`
3. Check sshd config: `grep -E "PubkeyAuthentication|PasswordAuthentication" /etc/ssh/sshd_config`

---

## Notes

- Tested on **Ubuntu 22.04 LTS** and **24.04 LTS**
- Requires **systemd** for Docker service management
- The "starship" prompt is what we call the "starfish theme" — customize via `~/.config/starship.toml`
