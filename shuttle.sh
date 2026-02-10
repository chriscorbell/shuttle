#!/bin/bash

# Set UTF-8 locale (if available)
if locale -a | grep -q "en_US.UTF-8\|en_US.utf8"; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NOCOLOR='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}✗ This script should not be run as root${NOCOLOR}"
    echo -e "${YELLOW}Please run as a normal user with sudo privileges${NOCOLOR}"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

# Check if user has sudo access
if ! sudo -n true; then
    if ! sudo -v; then
        echo -e "${RED}✗ Unable to obtain sudo privileges${NOCOLOR}"
        exit 1
    fi
fi

# Check for network connectivity
if ! ping -c 1 8.8.8.8 && ! ping -c 1 1.1.1.1; then
    echo -e "${RED}✗ No network connectivity detected${NOCOLOR}"
    echo -e "${YELLOW}Please check your internet connection and try again${NOCOLOR}"
    exit 1
fi

# Function to print step
print_step() {
    echo -e "${CYAN}▶ $1${NOCOLOR}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NOCOLOR}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NOCOLOR}"
}

echo -e "${MAGENTA}"
cat << "EOF"

      ▄             ▄▄                      ▄▄
    ▄███▄           ██           ██    ██   ██
   ██▀ ▀██    ▄█▀▀▀ ████▄ ██ ██ ▀██▀▀ ▀██▀▀ ██ ▄█▀█▄
  ████▄████   ▀███▄ ██ ██ ██ ██  ██    ██   ██ ██▄█▀
  █▀ ▄▄▄ ▀█   ▄▄▄█▀ ██ ██ ▀██▀█  ██    ██   ██ ▀█▄▄▄
     ▀█▀

EOF
echo -e "${NOCOLOR}"

# Display detected distribution
print_step "Detecting Linux distribution..."
print_success "Detected distribution: $DISTRO"

# Configure passwordless sudo
print_step "Configuring passwordless sudo..."

# Verify user is in wheel or sudo group
if ! groups | grep -qE '\bwheel\b|\bsudo\b'; then
    print_error "User $USER is not in wheel or sudo group"
    echo -e "${YELLOW}Run: sudo usermod -aG wheel $USER (or sudo instead of wheel)${NOCOLOR}"
    echo -e "${YELLOW}Then log out and log back in before running this script${NOCOLOR}"
    exit 1
fi

# Check if we can find a sudo group configuration to modify
SUDO_CONFIGURED=false

# Check if NOPASSWD is already configured
if sudo grep -qE '^%(wheel|sudo)[[:space:]]+ALL=\(ALL(:ALL)?\)[[:space:]]+NOPASSWD:[[:space:]]+ALL$' /etc/sudoers; then
    SUDO_CONFIGURED=true
    print_success "Passwordless sudo already configured"
elif sudo grep -q '^%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers; then
    # Uncommented wheel line exists, modify it
    sudo sed -i 's/^%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers; then
    # Commented wheel line exists, uncomment and modify it
    sudo sed -i 's/^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL$' /etc/sudoers; then
    # Alternate wheel format
    sudo sed -i 's/^%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+NOPASSWD:[[:space:]]\+ALL$' /etc/sudoers; then
    # Commented NOPASSWD wheel line - just uncomment it
    sudo sed -i 's/^#[[:space:]]*\(%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+NOPASSWD:[[:space:]]\+ALL\)$/\1/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers; then
    # Uncommented sudo line exists, modify it
    sudo sed -i 's/^%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for sudo group"
elif sudo grep -q '^#[[:space:]]*%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers; then
    # Commented sudo line exists, uncomment and modify it
    sudo sed -i 's/^#[[:space:]]*%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for sudo group"
fi

# Only remove sudoers.d files if we successfully configured the main sudoers file
if [ "$SUDO_CONFIGURED" = "true" ]; then
    # Validate sudoers file syntax
    if ! sudo visudo -c; then
        print_error "Sudoers file has syntax errors - aborting to prevent lockout"
        exit 1
    fi

    # Only remove sudoers.d files that might conflict with passwordless sudo
    if [ -d /etc/sudoers.d ]; then
        REMOVED_COUNT=0
        for file in /etc/sudoers.d/*; do
            if [ -f "$file" ] && sudo grep -qE '%(wheel|sudo).*ALL.*ALL' "$file"; then
                sudo rm -f "$file"
                REMOVED_COUNT=$((REMOVED_COUNT + 1))
            fi
        done
        if [ "$REMOVED_COUNT" -gt 0 ]; then
            print_success "Removed $REMOVED_COUNT conflicting sudoers.d override file(s)"
        fi
    fi
else
    print_error "Could not find standard sudo group configuration in /etc/sudoers - skipping sudoers.d cleanup to preserve existing sudo access"
fi

# Distribution-specific setup
case $DISTRO in
    debian)
        print_step "Enabling contrib and non-free components in APT sources..."
        # Add contrib and non-free to lines that don't already have them
        sudo sed -i '/^deb / { /contrib/! s/\(main\)\([^c]\|$\)/\1 contrib\2/ }' /etc/apt/sources.list
        sudo sed -i '/^deb / { /non-free[^-]/! s/\(main\|contrib\)\([^n]\|$\)/\1 non-free\2/ }' /etc/apt/sources.list
        sudo sed -i '/^deb-src / { /contrib/! s/\(main\)\([^c]\|$\)/\1 contrib\2/ }' /etc/apt/sources.list
        sudo sed -i '/^deb-src / { /non-free[^-]/! s/\(main\|contrib\)\([^n]\|$\)/\1 non-free\2/ }' /etc/apt/sources.list
        sudo apt update
        print_success "Repositories configured"

        print_step "Upgrading system and installing base packages..."
        if bash -c "sudo apt update && sudo apt full-upgrade -y && sudo apt install build-essential jq ripgrep gnupg2 pipx zsh dysk zoxide fastfetch nala file lsd fzf git lazygit wget curl bat btop ffmpeg cifs-utils tar unzip unrar unar unace bzip2 xz-utils 7zip which ncdu duf progress lsof wormhole rsync moreutils unp bsdextrautils -y && (command -v tldr >/dev/null 2>&1 || pipx install tldr)"; then
            print_success "System upgraded and base packages installed"
        else
            print_error "Failed to upgrade system and install base packages"
            exit 1
        fi

        if command -v gh; then
            print_success "GitHub CLI already installed"
        elif print_step "Installing GitHub CLI..." && bash -c "sudo mkdir -p -m 755 /etc/apt/keyrings && if [ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then out=\$(mktemp) && wget -nv -O\$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && cat \$out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; fi && sudo mkdir -p -m 755 /etc/apt/sources.list.d && if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list; fi && sudo apt update && sudo apt install gh -y"; then
            print_success "GitHub CLI installed"
        else
            print_error "Failed to install GitHub CLI"
            exit 1
        fi

        if command -v docker; then
            print_success "Docker already installed"
        elif print_step "Installing Docker..." && bash -c "sudo apt update && sudo apt install ca-certificates curl -y && sudo install -m 0755 -d /etc/apt/keyrings && sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && sudo chmod a+r /etc/apt/keyrings/docker.asc && printf 'Types: deb\\nURIs: https://download.docker.com/linux/debian\\nSuites: %s\\nComponents: stable\\nSigned-By: /etc/apt/keyrings/docker.asc\\n' \"\$(. /etc/os-release && echo \$VERSION_CODENAME)\" | sudo tee /etc/apt/sources.list.d/docker.sources && sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y && (getent group docker | grep -q \$USER || sudo usermod -aG docker \$USER)"; then
            print_success "Docker installed and configured"
        else
            print_error "Failed to install Docker"
            exit 1
        fi

        if command -v lazydocker || [ -x "$HOME/.local/bin/lazydocker" ]; then
            print_success "lazydocker already installed"
        elif print_step "Installing lazydocker..." && bash -c "DIR=\"\$HOME/.local/bin\" && mkdir -p \"\$DIR\" && ARCH=\$(uname -m) && case \$ARCH in i386|i686) ARCH=x86 ;; armv6*) ARCH=armv6 ;; armv7*) ARCH=armv7 ;; aarch64*) ARCH=arm64 ;; esac && GITHUB_LATEST_VERSION=\$(curl -L -s -H 'Accept: application/json' https://github.com/jesseduffield/lazydocker/releases/latest | sed -e 's/.*\"tag_name\":\"\([^\"]*\)\".*/\1/') && GITHUB_FILE=\"lazydocker_\${GITHUB_LATEST_VERSION//v/}_\$(uname -s)_\${ARCH}.tar.gz\" && GITHUB_URL=\"https://github.com/jesseduffield/lazydocker/releases/download/\${GITHUB_LATEST_VERSION}/\${GITHUB_FILE}\" && cd /tmp && curl -L -o lazydocker.tar.gz \$GITHUB_URL && tar xzf lazydocker.tar.gz lazydocker && install -Dm 755 lazydocker -t \"\$DIR\" && rm lazydocker lazydocker.tar.gz && cd -"; then
            print_success "lazydocker installed"
        else
            print_error "Failed to install lazydocker"
            exit 1
        fi
        ;;

    arch)
        print_step "Configuring pacman..."
        # Enable Color if commented
        if grep -q "^#Color$" /etc/pacman.conf; then
            sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
        fi
        # Enable VerbosePkgLists if commented
        if grep -q "^#VerbosePkgLists$" /etc/pacman.conf; then
            sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf
        fi
        # Set ParallelDownloads to 10
        if grep -q "^#ParallelDownloads = 5$" /etc/pacman.conf; then
            sudo sed -i 's/^#ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf
        elif grep -q "^ParallelDownloads = 5$" /etc/pacman.conf; then
            sudo sed -i 's/^ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf
        fi
        # Add ILoveCandy if not present
        if ! grep -q "^ILoveCandy" /etc/pacman.conf && grep -q "^VerbosePkgLists" /etc/pacman.conf; then
            sudo sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf
        fi
        print_success "Pacman configured"

        if print_step "Installing reflector..." && bash -c "sudo pacman -Sy --needed --noconfirm reflector rsync"; then
            print_success "Reflector installed"
        else
            print_error "Failed to install reflector"
            exit 1
        fi

        COUNTRY_CODE=$(locale | grep -oP '^LC_TIME=.*_\K[A-Z]{2}' | head -1)
        if [ -z "$COUNTRY_CODE" ]; then
            COUNTRY_CODE=$(locale | grep -oP '^LANG=.*_\K[A-Z]{2}' | head -1)
        fi
        COUNTRY_CODE=${COUNTRY_CODE:-US}

        # Only update mirrorlist if it wasn't recently updated by reflector
        # Check if reflector has run before (it adds a timestamp comment)
        if ! grep -q "# Reflector" /etc/pacman.d/mirrorlist 2>/dev/null || [ "$(find /etc/pacman.d/mirrorlist -mtime +7 2>/dev/null | wc -l)" -gt 0 ]; then
            if print_step "Updating mirrorlist with reflector..." && bash -c "sudo reflector --country '$COUNTRY_CODE' --score 20 --sort rate --save /etc/pacman.d/mirrorlist"; then
                print_success "Mirrorlist updated"
            else
                print_error "Failed to update mirrorlist"
                exit 1
            fi
        else
            print_success "Mirrorlist recently updated by reflector, skipping"
        fi

        if print_step "Updating system and installing base packages..." && bash -c "sudo pacman -Syu --needed --noconfirm base-devel jq ripgrep python-pipx ansible terraform zsh dysk zoxide yazi fastfetch file lsd fzf git github-cli lazygit wget curl bat btop ffmpeg cifs-utils tar unzip unrar unace bzip2 xz p7zip ncdu duf progress lsof magic-wormhole rsync rustup moreutils unp"; then
            print_success "System updated and base packages installed"
        else
            print_error "Failed to update system and install base packages"
            exit 1
        fi

        if command -v yay; then
            print_success "yay AUR helper already installed"
        elif print_step "Installing yay AUR helper..." && bash -c "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm --needed && cd -"; then
            print_success "yay AUR helper installed"
        else
            print_error "Failed to install yay AUR helper"
            exit 1
        fi

        if command -v docker; then
            print_success "Docker already installed"
        elif print_step "Installing Docker..." && bash -c "yay -S --needed --noconfirm docker docker-compose docker-buildx lazydocker && sudo systemctl enable docker && sudo systemctl start docker && (getent group docker | grep -q \$USER || sudo usermod -aG docker \$USER)"; then
            print_success "Docker installed and configured"
        else
            print_error "Failed to install Docker"
            exit 1
        fi
        ;;

    *)
        print_error "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

print_step "Installing dotfiles..."
if bash -c "cd /tmp && rm -rf dotfiles && git clone https://github.com/chriscorbell/dotfiles dotfiles && cd dotfiles && if [ -d \$HOME/.config ]; then cp -rn .config/* \$HOME/.config/ 2>/dev/null || true; cp -r .config \$HOME/ 2>/dev/null || true; else cp -r .config \$HOME/; fi && if [ ! -f \$HOME/.zshrc ] || ! cmp -s .zshrc \$HOME/.zshrc; then cp .zshrc \$HOME/; fi && cd .. && rm -rf dotfiles"; then
    print_success "Dotfiles installed"
else
    print_error "Failed to install dotfiles"
    exit 1
fi

print_step "Changing default shell to ZSH..."
# Prefer standard locations over whatever is first in PATH
if [ -x "/usr/bin/zsh" ]; then
    ZSH_PATH="/usr/bin/zsh"
else
    ZSH_PATH="/bin/zsh"
fi

# Configure PAM to allow wheel/sudo group members to use chsh without password
if [ -f /etc/pam.d/chsh ]; then
    # Determine which group to use (wheel or sudo)
    if groups | grep -q '\bwheel\b'; then
        PAM_GROUP="wheel"
    elif groups | grep -q '\bsudo\b'; then
        PAM_GROUP="sudo"
    fi

    if [ -n "$PAM_GROUP" ]; then
        # Check if the exact configuration already exists
        if ! grep -q "pam_wheel.so trust group=$PAM_GROUP" /etc/pam.d/chsh; then
            # Remove any old pam_wheel.so trust lines first
            sudo sed -i '/pam_wheel.so trust/d' /etc/pam.d/chsh
            # Add the pam_wheel.so line at the beginning of the auth section
            sudo sed -i "1i auth    sufficient  pam_wheel.so trust group=$PAM_GROUP" /etc/pam.d/chsh
        fi
    fi
fi

CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
    print_success "Default shell is already ZSH"
elif chsh -s "$ZSH_PATH"; then
    print_success "Default shell changed to ZSH"
else
    print_error "Failed to change default shell"
    exit 1
fi

clear

echo -e "${MAGENTA}"
cat << "EOF"

      ▄             ▄▄                      ▄▄
    ▄███▄           ██           ██    ██   ██
   ██▀ ▀██    ▄█▀▀▀ ████▄ ██ ██ ▀██▀▀ ▀██▀▀ ██ ▄█▀█▄
  ████▄████   ▀███▄ ██ ██ ██ ██  ██    ██   ██ ██▄█▀
  █▀ ▄▄▄ ▀█   ▄▄▄█▀ ██ ██ ▀██▀█  ██    ██   ██ ▀█▄▄▄
     ▀█▀

EOF
echo -e "${NOCOLOR}"

print_success "Installation completed"
echo -e "\n${MAGENTA}✓ Installation complete! Please log out and log back in for all changes to take effect.${NOCOLOR}"
echo
exit
