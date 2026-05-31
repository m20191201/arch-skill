# Arch Linux Troubleshooting Guide

Structured diagnosis-to-fix flows for common issues.

## Table of Contents

1. [Broken System After Update](#1-broken-system-after-update)
2. [No GUI After Reboot (GPU)](#2-no-gui-after-reboot-gpu)
3. [pacman Lock File Stuck](#3-pacman-lock-file-stuck)
4. [Filesystem Corruption](#4-filesystem-corruption)
5. [Boot Failures](#5-boot-failures)
6. [Dependency Conflicts](#6-dependency-conflicts)
7. [Keyring / Signature Errors](#7-keyring--signature-errors)
8. [No Sound After Update](#8-no-sound-after-update)
9. [Network Not Working](#9-network-not-working)
10. [Broken Permissions](#10-broken-permissions)
11. [Disk Space Full](#11-disk-space-full)
12. [Time/Clock Issues](#12-timeclock-issues)
13. [Pacman Hook Failures](#13-pacman-hook-failures)
14. [Bluetooth Not Working](#14-bluetooth-not-working)
15. [Printer Not Working (CUPS)](#15-printer-not-working-cups)
16. [USB Devices Not Recognized](#16-usb-devices-not-recognized)
17. [Docker / Virtualization Issues](#17-docker--virtualization-issues)
18. [Wayland Screen Sharing Not Working](#18-wayland-screen-sharing-not-working)
19. [Suspend / Hibernate Issues](#19-suspend--hibernate-issues)
20. [SSD TRIM Not Enabled](#20-ssd-trim-not-enabled)
21. [LUKS Encryption Issues](#21-luks-encryption-issues)
22. [Laptop Backlight Not Adjustable](#22-laptop-backlight-not-adjustable)
23. [General Diagnostic Commands](#general-diagnostic-commands)

---

## 1. Broken System After Update

**Symptoms:** Libraries not found, apps crash, `error while loading shared libraries`,
package conflicts during upgrade.

**Cause:** `pacman -Sy <package>` (partial upgrade) or interrupted upgrade.

**Fix (if bootable):**

```bash
sudo pacman -Syu                             # complete full upgrade
# If conflicts:
sudo pacman -Syu --overwrite '*'             # force overwrite (last resort)
```

**Fix (from live USB):**

```bash
# Mount partitions
lsblk -f                                     # identify partitions
mount /dev/sdXn /mnt
mount /dev/sdXn /mnt/boot                    # if separate boot partition
# Chroot
sudo arch-chroot /mnt
pacman -Syu                                  # complete upgrade
exit && reboot
```

**Persistent conflicts:**

```bash
# Identify conflict
sudo pacman -Syu 2>&1 | grep "conflicting"

# Remove conflicting package, then upgrade
sudo pacman -Rdd <conflicting-pkg>
sudo pacman -Syu
```

---

## 2. No GUI After Reboot (GPU)

**Symptoms:** Black screen, dropped to TTY, display manager fails.

**Diagnosis (from TTY: Ctrl+Alt+F2):**

```bash
systemctl status sddm                        # or gdm, lightdm
journalctl -u sddm -b --no-pager | tail -50
lspci -k | grep -A 3 VGA                    # GPU + loaded kernel module
lsmod | grep -i nvidia                       # check nvidia modules
```

**Fix NVIDIA:**

```bash
# Install NVIDIA drivers
sudo pacman -S nvidia-dkms nvidia-utils nvidia-settings
sudo mkinitcpio -P
sudo reboot
# Verify: nvidia-smi
```

**If mkinitcpio hooks need updating:**
Add `nvidia nvidia_modeset nvidia_uvm nvidia_drm` to `MODULES=` in
`/etc/mkinitcpio.conf`, then rebuild.

**Fix AMD:**

```bash
sudo pacman -S mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
sudo mkinitcpio -P && sudo reboot
```

**Fix Intel:**

```bash
sudo pacman -S mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel
sudo mkinitcpio -P && sudo reboot
```

**Fallback (software rendering, vesa):**

```bash
sudo pacman -S xf86-video-vesa
sudo mkinitcpio -P && sudo reboot
```

**Wayland issues (fall back to Xorg):**

```bash
# SDDM/KDE: set DisplayServer=x11 in /etc/sddm.conf.d/10-wayland.conf
# GDM/GNOME: set WaylandEnable=false in /etc/gdm/custom.conf
```

---

## 3. pacman Lock File Stuck

**Symptoms:** `unable to lock database`, `/var/lib/pacman/db.lck exists`.

**Fix:**

```bash
# Verify no pacman is running
ps aux | grep pacman

# If nothing running, remove lock
sudo rm /var/lib/pacman/db.lck
```

**If database corrupted after forced kill:**

```bash
sudo rm -r /var/lib/pacman/sync/
sudo pacman -Syy
```

---

## 4. Filesystem Corruption

**Symptoms:** Read-only filesystem, I/O errors, `structure needs cleaning`.

**ext4 (must be unmounted):**

```bash
sudo umount /dev/sdXn
sudo fsck.ext4 -f /dev/sdXn                  # force check
sudo fsck.ext4 -fy /dev/sdXn                 # auto-repair
```

**Btrfs:**

```bash
sudo btrfs check /dev/sdXn                   # read-only check (safe)
sudo btrfs check --repair /dev/sdXn          # repair (BACKUP FIRST)
sudo btrfs scrub start /                     # integrity scan (runs on mounted fs)
sudo btrfs scrub status /
```

**Root partition read-only — temporary fix:**

```bash
sudo mount -o remount,rw /                   # then run fsck from live USB
```

---

## 5. Boot Failures

### GRUB Rescue

**Symptoms:** `grub rescue>` prompt.

```bash
# From GRUB rescue
ls                                           # list partitions
ls (hd0,gpt2)/boot/grub/                     # find grub
set root=(hd0,gpt2)
set prefix=(hd0,gpt2)/boot/grub
insmod normal
normal                                        # load GRUB menu
```

**Reinstall GRUB from live USB:**

```bash
# Mount partitions
mount /dev/sdXn /mnt
mount /dev/sdXn /mnt/boot/efi                # UEFI
sudo arch-chroot /mnt

# UEFI:
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# BIOS/MBR:
grub-install --target=i386-pc /dev/sdX
grub-mkconfig -o /boot/grub/grub.cfg
exit && reboot
```

### Kernel Panic

**Symptoms:** `Kernel panic`, `VFS: Unable to mount root fs`.

**Fix:**

```bash
# Boot older kernel from GRUB advanced options
# Then rebuild initramfs:
sudo mkinitcpio -P

# Check /etc/mkinitcpio.conf
# HOOKS should include: base udev autodetect modconf block filesystems keyboard fsck
# MODULES: add 'btrfs' for Btrfs root, 'nvidia' for NVIDIA

# If kernel broken, fall back to LTS:
sudo pacman -S linux-lts
grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
```

---

## 6. Dependency Conflicts

### File Conflicts

```bash
# "/usr/lib/file exists in filesystem"
pacman -Qo /usr/lib/conflicting-file         # find owner

# If owned by another package — upgrade everything
sudo pacman -Syu

# If owned by no package (manual install)
sudo pacman -S <pkg> --overwrite '/usr/lib/conflicting-file'
```

### Version Conflicts

```bash
# "requires libfoo>=2.0 but installed is 1.9"
sudo pacman -Syu                             # upgrade everything

# Circular dependency:
sudo pacman -Rdd <pkg-with-old-dep>          # force remove
sudo pacman -Syu                             # upgrade
sudo pacman -S <removed-pkg>                 # reinstall
```

---

## 7. Keyring / Signature Errors

**Symptoms:** `invalid or corrupted package`, `GPGME error`, signature failures.

```bash
sudo pacman -Sy archlinux-keyring
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman-key --refresh-keys
sudo pacman -Syu
```

**If that fails:**

```bash
sudo rm -r /etc/pacman.d/gnupg/
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syu
```

---

## 8. No Sound After Update

**Symptoms:** No audio output, PipeWire/PulseAudio crash.

```bash
# Check audio system
pactl info
systemctl --user status pipewire

# Restart PipeWire stack
systemctl --user restart pipewire pipewire-pulse wireplumber

# Check ALSA
aplay -l                                     # list sound cards
alsamixer                                    # check mute/volume

# If PipeWire replaced PulseAudio during update:
sudo pacman -S pipewire pipewire-pulse wireplumber
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

---

## 9. Network Not Working

```bash
# Check NetworkManager
systemctl status NetworkManager
sudo systemctl enable --now NetworkManager

# Check interfaces
ip link show
nmcli device status

# Wi-Fi driver missing after kernel update
lspci -k | grep -A 3 Network
dmesg | grep -i wifi
dmesg | grep -i firmware

# Reinstall firmware
sudo pacman -S linux-firmware
# Broadcom:
sudo pacman -S broadcom-wl-dkms

# DNS issues
resolvectl status
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf  # temporary
```

---

## 10. Broken Permissions

**Symptoms:** Programs fail, `permission denied` on system binaries.

**Cause:** Accidental `chown -R` or `chmod -R` on system directories.

```bash
# Reinstall all packages to restore permissions
sudo pacman -S $(pacman -Qqn)

# Fix specific critical files
sudo chown root:root /usr/bin/sudo
sudo chmod 4755 /usr/bin/sudo

# From live USB if sudo is broken
sudo arch-chroot /mnt
pacman -S $(pacman -Qqn)
exit
```

---

## 11. Disk Space Full

**Symptoms:** `No space left on device`, install fails.

```bash
# Diagnose
df -h
du -sh /* 2>/dev/null | sort -rh | head -20
ncdu /                                       # interactive

# Common hogs
du -sh /var/cache/pacman/pkg/                # pacman cache
du -sh /var/log/journal/                     # journal
du -sh ~/.cache/                             # user cache

# Clean up
sudo paccache -rk 1                          # keep only latest version
sudo journalctl --vacuum-size=100M
sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null # remove orphans
rm -rf ~/.cache/yay/                         # AUR build cache

# Find large files
find / -type f -size +100M 2>/dev/null | head -20
```

---

## 12. Time/Clock Issues

**Symptoms:** Wrong time, dual-boot with Windows shows wrong time.

```bash
timedatectl status

# Enable NTP
sudo timedatectl set-ntp true

# Set timezone
sudo timedatectl set-timezone Europe/Paris
timedatectl list-timezones | grep Europe

# Dual-boot with Windows
# Option A (easiest): tell Linux to use localtime
sudo timedatectl set-local-rtc 1
# Option B (better): tell Windows to use UTC
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation
# Add DWORD: RealTimeIsUniversal = 1
```

---

## 13. Pacman Hook Failures

**Symptoms:** Update completes but hook scripts fail with errors like `hook 'xxx' failed`,
`/usr/share/libalpm/hooks/yyy` exit code non-zero.

**Diagnosis:**

```bash
# See the exact hook error
sudo pacman -Syu 2>&1 | grep -i hook

# Find hook files
ls /usr/share/libalpm/hooks/
ls /etc/pacman.d/hooks/
```

**Causes and fixes:**

| Cause | Fix |
|-------|-----|
| Hook script outdated after update | `sudo pacman -Syu` (reinstall hook package) |
| Hook dependency missing | `sudo pacman -S $(pacman -Qoq /usr/share/libalpm/hooks/)` |
| Custom hook has errors | Check `/etc/pacman.d/hooks/` for mistakes |
| DKMS hook fails for specific module | `sudo dkms remove <module>/<version> --all && sudo dkms autoinstall` |
| mkinitcpio hook fails | `sudo mkinitcpio -P` manually to see the full error |

**Skip problematic hooks temporarily (not recommended, use with caution):**

```bash
# Edit hook to add 'NeededByOS' or comment it out
sudo vim /etc/pacman.d/hooks/xxx.hook

# Or use --overwrite to bypass
sudo pacman -Syu --overwrite '*'
```

---

## 14. Bluetooth Not Working

**Symptoms:** Bluetooth adapter not detected, devices won't pair, audio stutters.

**Diagnosis:**

```bash
# Check service
systemctl status bluetooth
sudo systemctl enable --now bluetooth

# Check adapter
hciconfig                                   # legacy (bluez-utils)
bluetoothctl show                           # modern
rfkill list                                 # check if soft/hard blocked

# Pair device
bluetoothctl
#   power on
#   agent on
#   default-agent
#   scan on
#   pair <MAC>
#   trust <MAC>
#   connect <MAC>

# Check kernel module
lsmod | grep -i bt
lsmod | grep -i blue
```

**Fix:**

```bash
# Install full BlueZ stack
sudo pacman -S bluez bluez-utils bluez-plugins

# For audio (A2DP):
sudo pacman -S pulseaudio-bluetooth        # PulseAudio
# or:
sudo pacman -S pipewire-alsa pipewire-pulse  # PipeWire (auto-includes BT support)

# For Intel wireless cards missing firmware:
sudo pacman -S linux-firmware

# Unblock radio
rfkill unblock bluetooth
sudo rfkill unblock bluetooth

# Specific kernel modules for some adapters:
# Broadcom:  sudo pacman -S broadcom-wl-dkms
# Realtek:   sudo pacman -S rtl8723bs-firmware  (AUR)
```

---

## 15. Printer Not Working (CUPS)

**Symptoms:** Printer not detected, print jobs stuck, driver not found.

**Diagnosis:**

```bash
systemctl status cups
sudo systemctl enable --now cups

# List printers
lpinfo -v                                  # available backends/drivers
lpinfo -m                                  # available models/drivers
lpstat -t                                  # printer status
lpstat -p                                  # printer list

# Check cups config
cat /etc/cups/printers.conf                # configured printers
```

**Fix:**

```bash
# Install CUPS
sudo pacman -S cups cups-pdf               # cups-pdf for "print to PDF"

# For common printer drivers:
sudo pacman -S gutenprint                   # Canon, Epson, HP
sudo pacman -S hplip                        # HP printers
sudo pacman -S foomatic-db                  # generic drivers
yay -S samsung-unified-driver               # Samsung printers (AUR)
yay -S brlaser                              # Brother printers (AUR)

# Add user to lp group
sudo usermod -a -G lp $USER

# Web interface
# Open http://localhost:631/ in browser
```

---

## 16. USB Devices Not Recognized

**Symptoms:** USB device plugged in but not detected, `lsusb` shows nothing,
intermittent disconnects.

**Diagnosis:**

```bash
# List USB buses and devices
lsusb
lsusb -t                                    # tree view

# Watch kernel messages when plugging
sudo dmesg -wH                              # watch mode
journalctl -k -f                            # follow kernel messages

# Check power delivery
sudo lsusb -v 2>/dev/null | grep -E "MaxPower|bMaxPower"

# Check for xhci (USB 3.0) issues
sudo dmesg | grep -i xhci
```

**Fixes:**

```bash
# Power saving causing disconnect — disable USB autosuspend
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend

# Or via udev rule:
# /etc/udev/rules.d/50-usb-power.rules
# ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"

# Reset USB subsystem
sudo modprobe -r usbcore && sudo modprobe usbcore

# Install firmware (for specific devices)
sudo pacman -S linux-firmware

# Reinstall USB drivers
sudo mkinitcpio -P && sudo reboot
```

---

## 17. Docker / Virtualization Issues

**Symptoms:** Docker won't start, VirtualBox VMs fail, KVM not available.

### Docker

```bash
# Install
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER               # log out and back in

# Check
systemctl status docker
docker info
docker run hello-world

# Common issues:
# "Cannot connect to the Docker daemon":
sudo systemctl start docker

# "Failed to start docker.service: Unit docker.socket not found":
sudo systemctl enable --now docker.socket

# Rootless Docker (without sudo):
yay -S docker-rootless
systemctl --user enable --now docker
```

### KVM/QEMU (native Linux virtualization)

```bash
# Install
sudo pacman -S virt-manager qemu-desktop libvirt dnsmasq edk2-ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER              # log out and back in

# Check
virsh list --all
virt-manager                                 # GUI

# Common issues:
# "Permission denied": user not in libvirt group
groups $USER

# "No network": default network not started
sudo virsh net-start default
sudo virsh net-autostart default

# KVM not available:
lscpu | grep -i virtualization              # check CPU supports VT-x/AMD-V
lsmod | grep kvm                              # check kvm module loaded
```

### VirtualBox

```bash
sudo pacman -S virtualbox virtualbox-host-dkms
sudo modprobe vboxdrv
sudo usermod -aG vboxusers $USER

# After kernel update — rebuild modules
sudo dkms autoinstall
```

---

## 18. Wayland Screen Sharing Not Working

**Symptoms:** Screensharing in Zoom/Discord/Chrome shows black screen,
`xdg-desktop-portal` errors.

**Diagnosis:**

```bash
# Check which portal is running
systemctl --user status xdg-desktop-portal-*
systemctl --user status xdg-desktop-portal-wlr   # for wlroots compositors (Sway, Hyprland)
systemctl --user status xdg-desktop-portal-gnome # for GNOME
systemctl --user status xdg-desktop-portal-kde   # for KDE

# Check environment
echo $XDG_CURRENT_DESKTOP
echo $WAYLAND_DISPLAY

# Portal logs
journalctl --user -u xdg-desktop-portal* -b
```

**Fixes:**

```bash
# Install the correct portal backend for your DE/WM
# GNOME:
sudo pacman -S xdg-desktop-portal-gnome

# KDE:
sudo pacman -S xdg-desktop-portal-kde

# wlroots (Sway, Hyprland, river):
sudo pacman -S xdg-desktop-portal-wlr xdg-desktop-portal

# For browsers (Chrome/Chromium):
# Ensure xdg-desktop-portal is running
systemctl --user enable --now xdg-desktop-portal

# For OBS Studio:
sudo pacman -S obs-studio
# Use PipeWire capture source, not X11

# Environment fix (add to ~/.config/environment.d/*.conf):
# XDG_CURRENT_DESKTOP=sway   (match your compositor)
```

---

## 19. Suspend / Hibernate Issues

**Symptoms:** System won't suspend, wakes immediately, fails to resume from hibernation.

**Diagnosis:**

```bash
# Check sleep state support
cat /sys/power/state                          # freeze, mem, disk
cat /sys/power/mem_sleep                     # s2idle, shallow, deep

# What wakeups are configured
cat /proc/acpi/wakeup

# Recent suspend/resume logs
journalctl -b | grep -E "PM:|suspend|resume|hibernate"
```

**Fixes:**

```bash
# Immediate wakeup — disable USB wake
echo "USB0" | sudo tee /proc/acpi/wakeup     # toggle (run twice to disable)

# Make permanent via udev rule:
# /etc/udev/rules.d/70-disable-usb-wake.rules
# ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"

# Force deep sleep instead of s2idle
sudo kernelstub -a "mem_sleep_default=deep"  # systemd-boot
# or edit GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub,
# then grub-mkconfig -o /boot/grub/grub.cfg

# Hibernation setup:
# 1. Ensure swap is larger than RAM
swapon --show

# 2. Add kernel parameter: resume=UUID=<swap-partition-uuid>
# 3. Add 'resume' hook to /etc/mkinitcpio.conf before 'filesystems'
# 4. sudo mkinitcpio -P

# Nvidia specific: black screen after resume
# Add to /etc/systemd/system-sleep/nvidia.sh:
#   cat > /proc/driver/nvidia/suspend
# Also ensure nvidia kernel modules are in initramfs

# Disable suspend entirely (as last resort)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

---

## 20. SSD TRIM Not Enabled

**Symptoms:** SSD performance degrades over time, `fstrim` never runs automatically.

**Diagnosis:**

```bash
# Check if TRIM is supported
lsblk -D /dev/sdX                             # DISC-GRAN/DISC-MAX = non-zero means supported

# Check if timer is enabled
systemctl status fstrim.timer
systemctl list-timers fstrim.timer

# Manual TRIM
sudo fstrim -av                               # trim all mounted SSDs
```

**Fixes:**

```bash
# Enable weekly automatic TRIM
sudo systemctl enable --now fstrim.timer

# For LUKS encrypted SSDs — allow TRIM to pass through:
# Add 'allow_discards' to /etc/crypttab:
#   sudo crypttab --update <name> --allow-discards

# For LVM — issue_discards = 1" in /etc/lvm/lvm.conf

# Check TRIM is actually working
sudo fstrim -v /
# If it completes without error, TRIM is functional

# Periodic check
sudo journalctl -u fstrim -b
```

---

## 21. LUKS Encryption Issues

**Symptoms:** Can't unlock encrypted volume at boot, "No key available with this passphrase",
LUKS header corruption.

**Diagnosis:**

```bash
# Check crypttab
cat /etc/crypttab

# List active mappings
sudo dmsetup ls --tree

# Check LUKS header info
sudo cryptsetup luksDump /dev/sdX

# Check available key slots
sudo cryptsetup luksDump /dev/sdX | grep -E "Key Slot|Enabled"
```

**Fixes:**

```bash
# Wrong passphrase — try recovery key if available
# Recovery key was shown during LUKS creation

# Add additional passphrase (e.g., backup key)
sudo cryptsetup luksAddKey /dev/sdX

# Remove compromised passphrase
sudo cryptsetup luksRemoveKey /dev/sdX

# Backup LUKS header (CRITICAL — do this before any problems)
sudo cryptsetup luksHeaderBackup /dev/sdX --header-backup-file /root/luks-header.bak

# Restore LUKS header
sudo cryptsetup luksHeaderRestore /dev/sdX --header-backup-file /root/luks-header.bak

# LUKS header corruption — if header is lost, data is unrecoverable
# If header backup exists, restore it (see above)

# Add keyfile for automatic unlocking (e.g., with remote unlocking)
sudo dd if=/dev/urandom of=/etc/luks-key bs=512 count=8
sudo cryptsetup luksAddKey /dev/sdX /etc/luks-key
# Then reference in /etc/crypttab:
# <name> /dev/sdX /etc/luks-key luks

# Convert LUKS1 to LUKS2 (for Argon2 support)
sudo cryptsetup convert /dev/sdX --type luks2

# Resize encrypted volume
sudo cryptsetup resize <name>
sudo resize2fs /dev/mapper/<name>
```

---

## 22. Laptop Backlight Not Adjustable

**Symptoms:** Brightness keys don't work, `/sys/class/backlight/` empty, brightness
stuck at 100%.

**Diagnosis:**

```bash
# Check available backlight interfaces
ls /sys/class/backlight/

# Check if acpi_video0 exists
ls /sys/class/backlight/acpi_video0/

# Check current brightness
cat /sys/class/backlight/*/brightness
cat /sys/class/backlight/*/max_brightness

# Test manual adjustment
echo 500 | sudo tee /sys/class/backlight/*/brightness
```

**Fixes:**

```bash
# Kernel parameters to try (add to GRUB_CMDLINE_LINUX or systemd-boot options):
# acpi_backlight=vendor    (use vendor specific driver)
# acpi_backlight=native    (use native GPU driver)
# acpi_backlight=video     (use generic ACPI video)
# acpi_osi=Linux           (enable Linux-specific ACPI)

# Example GRUB:
# GRUB_CMDLINE_LINUX_DEFAULT="quiet acpi_backlight=native"
# Then: sudo grub-mkconfig -o /boot/grub/grub.cfg && reboot

# For NVIDIA Optimus laptops:
# Ensure nvidia kernel modules are loaded
# May need: sudo pacman -S nvidia-prime

# Install brightness control tools
sudo pacman -S brightnessctl                 # CLI tool
brightnessctl set 50%                        # set to 50%
brightnessctl -l                             # list devices

# Or install light (AUR)
yay -S light
light -S 50                                  # set to 50%
light -A 10                                  # increase by 10%
light -U 10                                  # decrease by 10%

# For KDE/GNOME — ensure power profiles daemon is running
systemctl status power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
```

```bash
# System info
uname -a                                     # kernel version
cat /etc/os-release                          # distro info
hostnamectl                                  # hostname + OS
lscpu                                        # CPU
free -h                                      # memory
uptime                                       # uptime + load

# Hardware
lspci                                        # PCI devices
lsusb                                        # USB devices
lsblk -f                                     # block devices + filesystems
dmesg | tail -50                             # recent kernel messages

# Services
systemctl --failed                           # failed services
systemctl list-units --state=running         # running services

# Logs
journalctl -p err -b                         # errors since boot
journalctl -xe                               # last entries with explanation
```
