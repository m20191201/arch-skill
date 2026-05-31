---
name: arch
description: >-
  Arch Linux system administration skill. Use this skill whenever the user asks about
  installing packages, managing services, configuring their system, maintaining or
  troubleshooting Arch Linux, or when you detect the host is Arch. Trigger on mentions
  of pacman, yay, makepkg, PKGBUILD, systemctl, journalctl, mkinitcpio, grub, arch-chroot,
  reflector, pacman.conf, mirrorlist, linux kernel, AUR, or any Arch system task. Also
  trigger when the user wants to install software (npm/pip/cargo global tools, CLI
  utilities, system packages) on an Arch system — this skill enforces pacman/AUR-first
  package resolution.
---

# Arch Linux System Administration

Arch Linux is a rolling-release distribution using pacman for package management,
systemd for services, and a do-it-yourself approach to system configuration. This skill
ensures you always prefer native Arch/pacman tools over generic cross-platform
alternatives.

## Core Principle: Pacman First

On an Arch system, **always prefer native package management** over language-specific
installers. This avoids version conflicts, ensures system-wide updates catch everything,
and keeps the system clean.

### Package Resolution Decision Tree

When the user needs to install software, follow this order:

```
1. Is it available via pacman?
   $ pacman -Ss <name>
   YES -> sudo pacman -S <package>
   NO  -> go to step 2

2. Is it available in the AUR?
   $ yay -Ss <name>
   YES -> yay -S <package>  (prefer -bin variants for large packages)
   NO  -> go to step 3

3. Use language-specific installer IN ISOLATION ONLY:
   - pip:   python -m venv .venv && source .venv/bin/activate && pip install <pkg>
   - npm:   npm install <pkg>            (local node_modules, NEVER npm -g)
   - cargo: cargo install <pkg>          (goes to ~/.cargo/bin)
   - go:    go install <pkg>@latest      (goes to ~/go/bin)

NEVER: sudo pip install, sudo npm install -g, or any global language-specific install.
Global CLI tools MUST come from pacman or AUR.
```

### Common Equivalence: Generic -> Arch

| Instead of...                | Use...                          |
|-----------------------------|----------------------------------|
| `apt install htop`          | `sudo pacman -S htop`           |
| `brew install htop`         | `sudo pacman -S htop`           |
| `snap install code`         | `yay -S visual-studio-code-bin` |
| `curl -fsSL ... \| sh`     | Check `pacman -Ss` / `yay -Ss` first |
| `npm -g install neovim`    | `sudo pacman -S neovim`         |
| `cargo install fd`          | `sudo pacman -S fd`             |
| `pip install httpie`       | `sudo pacman -S httpie`         |

For the full equivalence table and command reference, read `references/packages.md`.

## Package Management Quick Reference

```bash
# Install / Remove
sudo pacman -S <pkg>                   # install from repos
sudo pacman -S --needed <pkg>           # skip if already current (idempotent)
sudo pacman -Rns <pkg>                 # remove + deps + config (cleanest)

# Search / Info
pacman -Ss <query>                  # search remote repos
pacman -Qs <query>                  # search installed
pacman -Qi <pkg>                    # installed package info
pacman -Qo /path/to/file           # which package owns this file

# System Update (ALWAYS full upgrade, never partial)
sudo pacman -Syu                    # sync + full upgrade
sudo pacman -Syyu                   # force refresh + upgrade (after mirror change)

# AUR with yay
yay -S <pkg>                        # install from AUR or repos
yay -Ss <query>                     # search repos + AUR
yay -Sua                            # upgrade AUR packages only
yay -Syu                            # upgrade everything

# AUR with paru (alternative to yay, Rust-based, faster)
paru -S <pkg>                       # install from AUR or repos
paru -Ss <query>                    # search repos + AUR
paru -Sua                           # upgrade AUR packages only
paru -Syu                           # upgrade everything
```

**AUR helper installation:**
```bash
# Install yay
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
cd /tmp/yay-bin && makepkg -si && cd && rm -rf /tmp/yay-bin

# Install paru
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
cd /tmp/paru-bin && makepkg -si && cd && rm -rf /tmp/paru-bin
```

**Critical rule:** Never run `pacman -Sy <package>` — this causes partial upgrades and
breaks shared library dependencies. Always use `-Syu`.

## systemd Services

```bash
sudo systemctl start/stop/restart <unit>     # immediate control
sudo systemctl enable --now <unit>           # enable at boot + start now
sudo systemctl disable <unit>                # disable at boot
systemctl status <unit>                      # status + recent logs
systemctl --failed                           # list failed units
journalctl -u <unit> -f                      # follow logs for a unit
journalctl -p err -b                         # all errors since boot
```

For unit file templates (daemon, oneshot, timer, user service, socket activation),
hardening directives, and timer syntax, read `references/systemd-recipes.md`.

## System Configuration

### pacman.conf (`/etc/pacman.conf`)

Key settings to know:

```ini
[options]
ParallelDownloads = 5          # concurrent downloads (default 1)
Color                          # colorized output
CheckSpace                     # verify disk space before install
IgnorePkg = <pkg1> <pkg2>      # hold packages from upgrading
```

Enable `[multilib]` for 32-bit support (Steam, Wine).

### Mirror Management

```bash
sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syyu                           # ALWAYS refresh after mirror change
```

### Kernel Management

```bash
pacman -Qs linux | grep "^linux"            # list installed kernels
sudo pacman -S linux-lts                    # install LTS kernel (fallback)
sudo pacman -S linux                        # install latest kernel
```

Always keep at least two kernels installed as fallback (e.g., `linux` + `linux-lts`).

### GPU Drivers

```bash
# Check GPU
lspci -k | grep -A 3 VGA

# NVIDIA
sudo pacman -S nvidia-dkms nvidia-utils
sudo mkinitcpio -P

# AMD (open-source)
sudo pacman -S mesa lib32-mesa xf86-video-amdgpu

# Intel
sudo pacman -S mesa lib32-mesa xf86-video-intel
```

### Initramfs (mkinitcpio)

```bash
sudo mkinitcpio -P                           # rebuild all presets
sudo mkinitcpio -p linux                     # rebuild specific preset
```

**Important:** After kernel changes, GPU driver changes, or editing
`/etc/mkinitcpio.conf`, always rebuild initramfs.

## System Maintenance

### Regular Maintenance Checklist

```bash
# 1. Full system update
sudo pacman -Syu

# 2. Update AUR packages
yay -Sua

# 3. Remove orphaned packages
sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null

# 4. Clean package cache (keep last 3 versions)
paccache -r                                  # needs pacman-contrib

# 5. Check for failed services
systemctl --failed

# 6. Manage journal size
journalctl --disk-usage
sudo journalctl --vacuum-size=500M

# 7. Handle .pacnew config files
sudo pacdiff                                 # from pacman-contrib
```

### Health Check Commands

```bash
uname -r                                     # current kernel
df -h / /home /boot                          # disk usage
free -h                                      # memory
systemctl --failed                           # failed services
pacman -Qtdq | wc -l                         # orphan count
journalctl --disk-usage                      # journal size
checkupdates | wc -l                         # pending updates
```

### Pre-Destructive Operation Checklist

Before any operation that could break the system, run through this:

```
[ ] At least 2 kernels installed?
    pacman -Qs linux | grep "^linux"
[ ] Current state is bootable?
    systemctl is-system-running
[ ] Network available for recovery packages?
    ping -c 1 archlinux.org
[ ] Know how to chroot from live USB?
    Boot live USB -> mount partitions -> sudo arch-chroot /mnt
```

**Operations that require this checklist:**
- `pacman -Syu` (major updates with kernel changes)
- `sudo pacman -S linux / linux-lts` (kernel install/remove)
- `sudo mkinitcpio -P` (initramfs rebuild)
- `grub-mkconfig -o /boot/grub/grub.cfg` (GRUB reconfiguration)
- Editing `/etc/fstab`, `/etc/mkinitcpio.conf`, `/etc/default/grub`

## Boot Loaders

### systemd-boot (UEFI only, simpler than GRUB)

```bash
# Install to ESP
sudo bootctl install

# Check status
bootctl status

# Add entry: /boot/loader/entries/arch.conf
#   title   Arch Linux
#   linux   /vmlinuz-linux
#   initrd  /initramfs-linux.img
#   options root=PARTUUID=xxxx rw

# Update loader config: /boot/loader/loader.conf
#   default arch.conf
#   timeout 4
#   console-mode max
#   editor  no

# Automatically generate entries (with kernel hook)
# Install: sudo pacman -S systemd-boot-update
```

### GRUB

```bash
# UEFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# BIOS/MBR
grub-install --target=i386-pc /dev/sdX
grub-mkconfig -o /boot/grub/grub.cfg
```

## Native Package Managers on Arch (Flatpak / Snap)

Arch supports Flatpak and Snap alongside pacman for sandboxed/containerized apps:

### Flatpak

```bash
sudo pacman -S flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub <app-id>        # e.g., org.mozilla.firefox
flatpak run <app-id>
flatpak update
flatpak list
```

### Snap

```bash
yay -S snapd
sudo systemctl enable --now snapd.socket
sudo ln -s /var/lib/snapd/snap /snap
snap install <pkg>
```

## CPU Microcode

Always install microcode updates for security and stability:

```bash
# Intel
sudo pacman -S intel-ucode
# AMD
sudo pacman -S amd-ucode
```

GRUB will detect and load microcode automatically. For systemd-boot, ensure
`initrd /intel-ucode.img` comes before `initrd /initramfs-linux.img` in the entry.

## DKMS (Dynamic Kernel Module Support)

DKMS rebuilds kernel modules automatically when the kernel is updated:

```bash
# Install DKMS
sudo pacman -S dkms

# After any kernel update, DKMS modules are auto-rebuilt
# Check status:
dkms status

# Manually rebuild all DKMS modules:
sudo dkms autoinstall
```

Common packages providing DKMS modules: `nvidia-dkms`, `virtualbox-host-dkms`,
`broadcom-wl-dkms`, `zfs-dkms`.

## Btrfs Snapshots (Snapper / Timeshift)

For Btrfs filesystems, snapshots provide safe rollback after updates:

```bash
# Snapper (official Arch tooling)
sudo pacman -S snapper
sudo snapper -c root create-config /
sudo snapper list-configs
sudo snapper -c root create -d "before-update"
sudo snapper -c root list
sudo snapper -c root undochange 1..0         # rollback to snapshot 1

# Timeshift (GUI alternative, in AUR)
yay -S timeshift
```

## Laptop & Power Management

```bash
# Power profiles (modern, systemd-integrated)
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
powerprofilesctl list
powerprofilesctl set <balanced|power-saver|performance>

# TLP (advanced battery optimization, alternative)
sudo pacman -S tlp tlp-rdw
sudo systemctl enable --now tlp
sudo tlp-stat -s                              # status

# Suspend/resume debugging
journalctl -b | grep "PM: suspend"
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## Network Management Options

```bash
# NetworkManager (default, full-featured)
sudo pacman -S networkmanager
sudo systemctl enable --now NetworkManager
nmcli device status
nmcli connection up <name>

# iwd (lightweight Wi-Fi daemon, pure Wi-Fi only)
sudo pacman -S iwd
# Configure to work with NetworkManager:
# echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf
# Or use standalone:
sudo systemctl enable --now iwd
iwctl                                           # interactive prompt
#   station wlan0 scan
#   station wlan0 get-networks
#   station wlan0 connect <SSID>

# systemd-networkd (no NetworkManager at all)
sudo systemctl enable --now systemd-networkd systemd-resolved
```

## Security & Auditing

```bash
# arch-audit — check installed packages for known CVEs
yay -S arch-audit
arch-audit

# Firejail — sandbox applications
sudo pacman -S firejail firejail-gui
firejail firefox                             # run in sandbox

# Lynis — system security audit
yay -S lynis
sudo lynis audit system

# ClamAV — antivirus (for scanning files, not real-time)
sudo pacman -S clamav
sudo freshclam
clamscan -r /home
```

## Testing / Unstable Repositories

Advanced users can enable bleeding-edge packages (not recommended for production):

```ini
# /etc/pacman.conf — enable BEFORE [core]
[testing]
Include = /etc/pacman.d/mirrorlist
# [community-testing]
# Include = /etc/pacman.d/mirrorlist
# [multilib-testing]
# Include = /etc/pacman.d/mirrorlist
```

**WARNING:** Mixing testing and stable repos can break dependencies. Only enable if
you understand the risks and are prepared to troubleshoot.

## Troubleshooting Quick Reference

For full diagnosis-to-fix flows covering 12 common scenarios (broken updates, GPU issues,
lock files, filesystem corruption, boot failures, dependency conflicts, keyring problems,
sound/network issues, permissions, disk space, clock), read `references/troubleshooting.md`.

### Emergency Recovery (from live USB)

```bash
# 1. Boot Arch live USB
# 2. Mount root partition
mount /dev/sdXn /mnt
mount /dev/sdXn /mnt/boot   # if separate boot partition
# 3. Chroot
sudo arch-chroot /mnt

# 4. Inside chroot — common fixes:
pacman -Syu                                  # complete interrupted upgrade
mkinitcpio -P                                # rebuild initramfs
grub-mkconfig -o /boot/grub/grub.cfg         # fix GRUB

# 5. Exit and reboot
exit
reboot
```

## Reference Files

Read these on-demand when you need detailed information:

- **`references/packages.md`** — Full pacman/paru/yay command reference, advanced queries,
  cache management, makepkg config, package groups, downgrading, useful one-liners,
  complete generic-to-arch equivalence tables.
- **`references/systemd-recipes.md`** — Unit file templates for every service type,
  timer syntax and examples, journal management, boot analysis, security hardening,
  drop-in overrides, dependency ordering, systemd-networkd/resolved/boot/nspawn.
- **`references/troubleshooting.md`** — 22 common issues with structured
  symptoms/diagnosis/fix flows: broken updates, GPU, lock files, filesystem corruption,
  boot failures, dependency conflicts, keyring, sound, network, permissions, disk space,
  clock, hooks, Bluetooth, printers, USB, virtualization, Wayland, suspend, SSD TRIM,
  LUKS, backlight issues.
