# Package Management Reference

Complete pacman, paru, yay, and makepkg command reference with equivalence tables.

## Table of Contents

1. [Generic to Arch Equivalence Tables](#generic-to-arch-equivalence-tables)
2. [pacman Operations](#pacman-operations)
3. [yay (AUR Helper)](#yay-aur-helper)
4. [paru (AUR Helper, Rust)](#paru-aur-helper-rust)
5. [makepkg (Manual AUR Builds)](#makepkg-manual-aur-builds)
6. [Cache Management](#cache-management)
7. [Downgrading Packages](#downgrading-packages)
8. [pacman.conf Reference](#pacmanconf-reference)
9. [Advanced Queries](#advanced-queries)
10. [Useful One-Liners](#useful-one-liners)

---

## Generic to Arch Equivalence Tables

### Package Managers

| Generic / Other Distro        | Arch Equivalent                               |
|-------------------------------|-----------------------------------------------|
| `apt install <pkg>`           | `sudo pacman -S <pkg>`                        |
| `apt remove <pkg>`            | `sudo pacman -Rs <pkg>`                       |
| `apt update`                  | `sudo pacman -Sy` (but always use `-Syu`)     |
| `apt upgrade`                 | `sudo pacman -Syu`                            |
| `apt search <query>`          | `pacman -Ss <query>`                          |
| `apt show <pkg>`              | `pacman -Si <pkg>`                            |
| `apt autoremove`              | `sudo pacman -Rns $(pacman -Qtdq)`            |
| `dnf install <pkg>`           | `sudo pacman -S <pkg>`                        |
| `dnf remove <pkg>`            | `sudo pacman -Rs <pkg>`                       |
| `dnf update`                  | `sudo pacman -Syu`                            |
| `zypper install <pkg>`        | `sudo pacman -S <pkg>`                        |
| `brew install <pkg>`          | `sudo pacman -S <pkg>` or `yay -S <pkg>`      |
| `snap install <pkg>`          | `yay -S <pkg>` (search AUR for `-bin` pkgs)   |

### Other Package Managers -> Arch

| Instead of...                  | Use...                                    | Notes                              |
|--------------------------------|-------------------------------------------|------------------------------------|
| `nix install <pkg>`            | `sudo pacman -S <pkg>`                    | Search pacman first                |
| `winget install <pkg>`         | `sudo pacman -S <pkg>` or `yay -S <pkg>`  |                                    |
| `choco install <pkg>`          | `sudo pacman -S <pkg>` or `yay -S <pkg>`  |                                    |
| `port install <pkg>`           | `sudo pacman -S <pkg>`                    | MacPorts equivalent                |
| `flatpak install <pkg>`        | `sudo pacman -S <pkg>` first              | Flatpak for sandboxed apps only    |
| `snap install <pkg>`           | `yay -S <pkg>` (search AUR for `-bin`)    |                                    |

### Language-Specific -> Pacman/AUR

| Instead of...                        | Use...                                    | Notes                          |
|--------------------------------------|-------------------------------------------|--------------------------------|
| `sudo pip install black`             | `sudo pacman -S python-black`             | Python pkgs prefixed `python-` |
| `sudo pip install ansible`           | `sudo pacman -S ansible`                  |                                |
| `sudo pip install pylint`            | `sudo pacman -S python-pylint`            |                                |
| `pip install poetry`                 | `sudo pacman -S python-poetry`            |                                |
| `pip install pipx`                   | `sudo pacman -S python-pipx`              |                                |
| `sudo npm install -g prettier`       | `yay -S prettier`                         | Check AUR                      |
| `sudo npm install -g typescript`     | `sudo pacman -S typescript`               | In extra repo                  |
| `sudo npm install -g eslint`         | `yay -S eslint`                           | Check AUR                      |
| `sudo npm install -g neovim`         | `sudo pacman -S neovim`                   |                                |
| `sudo gem install sass`              | `sudo pacman -S ruby-sass`                | Ruby pkgs prefixed `ruby-`     |
| `cargo install ripgrep`              | `sudo pacman -S ripgrep`                  |                                |
| `cargo install fd-find`              | `sudo pacman -S fd`                       |                                |
| `cargo install bat`                  | `sudo pacman -S bat`                      |                                |
| `cargo install eza`                  | `sudo pacman -S eza`                      |                                |
| `cargo install zoxide`               | `sudo pacman -S zoxide`                   |                                |
| `go install lazygit`                 | `sudo pacman -S lazygit`                  |                                |
| `curl -fsSL ... \| sh` (any script) | Search `pacman -Ss` / `yay -Ss` first     | Prefer packaged version        |
| `snap install code`                  | `yay -S visual-studio-code-bin`           |                                |
| `snap install slack`                 | `yay -S slack-desktop`                    |                                |

### When Language-Specific Installers ARE Acceptable

These are fine because they install locally (not globally):

```bash
# Python: always in a venv
python -m venv .venv && source .venv/bin/activate
pip install <project-deps>

# Node.js: local node_modules
npm install <pkg>                # project-local
npx <tool>                      # one-shot without install

# Rust: cargo install goes to ~/.cargo/bin (user-local)
cargo install <pkg>             # OK for user tools not in repos

# Go: goes to ~/go/bin
go install <pkg>@latest         # OK for user tools not in repos
```

**Rule:** If the tool should be available system-wide or is a CLI utility, it MUST come
from pacman or AUR. Language-specific installers are only for project dependencies or
when the package genuinely does not exist in repos/AUR.

---

## pacman Operations

### Install (-S)

```bash
sudo pacman -S <pkg>                         # install from repos
sudo pacman -S <p1> <p2> <p3>               # install multiple
sudo pacman -S --needed <pkg>                # skip if already current (idempotent)
sudo pacman -S --noconfirm <pkg>             # no prompts (scripting)
sudo pacman -S extra/<pkg>                   # from a specific repo
sudo pacman -S --asdeps <pkg>                # mark as dependency
sudo pacman -U /path/to/file.pkg.tar.zst    # install local package
sudo pacman -U https://example.com/pkg.tar.zst  # install from URL
sudo pacman -Sp <pkg>                          # print download URL (dry run)
sudo pacman -Sp --print-format '%r/%n-%v' <pkg>  # custom format
```

### Remove (-R)

```bash
sudo pacman -R <pkg>                         # remove package only
sudo pacman -Rs <pkg>                        # remove + orphaned deps
sudo pacman -Rns <pkg>                       # remove + deps + config (cleanest)
sudo pacman -Rdd <pkg>                       # force, skip dep checks (DANGEROUS)
sudo pacman -Rc <pkg>                        # remove + all reverse deps (CASCADE)
```

| Command | Package | Unused Deps | Config Files | Dep Check |
|---------|---------|-------------|--------------|-----------|
| `-R`    | removed | kept        | kept         | yes       |
| `-Rs`   | removed | removed     | kept         | yes       |
| `-Rns`  | removed | removed     | removed      | yes       |
| `-Rdd`  | removed | kept        | kept         | SKIPPED   |

### Query Installed (-Q)

```bash
pacman -Q                                    # list ALL installed
pacman -Qe                                   # explicitly installed (not deps)
pacman -Qd                                   # installed as dependencies
pacman -Qm                                   # foreign (AUR, manual)
pacman -Qn                                   # native (from repos)
pacman -Qdt                                  # orphans: deps no longer needed
pacman -Qdtq                                 # orphans: names only (pipe-friendly)
pacman -Qs <query>                           # search installed (name+desc)
pacman -Qi <pkg>                             # detailed info
pacman -Ql <pkg>                             # list all files from package
pacman -Qo /path/to/file                     # which package owns this file
pacman -Qk <pkg>                             # verify files (missing/modified)
pacman -Qkk <pkg>                            # deep verify (checksums)
```

### Search Remote (-Ss / -Si)

```bash
pacman -Ss <query>                           # search by name+description
pacman -Ss '^vim$'                           # exact name match (regex)
pacman -Si <pkg>                             # detailed remote info
pacman -Sl                                   # list all packages in all repos
pacman -Sl extra                             # list packages in specific repo
```

### File Database (-F)

```bash
sudo pacman -Fy                              # sync file database (run first)
pacman -F <filename>                         # which package provides a file
pacman -Fl <pkg>                             # list files in a remote package
```

### Check Installable (-T)

```bash
pacman -T <pkg>                               # check if pkg can be installed — exit 0/1
pacman -T <pkg1> <pkg2>                       # check multiple at once
```

Useful in scripts to verify packages exist before attempting installation.
Returns 0 (success) only if all named packages are available in the repos.

### System Upgrade (-Syu)

```bash
sudo pacman -Syu                             # sync + full upgrade
sudo pacman -Syyu                            # force refresh + upgrade
sudo pacman -Syyuu                           # force + allow downgrades (branch switch)
```

**NEVER** run `sudo pacman -Sy <package>` — partial upgrades break the system.

### Package Groups

```bash
pacman -Sg                                   # list all groups
pacman -Sg base-devel                        # packages in a group
sudo pacman -S base-devel                    # install entire group
```

Common groups: `base-devel` (build tools), `xfce4`, `kde-applications`.

### Database Operations (-D)

```bash
sudo pacman -D --asdeps <pkg>                # mark as dependency
sudo pacman -D --asexplicit <pkg>            # mark as explicitly installed
```

---

## yay (AUR Helper)

### Basic Usage

```bash
yay -S <pkg>                                 # install (repos or AUR)
yay -S --noconfirm <pkg>                     # no prompts
yay                                          # alias for yay -Syu
yay -Ss <query>                              # search repos + AUR
yay -Si <pkg>                                # info (repo or AUR)
yay -Ps                                      # stats (counts, sizes)
```

### Upgrade

```bash
yay -Syu                                     # upgrade repos + AUR
yay -Sua                                     # upgrade AUR only
```

### Clean

```bash
yay -Yc                                      # remove unneeded deps
yay -Sc                                      # clean cache
```

### Recommended Config

```bash
yay --devel --save                           # track -git packages
yay --cleanafter --save                      # auto-clean build dirs
yay --removemake --save                      # remove makedeps after build
yay --batchinstall --save                    # batch install (faster)
yay --sudoloop --save                        # keep sudo alive during long builds
```

### Directories

- Build: `~/.cache/yay/<package>/`
- Config: `~/.config/yay/config.json`

---

## paru (AUR Helper, Rust)

Alternative to yay — faster, with built-in devtools integration.

### Basic Usage

```bash
paru -S <pkg>                                 # install (repos or AUR)
paru -S --noconfirm <pkg>                     # no prompts
paru                                         # alias for paru -Syu
paru -Ss <query>                              # search repos + AUR
paru -Si <pkg>                                # info (repo or AUR)
paru -Ps                                      # stats
```

### Upgrade

```bash
paru -Syu                                     # upgrade repos + AUR
paru -Sua                                     # upgrade AUR only
```

### Unique Features (vs yay)

```bash
paru -G <pkg>                                 # download PKGBUILD without building
paru -Gp <pkg>                                # print PKGBUILD to stdout
paru --repo                                   # force repo search only
paru --aur                                    # force AUR search only
paru --skipreview                             # skip PKGBUILD review (use with caution)
```

### Recommended Config (`/etc/paru.conf` or `~/.config/paru/paru.conf`)

```ini
[options]
BottomUp = true              # show AUR results after repos
SudoLoop = true              # keep sudo alive during builds
CleanAfter = true            # remove build dirs after install
RemoveMake = true            # remove make dependencies
BatchInstall = false         # review each PKGBUILD individually
SkipReview = false           # always review PKGBUILDs
```

### Migration from yay

```bash
# Export explicit package list
pacman -Qqe > pkglist.txt

# Install paru
git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
cd /tmp/paru-bin && makepkg -si && cd && rm -rf /tmp/paru-bin

# Restore packages
sudo pacman -S --needed - < pkglist.txt
```

---

## makepkg (Manual AUR Builds)

```bash
git clone https://aur.archlinux.org/<pkg>.git
cd <pkg>
less PKGBUILD                                # ALWAYS review before building
makepkg -si                                  # install deps + build + install
namcap PKGBUILD                              # lint the PKGBUILD
namcap <pkg>.pkg.tar.zst                     # lint the built package
```

### makepkg Flags

```bash
makepkg -s                                   # auto-install missing deps
makepkg -i                                   # install after building
makepkg -si                                  # both (most common)
makepkg -c                                   # clean build dir after
makepkg -f                                   # force rebuild
makepkg --nocheck                            # skip check() function
```

### makepkg.conf Optimization

Edit `/etc/makepkg.conf` or `~/.makepkg.conf`:

```bash
MAKEFLAGS="-j$(nproc)"                       # parallel compilation
COMPRESSZST=(zstd -c -T0 --ultra -20 -)     # max compression
PACKAGER="Name <email>"                      # identify in packages
BUILDDIR=/tmp/makepkg                        # build in RAM (faster)
```

---

## Cache Management

```bash
# pacman built-in
sudo pacman -Sc                              # remove uninstalled from cache
sudo pacman -Scc                             # remove ALL cached (nuclear)

# paccache (from pacman-contrib, recommended)
paccache -d                                  # dry run
paccache -r                                  # keep last 3 versions
paccache -rk 1                               # keep only latest
paccache -ruk 0                              # remove all uninstalled cache

# Cache location and size
ls /var/cache/pacman/pkg/
du -sh /var/cache/pacman/pkg/
```

---

## Downgrading Packages

```bash
# From local cache
sudo pacman -U /var/cache/pacman/pkg/<pkg>-<old-version>.pkg.tar.zst

# Using downgrade tool (AUR)
yay -S downgrade
sudo downgrade <pkg>                         # interactive version picker

# Pin version to prevent upgrade
# Add to /etc/pacman.conf under [options]:
# IgnorePkg = <package>
```

---

## pacman.conf Reference

Key settings in `/etc/pacman.conf`:

```ini
[options]
ParallelDownloads = 5          # concurrent downloads (default 1)
Color                          # colorized output
ILoveCandy                     # Pac-Man progress bar
VerbosePkgLists                # show old/new version on upgrade
CheckSpace                     # verify disk space before install
SigLevel = Required DatabaseOptional  # require package signatures
IgnorePkg = <pkg1> <pkg2>      # hold packages at current version
IgnoreGroup = <group>          # hold entire group

# Repository order = priority
[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]                     # uncomment for 32-bit (Steam, Wine)
Include = /etc/pacman.d/mirrorlist
```

---

## Advanced Queries

### Check if packages are installable (-T)

```bash
pacman -T <pkg>                               # check if pkg can be installed (returns 0)
pacman -T <pkg1> <pkg2>                       # check multiple
```

Returns 0 (success) if all packages exist and have no conflicts — useful in scripts.

### Print download URLs (-Sp)

```bash
pacman -Sp <pkg>                              # print download URL without installing
pacman -Sp --print-format '%r/%n-%v' <pkg>    # custom format (repo/name-version)
```

### Package file database (-F)

```bash
sudo pacman -Fy                               # sync file database
pacman -F <filename>                          # which package provides this file
pacman -Fx <pattern>                          # regex search in file database
pacman -Fl <pkg>                              # list files in a remote package
```

### pkgfile (lightweight alternative to pacman -F)

```bash
sudo pacman -S pkgfile                        # install
sudo pkgfile -u                               # update database
pkgfile <filename>                            # find package owner
pkgfile -i <filename>                         # case-insensitive
pkgfile -l <pkg>                              # list files in package
```

### expac (advanced querying)

```bash
sudo pacman -S expac

# Format: %<field>
expac "%n %v %d"                              # name, version, description
expac -l '\n' "%n" -H "Installed:" -Q         # list all installed
expac -l '\n' "%n" -H "Foreign:" -Qm          # list foreign (AUR) packages
expac -s '%n' -Q '^(linux|linux-lts|linux-zen)$'  # regex matching
expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -20  # recently installed
```

### Package signing verification

```bash
pacman-key --list-keys                        # list trusted keys
pacman-key --finger <keyid>                   # show fingerprint
pacman-key --refresh-keys                     # update keyring
pacman -Qik <pkg>                             # verify package signature
sudo pacman -D --check                        # verify database integrity
```

### AUR security auditing

```bash
# aurphan — find orphaned AUR packages
yay -S aurphan
aurphan

# Check PKGBUILD for suspicious content
git clone https://aur.archlinux.org/<pkg>.git
cd <pkg>
grep -E "(source=.*http|curl|wget|chmod 777|sudo|rm -rf /)" PKGBUILD

# Check for -bin packages that may be outdated
yay -Sua --devel                               # check AUR -git updates
```

---

## Useful One-Liners

```bash
# Remove all orphans
sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null

# List AUR/foreign packages
pacman -Qem

# 20 largest installed packages
pacman -Qi | awk '/^Name/{name=$3} /^Installed Size/{print $4$5, name}' | sort -rh | head -20

# Export package list (for migration/backup)
pacman -Qqe > pkglist.txt

# Restore from list
sudo pacman -S --needed - < pkglist.txt

# Recently installed packages
expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -20

# Find .pacnew/.pacsave files (config changes after update)
find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null

# Interactively merge .pacnew files
sudo pacdiff                                 # from pacman-contrib

# Verify all packages for corruption
pacman -Qk 2>/dev/null | grep -v ' 0 missing'

# Count installed packages
pacman -Q | wc -l                            # total
pacman -Qe | wc -l                           # explicit
pacman -Qm | wc -l                           # AUR/foreign
```
