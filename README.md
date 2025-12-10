<div align="center">
  <img src="https://i.imgur.com/E7QQ18h.png?raw=true" width="400" alt="shuttle"><br><br>
  shuttle is a streamlined setup script that automatically configures a fresh installation<br>with essential development tools and server-focused packages.<br>
  <br>
  <b>Supports Debian and Arch Linux.</b>
</div>
<br>

## Prerequisites

- Fresh Debian or Arch installation
- sudo privileges
- User in wheel or sudo group
- Internet connection

## Instructions

```bash
git clone https://github.com/chriscorbell/shuttle.git \
cd shuttle \
chmod +x shuttle.sh \
./shuttle.sh \
```

## What It Installs

### Configuration Changes
- **Passwordless sudo**: Autodetects group (wheel or sudo) to configure passwordless privilege elevation

### Base Packages
- **Shell**: zsh (along with my .zshrc config with zinit, starship, atuin, and [aliases](#zsh-aliases))
- **Development**: base build tools, wget, curl
- **Utilities**: pipx, lsd, fzf, bat, btop, fastfetch
- **Archive tools**: tar, unzip, unrar, unar, unace, bzip2, xz, 7zip (for [pack](#pack) and [extract](#extract) zsh functions)

### Additional Tools
- **Git, GitHub CLI and lazygit**
- **Docker, Docker Compose and lazydocker**
- **Terraform**
- **Ansible**

### Distribution-Specific

**Debian:**
- Enables non-free and contrib repositories
- Installs nala frontend for apt

**Arch:**
- Installs yay AUR helper

## Post-Installation

After the script completes:

1. **Log out and log back in** for all changes to take effect (especially group memberships)
2. Your default shell will be zsh with custom configuration
3. Docker will be enabled and ready to use (no sudo required)
4. All installations are logged to `/tmp/shuttle-install-YYYYMMDD-HHMMSS.log`

## Customization

To use your own dotfiles repository, modify the clone command in the script:
```bash
git clone https://github.com/your-username/dotfiles /tmp/dotfiles
```

## ZSH Aliases

The following aliases are configured in the `.zshrc` file:

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `ls -alh --color=always` | List all files with human-readable sizes and colors |
| `grep` | `grep --color=auto` | Colorized grep output |
| `gs` | `git status` | Show git working tree status |
| `ga` | `git add .` | Stage all changes |
| `gc` | `git commit -m` | Commit with message |
| `gp` | `git push origin main` | Push to main branch |
| `gpl` | `git pull` | Pull from remote |
| `ld` | `lazydocker` | Launch lazydocker TUI for Docker management |
| `lg` | `lazygit` | Launch lazygit TUI for Git operations |

## ZSH Functions

Custom functions included in the `.zshrc` file:

### gacp
Git add, commit, and push in one command. Automatically pushes to the current branch.

**Example:**
```bash
gacp "Fixed bug in authentication"
```

### extract
Universal extraction function that automatically detects archive type and extracts accordingly. Uses multi-threaded XZ extraction for faster decompression.

**Supported formats:**
- `.tar.bz2`, `.tbz2` - Bzip2 compressed tar
- `.tar.xz`, `.txz` - XZ compressed tar
- `.tar.gz`, `.tgz` - Gzip compressed tar
- `.tar`, `.cbt` - Uncompressed tar
- `.tar.zst` - Zstandard compressed tar
- `.zip`, `.cbz` - ZIP archives
- `.rar`, `.cbr` - RAR archives
- `.7z` - 7-Zip archives
- `.bz2`, `.xz`, `.gz` - Individual compressed files
- `.arj`, `.ace` - Legacy archive formats
- `.gpg` - GPG encrypted tar.gz

**Example:**
```bash
extract myfile.tar.gz
```

### pack
Create archives in various formats from files or directories.

**Supported formats:**
- `txz` - XZ compressed tar (`.tar.xz`)
- `tbz` - Bzip2 compressed tar (`.tar.bz2`)
- `tgz` - Gzip compressed tar (`.tar.gz`)
- `tar` - Uncompressed tar (`.tar`)
- `bz2` - Bzip2 compression
- `gz` - Gzip compression (level 9)
- `zip` - ZIP archive
- `7z` - 7-Zip archive

**Example:**
```bash
pack txz myproject
# Creates: myproject.tar.xz
```
