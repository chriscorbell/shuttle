<div align="center">
  <img src="https://i.imgur.com/E7QQ18h.png?raw=true" width="400" alt="shuttle"><br><br>
  shuttle is a streamlined setup script that automatically configures a fresh installation with shell enhancements, essential development tools and server-focused packages.<br>
  <br>
  <b>Supports Debian and Arch Linux.</b>
</div>
<br>

## Instructions

```bash
git clone https://github.com/chriscorbell/shuttle.git
cd shuttle
chmod +x shuttle.sh
./shuttle.sh
```
Or alternatively, curl-pipe into bash (don't forget to always read and verify the source before doing so):
```
curl https://raw.githubusercontent.com/chriscorbell/shuttle/main/shuttle.sh | bash
```

## What it Installs

### Configuration Changes
- **Passwordless sudo**: Autodetects group (wheel or sudo) to configure passwordless privilege elevation

### Base Packages
- **Shell**: zsh with [my .zshrc](https://github.com/chriscorbell/dotfiles/blob/main/.zshrc) which includes zinit with starship, atuin, syntax highlighting, completions, autosuggestions, fzf-tab, OMZ snippets, [aliases](#zsh-aliases) and [functions](#zsh-functions)
- **Development**: base build tools, wget, curl
- **Utilities**: pipx, lsd, fzf, zoxide, bat, btop, fastfetch
- **Archive tools**: tar, unzip, unrar, unar, unace, bzip2, xz, 7zip (for [pack](#pack) and [extract](#extract) zsh functions)
- **Git, GitHub CLI and lazygit**
- **Docker, Docker Compose and lazydocker**
- **Terraform**
- **Ansible**

### Distribution-Specific:

Debian:
- Enables non-free and contrib repositories
- Installs nala frontend for apt

Arch:
- Installs yay AUR helper

## Post-Installation

After the script completes:

1. **Log out and log back in** for all changes to take effect
2. Your default shell will be zsh with custom configuration
3. Docker will be enabled and ready to use with your current non-root user (no sudo required)
4. Installations are logged to `/tmp/shuttle-install-YYYYMMDD-HHMMSS.log`

## Customization

To use your own dotfiles repository, modify the clone command in the script with:
```bash
git clone https://github.com/your-username/your-dotfiles /tmp/dotfiles
```
Your dotfiles repo needs to contain a `.zshrc` file and a `.config` directory.

## ZSH Aliases

The following aliases are configured in the `.zshrc` file:

| Alias | Command | Description |
|-------|---------|-------------|
| `cd` | `z` | Replace cd with zoxide |
| `ls` | `lsd -alh --color=always` | List all files and directories with human-readable sizes, colors and icons |
| `grep` | `grep --color=auto` | Colorized grep output |
| `gs` | `git status` | Show git working tree status |
| `ga` | `git add .` | Stage all changes |
| `gc` | `git commit -m` | Commit with message |
| `gp` | `git push origin main` | Push to main branch |
| `gpl` | `git pull` | Pull from remote |
| `ld` | `lazydocker` | Launch lazydocker TUI for Docker management |
| `lg` | `lazygit` | Launch lazygit TUI for Git operations |
| `up` | `sudo nala update && sudo nala full-upgrade -y` | Update and full upgrade (Debian) |
| `in` | `sudo nala install` | Install package with `in <package>' (Debian) |
| `un` | `sudo nala purge` | Remove package with `un <package>' (Debian) |
| `cat` | `batcat --theme ansi -pp` | Replace cat with bat (Debian) |
| `fzfp` | `fzf --preview='batcat --theme ansi -pp {}'` | fzf with bat preview (Debian) |
| `up` | `yay -Syu` | Update and upgrade (Arch) |
| `in` | `yay -S` | Install package with `in <package>' (Arch) |
| `un` | `yay -Rns` | Remove package with `un <package>' (Arch) |
| `cat` | `bat --theme ansi -pp` | Replace cat with bat (Arch) |
| `fzfp` | `fzf --preview='bat --theme ansi -pp {}'` | fzf with bat preview (Arch) |

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
