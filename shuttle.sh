#!/bin/bash

# Enable debug mode if DEBUG=1 is set
if [ "${DEBUG}" = "1" ]; then
    set -x
fi

# Trap handler to ensure cursor is restored and cleanup on exit
trap 'tput cnorm 2>/dev/null; exit' INT TERM EXIT

# Set UTF-8 locale (if available)
if locale -a 2>/dev/null | grep -q "en_US.UTF-8\|en_US.utf8"; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
fi

# Log file for debugging
LOG_FILE="/tmp/shuttle-install-$(date +%Y%m%d-%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NOCOLOR='\033[0m' # No Color

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

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
if ! sudo -n true 2>/dev/null; then
    if ! sudo -v; then
        echo -e "${RED}✗ Unable to obtain sudo privileges${NOCOLOR}"
        exit 1
    fi
fi

# Check for network connectivity
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 1.1.1.1 >/dev/null 2>&1; then
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

# Function to show spinner while command runs
spin() {
    local pid=$!
    local delay=0.1
    local spinstr=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while ps -p $pid > /dev/null 2>&1; do
        printf "\r${CYAN}▶ %s ${MAGENTA}%s${NOCOLOR}" "$1" "${spinstr[$i]}"
        i=$(( (i+1) % 10 ))
        sleep $delay
    done
    printf "\r%*s\r" $(tput cols) ""  # Clear the line
    wait $pid
    return $?
}

# Function to run command with spinner
run_with_spinner() {
    local message="$1"
    shift
    local cmd="$*"
    
    log "Running: $cmd"
    
    # Create temporary files for stdout and stderr
    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)
    
    # Run command in background, capturing output
    if [ "${DEBUG}" = "1" ]; then
        # In debug mode, show output
        "$@" 2>&1 | tee -a "$LOG_FILE" &
    else
        # Normal mode, capture output
        "$@" >"$tmp_out" 2>"$tmp_err" &
    fi
    
    spin "$message"
    local exit_code=$?
    
    # Log output
    if [ -f "$tmp_out" ]; then
        cat "$tmp_out" >> "$LOG_FILE"
    fi
    if [ -f "$tmp_err" ]; then
        cat "$tmp_err" >> "$LOG_FILE"
    fi
    
    printf "\r${CYAN}▶ %s${NOCOLOR}" "$message"
    echo
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR: Command failed with exit code $exit_code"
        printf "${RED}✗ Failed with exit code: %d${NOCOLOR}\n" "$exit_code"
        if [ -f "$tmp_err" ] && [ -s "$tmp_err" ]; then
            echo -e "${YELLOW}Error output:${NOCOLOR}"
            cat "$tmp_err"
        fi
        echo -e "${YELLOW}Full log available at: $LOG_FILE${NOCOLOR}"
    fi
    
    # Cleanup temp files
    rm -f "$tmp_out" "$tmp_err"
    
    return $exit_code
}

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
if sudo grep -qE '^%(wheel|sudo)[[:space:]]+ALL=\(ALL(:ALL)?\)[[:space:]]+NOPASSWD:[[:space:]]+ALL$' /etc/sudoers 2>/dev/null; then
    SUDO_CONFIGURED=true
    print_success "Passwordless sudo already configured"
elif sudo grep -q '^%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Uncommented wheel line exists, modify it
    sudo sed -i 's/^%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Commented wheel line exists, uncomment and modify it
    sudo sed -i 's/^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Alternate wheel format
    sudo sed -i 's/^%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^#[[:space:]]*%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+NOPASSWD:[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Commented NOPASSWD wheel line - just uncomment it
    sudo sed -i 's/^#[[:space:]]*\(%wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+NOPASSWD:[[:space:]]\+ALL\)$/\1/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for wheel group"
elif sudo grep -q '^%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Uncommented sudo line exists, modify it
    sudo sed -i 's/^%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for sudo group"
elif sudo grep -q '^#[[:space:]]*%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$' /etc/sudoers 2>/dev/null; then
    # Commented sudo line exists, uncomment and modify it
    sudo sed -i 's/^#[[:space:]]*%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null
    SUDO_CONFIGURED=true
    print_success "Configured passwordless sudo for sudo group"
fi

# Only remove sudoers.d files if we successfully configured the main sudoers file
if [ "$SUDO_CONFIGURED" = "true" ]; then
    # Validate sudoers file syntax
    if ! sudo visudo -c >/dev/null 2>&1; then
        print_error "Sudoers file has syntax errors - aborting to prevent lockout"
        exit 1
    fi
    
    if [ -d /etc/sudoers.d ]; then
        sudo find /etc/sudoers.d -type f -exec sudo chmod 644 {} \; 2>/dev/null
        sudo find /etc/sudoers.d -type f -exec sudo rm -f {} \; 2>/dev/null
        print_success "Removed conflicting sudoers.d override files"
    fi
else
    print_error "Could not find standard sudo group configuration in /etc/sudoers - skipping sudoers.d cleanup to preserve existing sudo access"
fi

tput civis

# Distribution-specific setup
case $DISTRO in
    debian)
        print_step "Enabling contrib and non-free components in APT sources..."
        # Add contrib and non-free to lines that don't already have them
        sudo sed -i '/^deb / { /contrib/! s/main/main contrib/ }' /etc/apt/sources.list 2>/dev/null
        sudo sed -i '/^deb / { /non-free[^-]/! s/main/main non-free/ }' /etc/apt/sources.list 2>/dev/null
        sudo sed -i '/^deb-src / { /contrib/! s/main/main contrib/ }' /etc/apt/sources.list 2>/dev/null
        sudo sed -i '/^deb-src / { /non-free[^-]/! s/main/main non-free/ }' /etc/apt/sources.list 2>/dev/null
        sudo apt update >/dev/null 2>&1
        print_success "Repositories configured"
        
        if run_with_spinner "Upgrading system and installing base packages..." bash -c "sudo apt update && sudo apt full-upgrade -y && sudo apt install build-essential jq ripgrep gnupg2 pipx ansible zsh dysk zoxide fastfetch nala file lsd fzf git lazygit wget curl bat btop ffmpeg cifs-utils tar unzip unrar unar unace bzip2 xz-utils 7zip which -y"; then
            print_success "System upgraded and base packages installed"
        else
            print_error "Failed to upgrade system and install base packages"
            exit 1
        fi

        if command -v gh >/dev/null 2>&1; then
            print_success "GitHub CLI already installed"
        elif run_with_spinner "Installing GitHub CLI..." bash -c "sudo mkdir -p -m 755 /etc/apt/keyrings && out=\$(mktemp) && wget -nv -O\$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && cat \$out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && sudo mkdir -p -m 755 /etc/apt/sources.list.d && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null && sudo apt update && sudo apt install gh -y"; then
            print_success "GitHub CLI installed"
        else
            print_error "Failed to install GitHub CLI"
        fi
        
        if run_with_spinner "Installing Docker..." bash -c "sudo apt update && sudo apt install ca-certificates curl -y && sudo install -m 0755 -d /etc/apt/keyrings && sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && sudo chmod a+r /etc/apt/keyrings/docker.asc && printf 'Types: deb\\nURIs: https://download.docker.com/linux/debian\\nSuites: %s\\nComponents: stable\\nSigned-By: /etc/apt/keyrings/docker.asc\\n' \"\$(. /etc/os-release && echo \$VERSION_CODENAME)\" | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null && sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y && (groups | grep -q docker || sudo usermod -aG docker \$USER)"; then
            print_success "Docker installed and configured"
        else
            print_error "Failed to install Docker"
        fi
        
        if command -v lazydocker >/dev/null 2>&1 || [ -x "$HOME/.local/bin/lazydocker" ]; then
            print_success "lazydocker already installed"
        elif run_with_spinner "Installing lazydocker..." bash -c "DIR=\"\$HOME/.local/bin\" && mkdir -p \"\$DIR\" && ARCH=\$(uname -m) && case \$ARCH in i386|i686) ARCH=x86 ;; armv6*) ARCH=armv6 ;; armv7*) ARCH=armv7 ;; aarch64*) ARCH=arm64 ;; esac && GITHUB_LATEST_VERSION=\$(curl -L -s -H 'Accept: application/json' https://github.com/jesseduffield/lazydocker/releases/latest | sed -e 's/.*\"tag_name\":\"\([^\"]*\)\".*/\1/') && GITHUB_FILE=\"lazydocker_\${GITHUB_LATEST_VERSION//v/}_\$(uname -s)_\${ARCH}.tar.gz\" && GITHUB_URL=\"https://github.com/jesseduffield/lazydocker/releases/download/\${GITHUB_LATEST_VERSION}/\${GITHUB_FILE}\" && cd /tmp && curl -L -o lazydocker.tar.gz \$GITHUB_URL && tar xzf lazydocker.tar.gz lazydocker && install -Dm 755 lazydocker -t \"\$DIR\" && rm lazydocker lazydocker.tar.gz && cd -"; then
            print_success "lazydocker installed"
        else
            print_error "Failed to install lazydocker"
        fi
        
        if run_with_spinner "Installing Terraform..." bash -c "wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null && sudo apt update && sudo apt install terraform -y"; then
            print_success "Terraform installed"
        else
            print_error "Failed to install Terraform"
        fi
        ;;
        
    arch)
        print_step "Configuring pacman..."
        sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf 2>/dev/null
        sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf 2>/dev/null
        sudo sed -i 's/^#ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf 2>/dev/null
        sudo sed -i 's/^ParallelDownloads = 5$/ParallelDownloads = 10/' /etc/pacman.conf 2>/dev/null
        if ! grep -q "^ILoveCandy" /etc/pacman.conf && grep -q "^VerbosePkgLists" /etc/pacman.conf; then
            sudo sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf 2>/dev/null
        fi
        print_success "Pacman configured"
        
        if run_with_spinner "Installing reflector..." bash -c "sudo pacman -Sy --needed --noconfirm reflector rsync"; then
            print_success "Reflector installed"
        else
            print_error "Failed to install reflector"
        fi
        
        COUNTRY_CODE=$(locale | grep -oP '^LC_TIME=.*_\K[A-Z]{2}' | head -1)
        if [ -z "$COUNTRY_CODE" ]; then
            COUNTRY_CODE=$(locale | grep -oP '^LANG=.*_\K[A-Z]{2}' | head -1)
        fi
        COUNTRY_CODE=${COUNTRY_CODE:-US}

        if run_with_spinner "Updating mirrorlist with reflector..." bash -c "sudo reflector --country '$COUNTRY_CODE' --score 20 --sort rate --save /etc/pacman.d/mirrorlist"; then
            print_success "Mirrorlist updated"
        else
            print_error "Failed to update mirrorlist"
        fi
        
        if run_with_spinner "Updating system and installing base packages..." bash -c "sudo pacman -Syu --noconfirm base-devel jq ripgrep python-pipx ansible terraform zsh dysk zoxide yazi fastfetch file lsd fzf git github-cli lazygit wget curl bat btop ffmpeg cifs-utils tar unzip unrar unace bzip2 xz p7zip"; then
            print_success "System updated and base packages installed"
        else
            print_error "Failed to update system and install base packages"
            exit 1
        fi
        
        if command -v yay >/dev/null 2>&1; then
            print_success "yay AUR helper already installed"
        elif run_with_spinner "Installing yay AUR helper..." bash -c "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm --needed && cd -"; then
            print_success "yay AUR helper installed"
        else
            print_error "Failed to install yay AUR helper"
        fi
        
        if run_with_spinner "Installing Docker..." bash -c "yay -S --noconfirm docker docker-compose docker-buildx lazydocker && sudo systemctl enable docker && sudo systemctl start docker && (groups | grep -q docker || sudo usermod -aG docker \$USER)"; then
            print_success "Docker installed and configured"
        else
            print_error "Failed to install Docker"
        fi
        ;;
        
    *)
        print_error "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

if run_with_spinner "Cloning and installing dotfiles..." bash -c "rm -rf /tmp/dotfiles && git clone https://github.com/chriscorbell/dotfiles /tmp/dotfiles && cp -r /tmp/dotfiles/.config \$HOME/ && cp /tmp/dotfiles/.zshrc \$HOME/"; then
    print_success "Dotfiles installed"
else
    print_error "Failed to clone and install dotfiles"
fi

print_step "Changing default shell to ZSH..."
ZSH_PATH=$(command -v zsh 2>/dev/null || echo "/bin/zsh")
if [ -x "$ZSH_PATH" ]; then
    # Configure PAM to allow wheel/sudo group members to use chsh without password
    if [ -f /etc/pam.d/chsh ]; then
        # Determine which group to use (wheel or sudo)
        if groups | grep -q '\bwheel\b'; then
            PAM_GROUP="wheel"
        elif groups | grep -q '\bsudo\b'; then
            PAM_GROUP="sudo"
        fi
        
        if [ -n "$PAM_GROUP" ]; then
            if ! grep -q "pam_wheel.so trust" /etc/pam.d/chsh 2>/dev/null; then
                # Add the pam_wheel.so line at the beginning of the auth section
                sudo sed -i "1i auth    sufficient  pam_wheel.so trust group=$PAM_GROUP" /etc/pam.d/chsh 2>/dev/null
            fi
        fi
    fi
    
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
        print_success "Default shell is already ZSH"
    elif chsh -s "$ZSH_PATH" >/dev/null 2>&1; then
        print_success "Default shell changed to ZSH"
    else
        print_error "Failed to change default shell"
    fi
else
    print_error "ZSH not found, could not change default shell"
fi

log "Installation completed"
echo -e "\n${MAGENTA}✓ Installation complete! Please log out and log back in for all changes to take effect.${NOCOLOR}"
echo
echo -e "${CYAN}Log saved to: $LOG_FILE${NOCOLOR}\n"
