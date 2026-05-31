---
description: "Arch Linux system admin: health check, smart install, troubleshooting, cleanup, kernel management, snapshots"
allowed-tools: ["Bash", "Read"]
---

# /arch

Unified Arch Linux system administration command. Parse `$ARGUMENTS` to determine
which subcommand to run.

## Routing

- **No arguments or `help`**: Show the help message below and stop.
- **`check`**: Run the [System Health Check](#check).
- **`install <package>`**: Run the [Smart Installer](#install).
- **`upgrade`**: Run the [Smart Upgrader](#upgrade).
- **`clean`**: Run the [System Cleanup](#clean).
- **`kernel`**: Run the [Kernel Management](#kernel).
- **`snapshot`**: Run the [Snapshot Manager](#snapshot).
- **`log <unit>`**: Run the [Log Viewer](#log).
- **`rescue <symptoms>`**: Run the [Guided Troubleshooting](#rescue).
- **Anything else**: Show the help message and suggest the closest subcommand.

## Help Message

```
/arch — Arch Linux system administration

Subcommands:
  /arch check                System health check (disk, services, updates, kernels)
  /arch install <package>    Smart package installer (pacman/AUR-first)
  /arch upgrade              Smart system upgrade with pre-flight checks
  /arch clean                Clean orphaned packages, cache, journal, .pacnew files
  /arch kernel               List/install kernels, rebuild initramfs
  /arch snapshot             Snapper: create/list/rollback Btrfs snapshots
  /arch log <unit>           View recent logs for a systemd unit
  /arch rescue <symptoms>    Guided troubleshooting from symptom description
  /arch help                 Show this message
```

---

## check

Run these commands and present results as a formatted health summary:

```bash
# OS and kernel
uname -r
grep PRETTY_NAME /etc/os-release

# Disk usage (warn if any partition >85%)
df -h / /home /boot /boot/efi 2>/dev/null

# Failed systemd units
systemctl --failed --no-pager

# Pending updates
checkupdates 2>/dev/null | wc -l

# Orphaned packages
pacman -Qtdq 2>/dev/null | wc -l

# Journal disk usage (warn if >500MB)
journalctl --disk-usage 2>/dev/null

# Installed kernels
pacman -Qs linux | grep "^linux " 2>/dev/null
```

Format output as a summary table with status indicators:
- Items in good shape: state the value
- Items needing attention: flag them and suggest the fix command

Example suggestions:
- Orphans > 0: "Run `sudo pacman -Rns $(pacman -Qtdq)` to clean up"
- Journal > 500MB: "Run `sudo journalctl --vacuum-size=500M`"
- Updates available: "Run `sudo pacman -Syu`"
- Failed services: list them and suggest `journalctl -u <unit> -b` for each
- Only one kernel installed: suggest installing `linux-lts` as fallback

---

## install

Smart package installer that enforces the pacman/AUR-first resolution hierarchy.

Given `$ARGUMENTS` with `install` removed, the remaining text is the package name(s).

### Step 1: Search official repos

```bash
pacman -Ss <package>
```

Present any matches found, highlighting exact name matches.

### Step 1.5: Check if AUR helper is installed

If `yay` is not found, try `paru`. If neither is available, suggest
installing one:

```bash
# Check
which yay 2>/dev/null || which paru 2>/dev/null || echo "No AUR helper found"
```

If no AUR helper is installed, offer to install `yay-bin` or `paru-bin`
before proceeding, or search AUR manually via web.

### Step 2: Search AUR

```bash
yay -Ss <package>    # or: paru -Ss <package>
```

Present AUR results separately from repo results.

### Step 3: Present findings and recommend

Show results organized by source:

```
Found in official repos:
  extra/package-name 1.2.3 — Description

Found in AUR:
  aur/package-name-bin 1.2.3 — Description (votes: 42, popularity: 1.5)
```

Recommend the best option following this priority:
1. Official repo match (prefer `extra` over `community`)
2. AUR match (prefer `-bin` variants for large packages)

If nothing found in repos or AUR, suggest the language-specific alternative with
proper isolation:
- Python: `python -m venv .venv && source .venv/bin/activate && pip install <pkg>`
- Node.js: `npm install <pkg>` (local only, never `-g`)
- Other: explain the isolated install approach

### Step 4: Confirm and install

Ask the user to confirm which package to install. Only after confirmation, run:

```bash
# For repo packages:
sudo pacman -S <package>

# For AUR packages:
yay -S <package>
```

If the user wants multiple packages, handle them in a single command.

---

## upgrade

Smart system upgrade with pre-flight safety checks.

### Step 1: Pre-flight checks

```bash
# Run health checks first (see check subcommand)
systemctl is-system-running
ping -c 1 archlinux.org &>/dev/null && echo "ok" || echo "no network"
```

Assess whether the system is healthy enough to upgrade. If not, suggest
`/arch rescue` first.

### Step 2: Check pending updates

```bash
checkupdates
```

If no updates available, inform the user and stop.

### Step 3: Check for kernel update

```bash
checkupdates 2>/dev/null | grep -E "^linux |^linux-lts |^linux-zen "
```

If a kernel update is detected, warn the user and suggest ensuring at least
2 kernels are installed before proceeding.

### Step 4: Confirm and upgrade

Present the list of pending updates and ask for confirmation. Only after
confirmation, run:

```bash
sudo pacman -Syu
```

If AUR packages are installed, suggest also running:

```bash
yay -Sua   # or paru -Sua
```

### Step 5: Post-upgrade checks

```bash
systemctl --failed                           # verify no new failures
journalctl -p err -b | tail -10             # recent errors since boot
```

If a new kernel was installed, remind the user to reboot.

---

## clean

System cleanup: orphans, cache, journal, .pacnew files, AUR build cache.

### Step 1: Show what can be cleaned

```bash
echo "=== Orphaned packages ==="
pacman -Qtdq 2>/dev/null | wc -l

echo "=== Cache size ==="
du -sh /var/cache/pacman/pkg/

echo "=== Journal size ==="
journalctl --disk-usage 2>/dev/null

echo "=== Yay cache size ==="
du -sh ~/.cache/yay/ 2>/dev/null

echo "=== .pacnew files ==="
find /etc -name "*.pacnew" 2>/dev/null | wc -l
```

### Step 2: Confirm and clean

Ask the user which cleanup operations to perform, then execute accordingly:

```bash
# Remove orphans
sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null

# Clean pacman cache (keep last 3 versions)
paccache -r

# Truncate journal
sudo journalctl --vacuum-size=500M

# Clean AUR build cache
rm -rf ~/.cache/yay/

# Merge .pacnew files
sudo pacdiff
```

---

## kernel

Kernel management: list, install, remove, rebuild initramfs.

### List installed kernels

```bash
pacman -Qs linux | grep "^linux " 2>/dev/null
```

### List all available kernels

```bash
pacman -Ss linux | grep "^core/linux"
```

### Install LTS kernel as fallback

If only one kernel is installed, recommend installing `linux-lts`:

```bash
sudo pacman -S linux-lts linux-lts-headers
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

For systemd-boot, kernel updates are automatic if `systemd-boot-update` is installed.

### Rebuild initramfs

```bash
sudo mkinitcpio -P
```

### Remove old kernel

```bash
# List installed kernels first
pacman -Qs linux | grep "^linux "

# Then remove unwanted kernel package
sudo pacman -Rns <unwanted-kernel-package>
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Safety:** always keep at least 2 kernels installed (e.g., `linux` + `linux-lts`).

---

## snapshot

Btrfs snapshot management via Snapper (if using Btrfs).

### Prerequisite check

```bash
# Only run if / is Btrfs
findmnt -n -o FSTYPE / | grep -q btrfs
# If not btrfs, inform user snapshots are unavailable
```

### List snapshots

```bash
sudo snapper -c root list
```

### Create snapshot

```bash
sudo snapper -c root create -d "<description>"
```

### Rollback to snapshot

Show the list, ask which number to rollback to, then:

```bash
sudo snapper -c root undochange <num>..0
```

---

## log

Quick log viewer for a systemd unit.

Parse `$ARGUMENTS` — after `log` is removed, the remaining text is the unit name.

```bash
# If a unit name was provided:
journalctl -u <unit> -n 50 --no-pager

# If no unit name: show recent high-priority logs
journalctl -p err -b -n 30 --no-pager
```

If the output looks truncated, suggest the user run the full command manually:

```bash
journalctl -u <unit> -f          # follow live
journalctl -u <unit> --since "1 hour ago"
journalctl -u <unit> -b          # since boot
```

---

## rescue

Guided troubleshooting based on free-text symptom description.

### Step 1: Read the troubleshooting guide

Read `references/troubleshooting.md` from the arch skill directory.

### Step 2: Match symptoms

Interpret the user's symptom description and match it to the closest issue in the
troubleshooting guide. The 22 documented issues are:

1. Broken system after update (partial upgrade, library errors)
2. No GUI after reboot (GPU/driver issues, black screen)
3. pacman lock file stuck
4. Filesystem corruption (read-only, I/O errors)
5. Boot failures (GRUB rescue, kernel panic)
6. Dependency conflicts (file conflicts, version conflicts)
7. Keyring / signature errors
8. No sound after update
9. Network not working
10. Broken permissions
11. Disk space full
12. Time/clock issues
13. Pacman hooks failing after update
14. Bluetooth not working
15. Printer not working (CUPS)
16. USB devices not recognized
17. Docker / virtualization issues
18. Wayland screen sharing not working
19. Suspend / hibernate issues
20. SSD TRIM not enabled
21. LUKS encryption issues
22. Laptop backlight not adjustable

### Step 3: Walk through the fix

Follow the structured flow from the guide:
1. Confirm the symptoms match
2. Run the diagnostic commands
3. Present the diagnosis
4. Walk through the fix steps one at a time
5. Verify the fix worked

If symptoms don't clearly match any documented issue, run the general diagnostic
commands from the guide and help narrow down the problem interactively.
