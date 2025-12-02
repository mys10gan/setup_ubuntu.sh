## setup_ubuntu.sh

Opinionated Ubuntu bootstrap for fresh cloud servers (AWS/GCP/etc).

### Overview

- **`bootstrap_root.sh`**: Run once as **root** on a brand‑new server. It:
  - Prints a colored **myst** ASCII banner and sets up structured logging (with timestamps + log file)
  - Prompts for a new username and password
  - Creates the user and adds them to the `sudo` group (if needed)
  - Copies your existing `authorized_keys` to the new user
  - Copies this repo into `/home/<user>/setup_ubuntu.sh`
  - Runs **root‑level installers** (apt, Docker, fish)
  - Runs **user‑level installers** as the new user
  - Sets fish as the default shell for the new user (after it’s installed)
  - Verifies local login, docker (no sudo), and lazydocker for the new user
- **Root‑level installers** (invoked by `bootstrap_root.sh`):
  - `scripts/install_system_packages.sh` – apt upgrade + core CLI tools (must be run as root)
  - `scripts/install_fish_root.sh` – installs the fish shell via apt/ppa
  - `scripts/install_docker_root.sh` – installs Docker Engine and adds the new user to the `docker` group
- **User‑level installers** (invoked by `bootstrap_root.sh` as the new user):
  - `scripts/install_shell_and_cli.sh` – starship “theme”, zoxide, Homebrew, modern `ls` (`eza` with icons)
  - `scripts/install_dev_tools.sh` – uv, Node.js via `fnm`, optional pyenv, tldr
  - `scripts/install_lazydocker.sh` – lazydocker in `~/.local/bin` and on PATH

Everything is designed to be **idempotent**: re‑running scripts should be safe.

### 1. One‑time setup on the fresh server (as root)

SSH into the new machine using the initial/root account your cloud provider gives you, then:

```bash
sudo apt-get update -y
sudo apt-get install -y git
cd ~
git clone <your-repo-url> setup_ubuntu.sh
cd setup_ubuntu.sh
sudo bash bootstrap_root.sh
```

The script will:
- Ask for a **new username** (default: `dev`)
- Ask for a **password** for that user
- Copy SSH `authorized_keys` from:
  - `$SUDO_USER`’s home if you used `sudo`, or
  - `/root/.ssh/authorized_keys` if you are root
- Copy the repo into `/home/<user>/setup_ubuntu.sh`
- Run the user‑level installers as that user

### 2. What gets installed for the new user

- **System / CLI**
  - `curl`, `wget`, `git`, `htop`, `neofetch`, `tmux`, `ncdu`, `bat`, `unzip`, build essentials, etc.
- **Shell**
  - `fish` shell (installed at root level, set as default for the new user)
  - `starship` prompt integrated into `~/.config/fish/config.fish`
  - `zoxide` with fish init hook and `~/.local/bin` on `PATH`
  - `eza` (modern `ls`) with fish aliases:
    - `ls` → `eza --group-directories-first --icons --header`
    - `ll` → `eza -lh --group-directories-first --icons --header`
    - `la` → `eza -lha --group-directories-first --icons --header`
- **Package managers / runtimes**
  - **Homebrew for Linux**, with shell integration for bash and fish
  - **uv** (Python package/venv manager) in `~/.local/bin` and on fish `PATH`
  - **Node.js** via **fnm** (Fast Node Manager), with fish integration
  - Optional **pyenv** (prompted; installs latest CPython and wires bash+fish)
- **Docker**
  - Docker Engine (Docker CE) + Docker Compose plugin (root‑level)
  - User is added to `docker` group so Docker works **without sudo** after re‑login
  - `lazydocker` in `~/.local/bin` and on fish `PATH`

All tools are wired into fish via `~/.config/fish/config.fish`, so a new fish session sees everything.

### 3. Verifying SSH and default shell

After `bootstrap_root.sh` finishes:

- From your local machine, SSH using the new user:

```bash
ssh <new-user>@<server-ip>
```

- On first login, you should land directly in **fish** (after install completed) and have:
  - `docker`, `lazydocker`, `uv`, `brew`, `node`, `tmux`, `zoxide`, etc. on `PATH`
  - Starship prompt active in fish

If SSH fails:
- Check `/home/<user>/.ssh/authorized_keys` exists and contains your key
- Check `/etc/ssh/sshd_config` allows pubkey auth and that the user is not restricted

### 4. Re‑running parts of the setup

You can log in as the new user and re‑run most installers individually:

```bash
cd ~/setup_ubuntu.sh/scripts
# User-level (safe as the new user)
bash install_shell_and_cli.sh
bash install_dev_tools.sh
bash install_lazydocker.sh

# Root-level (must be run with sudo/root)
sudo bash install_system_packages.sh
sudo bash install_fish_root.sh
sudo bash install_docker_root.sh <username>
```

Each script is written to be **safe to re‑run** and will skip already installed tools when possible.

### Notes / assumptions

- Scripts assume **Ubuntu** (LTS) and **systemd** for Docker service management.
- `bootstrap_root.sh` must be run as **root** (either real root or via `sudo`).
- “Starfish theme” is implemented via the **Starship prompt** for fish; if you meant a different theme,
  you can easily adjust `scripts/install_shell_and_cli.sh` and `config.fish` initialization lines.

