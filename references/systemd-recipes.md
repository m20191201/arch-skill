# systemd Recipes

Unit file templates, timer syntax, journal management, boot analysis, and hardening.

## Table of Contents

1. [Service Types](#service-types)
2. [Unit File Templates](#unit-file-templates)
3. [User Services](#user-services)
4. [Timer Units](#timer-units)
5. [Journal Management](#journal-management)
6. [Boot Analysis](#boot-analysis)
7. [Service Hardening](#service-hardening)
8. [Drop-In Overrides](#drop-in-overrides)
9. [Dependency and Ordering](#dependency-and-ordering)
10. [Other Unit Types](#other-unit-types)
11. [systemd-networkd](#systemd-networkd)
12. [systemd-resolved](#systemd-resolved)
13. [systemd-boot](#systemd-boot)
14. [systemd-nspawn](#systemd-nspawn)
15. [systemd-tmpfiles](#systemd-tmpfiles)
16. [systemd-oomd](#systemd-oomd)
17. [systemd-sysusers](#systemd-sysusers)
18. [systemd-homed](#systemd-homed)
19. [systemd-repart](#systemd-repart)
20. [systemd-sysext](#systemd-sysext)
21. [systemd-portabled](#systemd-portabled)

---

## Service Types

| Type       | Behavior                                                         |
|------------|------------------------------------------------------------------|
| `simple`   | Default. ExecStart process IS the main process.                  |
| `exec`     | Like simple, but waits for binary to execute (not just fork).    |
| `forking`  | Process forks and parent exits. Use PIDFile to track.            |
| `oneshot`  | Runs to completion. Good for scripts.                            |
| `notify`   | Process sends sd_notify() when ready. Best for aware daemons.    |
| `dbus`     | Ready when BusName appears on D-Bus.                             |
| `idle`     | Like simple, delayed until all jobs are done.                    |

---

## Unit File Templates

### Basic Daemon (simple)

```ini
# /etc/systemd/system/my-daemon.service
[Unit]
Description=My Custom Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/my-daemon --config /etc/my-daemon.conf
Restart=on-failure
RestartSec=5
User=myuser
Group=mygroup

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/my-daemon

[Install]
WantedBy=multi-user.target
```

### One-Shot (run once)

```ini
# /etc/systemd/system/my-task.service
[Unit]
Description=Run a one-time task
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/my-script.sh
RemainAfterExit=no
User=root

[Install]
WantedBy=multi-user.target
```

### Forking Daemon (legacy)

```ini
# /etc/systemd/system/legacy-daemon.service
[Unit]
Description=Legacy Forking Daemon
After=network.target

[Service]
Type=forking
PIDFile=/var/run/legacy-daemon.pid
ExecStart=/usr/sbin/legacy-daemon -d
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Web Application (Node.js / Go / Python)

```ini
# /etc/systemd/system/webapp.service
[Unit]
Description=My Web Application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=webapp
Group=webapp
WorkingDirectory=/opt/webapp
ExecStart=/opt/webapp/server --port 8080
Restart=always
RestartSec=5

Environment=NODE_ENV=production
EnvironmentFile=-/opt/webapp/.env

LimitNOFILE=65536

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/webapp/data /var/log/webapp
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=webapp

[Install]
WantedBy=multi-user.target
```

### Docker Container as Service

```ini
# /etc/systemd/system/my-container.service
[Unit]
Description=My Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop my-container
ExecStartPre=-/usr/bin/docker rm my-container
ExecStart=/usr/bin/docker run --name my-container \
    -p 8080:8080 \
    -v /opt/data:/data \
    --rm \
    my-image:latest
ExecStop=/usr/bin/docker stop my-container

[Install]
WantedBy=multi-user.target
```

---

## User Services

Place in `~/.config/systemd/user/`. No sudo needed.

### Template

```ini
# ~/.config/systemd/user/my-app.service
[Unit]
Description=My User Application
After=default.target

[Service]
Type=simple
ExecStart=%h/bin/my-app
Restart=on-failure
RestartSec=5
Environment=HOME=%h
Environment=MY_VAR=value

[Install]
WantedBy=default.target
```

### Management

```bash
systemctl --user daemon-reload               # reload after editing
systemctl --user enable --now my-app.service # enable + start
systemctl --user start/stop/restart my-app   # control
systemctl --user status my-app               # status
journalctl --user -u my-app -f              # follow logs
```

### Linger (keep running after logout)

```bash
sudo loginctl enable-linger $USER            # enable
sudo loginctl disable-linger $USER           # disable
loginctl show-user $USER | grep Linger       # check
```

---

## Timer Units

Each timer needs a matching `.service` unit with the same name.

### Periodic Timer

```ini
# ~/.config/systemd/user/backup.timer
[Unit]
Description=Run backup every 6 hours

[Timer]
OnCalendar=*-*-* 00/6:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

```ini
# ~/.config/systemd/user/backup.service
[Unit]
Description=Backup task

[Service]
Type=oneshot
ExecStart=%h/scripts/backup.sh
```

### OnCalendar Syntax

```
*-*-* 00:00:00           # daily at midnight
Mon *-*-* 09:00:00       # every Monday at 9am
*-*-01 00:00:00          # first day of every month
*-*-* *:00/15:00         # every 15 minutes
hourly                   # shorthand
daily                    # shorthand
weekly                   # shorthand (Mon 00:00)
monthly                  # shorthand (1st 00:00)
```

```bash
# Test expressions
systemd-analyze calendar "Mon *-*-* 09:00:00"
systemd-analyze calendar --iterations=5 "hourly"
```

### Monotonic Timer (relative to boot)

```ini
[Timer]
OnBootSec=15min
OnUnitActiveSec=1h
Persistent=true
```

### Timer Fields

| Field                  | Description                                    |
|------------------------|------------------------------------------------|
| `OnCalendar=`          | Wallclock schedule                             |
| `OnBootSec=`           | Time after boot                                |
| `OnStartupSec=`        | Time after systemd started                     |
| `OnUnitActiveSec=`     | Time after service last activated              |
| `OnUnitInactiveSec=`   | Time after service last deactivated            |
| `Persistent=true`      | Catch up missed runs                           |
| `RandomizedDelaySec=`  | Random delay (avoid thundering herd)           |
| `AccuracySec=`         | Timer accuracy (default 1min)                  |

### Managing Timers

```bash
systemctl list-timers --all                  # all timers with next/last
systemctl --user list-timers                 # user timers
systemctl enable --now backup.timer          # enable + start
systemctl start backup.service               # trigger manually
```

---

## Journal Management

### Viewing Logs

```bash
# By unit
journalctl -u <unit>                        # all logs
journalctl -u <unit> -f                     # follow (tail)
journalctl -u <unit> -n 50                  # last 50 lines
journalctl -u <unit> --since "1 hour ago"   # time-filtered

# By priority
journalctl -p err                            # errors and above
journalctl -p warning                        # warnings and above

# By boot
journalctl -b                                # current boot
journalctl -b -1                             # previous boot
journalctl --list-boots                      # all boots

# Kernel messages
journalctl -k                                # like dmesg
journalctl -k -b -1                          # kernel msgs from last boot

# By process
journalctl _PID=1234
journalctl _EXE=/usr/bin/nginx
journalctl _UID=1000

# Output formats
journalctl -o json-pretty                    # JSON
journalctl -o short-iso                      # ISO timestamps
journalctl -o cat                            # message only
```

### Disk Management

```bash
journalctl --disk-usage                      # current size
sudo journalctl --vacuum-size=500M           # shrink to 500MB
sudo journalctl --vacuum-time=2weeks         # remove older than 2 weeks
sudo journalctl --rotate                     # force rotation
```

### Persistent Config (`/etc/systemd/journald.conf`)

```ini
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=1month
Compress=yes
Storage=persistent
```

After editing: `sudo systemctl restart systemd-journald`

---

## Boot Analysis

```bash
systemd-analyze                              # total boot time
systemd-analyze blame                        # time per unit (slowest first)
systemd-analyze critical-chain               # critical path
systemd-analyze critical-chain sshd.service  # what delayed specific service
systemd-analyze plot > boot.svg              # visual boot chart
systemd-analyze verify my.service            # validate unit file
systemd-analyze security my.service          # security audit
```

---

## Service Hardening

Apply in the `[Service]` section:

```ini
# Filesystem
ProtectSystem=strict                # / as read-only
ProtectHome=true                    # hide /home
ReadWritePaths=/var/lib/myapp       # whitelist writable
PrivateTmp=true                     # isolated /tmp

# Privileges
NoNewPrivileges=true                # prevent escalation
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Network
PrivateNetwork=true                 # no network
RestrictAddressFamilies=AF_INET AF_INET6

# System calls
SystemCallFilter=@system-service
SystemCallArchitectures=native

# Other
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
MemoryDenyWriteExecute=true
LockPersonality=true
```

Audit: `systemd-analyze security my.service` (score 0=best, 10=worst).

---

## Drop-In Overrides

Override parts of a unit without editing the original:

```bash
sudo systemctl edit my.service               # creates drop-in
# Creates: /etc/systemd/system/my.service.d/override.conf
```

```ini
[Service]
Environment=MY_VAR=new-value
RestartSec=10
```

To replace a field, clear it first:

```ini
[Service]
ExecStart=                                   # clear original
ExecStart=/new/path/to/binary                # set new
```

---

## Dependency and Ordering

```ini
[Unit]
# Ordering
After=network-online.target          # start after
Before=httpd.service                 # start before

# Dependencies
Requires=postgresql.service          # hard dep (fail if postgres fails)
Wants=redis.service                  # soft dep (don't fail)
BindsTo=docker.service               # stop if docker stops
PartOf=app.target                    # stop/restart with target

# Conflict
Conflicts=other.service              # cannot coexist
```

---

## Other Unit Types

### Mount Unit

```ini
# /etc/systemd/system/mnt-data.mount
# Name must match path: mnt-data = /mnt/data
[Unit]
Description=Mount Data Drive

[Mount]
What=/dev/disk/by-uuid/xxxx
Where=/mnt/data
Type=ext4
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
```

### Path Unit (file watcher)

```ini
# /etc/systemd/system/deploy-watch.path
[Unit]
Description=Watch for deploy trigger

[Path]
PathChanged=/opt/deploy/trigger
MakeDirectory=yes

[Install]
WantedBy=multi-user.target
```

### Socket Activation

```ini
# /etc/systemd/system/my-app.socket
[Unit]
Description=My App Socket

[Socket]
ListenStream=8080
Accept=no

[Install]
WantedBy=sockets.target
```

Service starts only when a connection arrives on port 8080 — zero resources when idle.

### Custom Target (group services)

```ini
# /etc/systemd/system/my-stack.target
[Unit]
Description=My Application Stack
Requires=webapp.service worker.service
After=webapp.service worker.service

[Install]
WantedBy=multi-user.target
```

---

## systemd-networkd

Lightweight network manager — no NetworkManager required.

### Configuration locations

- `/etc/systemd/network/*.network`  — link configuration (DHCP/static)
- `/etc/systemd/network/*.netdev`   — virtual device definitions (bridge, bond, veth)
- `/etc/systemd/network/*.link`     — low-level link settings (MAC, driver)

### DHCP (wired)

```ini
# /etc/systemd/network/20-wired.network
[Match]
Name=enp* eth*

[Network]
DHCP=yes
DNSSEC=no

[DHCP]
RouteMetric=10
UseDNS=true
UseTimezone=true
```

### Static IP

```ini
# /etc/systemd/network/20-static.network
[Match]
Name=enp0s3

[Network]
Address=192.168.1.100/24
Gateway=192.168.1.1
DNS=1.1.1.1
DNS=8.8.8.8
```

### Wi-Fi (with iwd backend)

```ini
# /etc/systemd/network/25-wireless.network
[Match]
Name=wlan*

[Network]
DHCP=yes
```

Wireless authentication handled by iwd separately.

### Bridge (for VMs/containers)

```ini
# /etc/systemd/network/br0.netdev
[NetDev]
Name=br0
Kind=bridge

# /etc/systemd/network/br0.network
[Match]
Name=br0

[Network]
Address=10.0.0.1/24
DHCPServer=yes
IPForward=yes

[DHCPServer]
PoolSize=100

# /etc/systemd/network/eth0.network — attach interface to bridge
[Match]
Name=enp0s3

[Network]
Bridge=br0
```

### Bonding (link aggregation)

```ini
# /etc/systemd/network/30-bond.netdev
[NetDev]
Name=bond0
Kind=bond

[Bond]
Mode=802.3ad
MIIMonitorSec=1s
LACPTransmitRate=fast

# /etc/systemd/network/30-bond.network
[Match]
Name=bond0

[Network]
DHCP=ipv4

# /etc/systemd/network/30-eth0.network — attach slave
[Match]
Name=enp*

[Network]
Bond=bond0
```

### Management

```bash
sudo systemctl enable --now systemd-networkd
networkctl status                              # overall status
networkctl list                                # all links
networkctl lldp                                # LLDP neighbors
sudo networkctl reload                         # reload config files
sudo journalctl -u systemd-networkd -f         # follow logs
```

---

## systemd-resolved

DNS stub resolver — replaces `/etc/resolv.conf` management.

### Enable

```bash
sudo systemctl enable --now systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

### Configuration (`/etc/systemd/resolved.conf`)

```ini
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9
Domains=~.
DNSSEC=allow-downgrade
DNSOverTLS=yes
MulticastDNS=no
LLMNR=no
Cache=yes
```

### Per-link DNS (via networkd or resolvectl)

```bash
# Set DNS for specific interface
resolvectl dns enp0s3 1.1.1.1 8.8.8.8
resolvectl domain enp0s3 "~."
resolvectl default-route enp0s3 true

# Show status
resolvectl status
resolvectl query example.com

# Flush cache
sudo resolvectl flush-caches
```

### mDNS (local .local resolution)

```ini
# /etc/systemd/resolved.conf
[Resolve]
MulticastDNS=yes
```

```bash
resolvectl mdns enp0s3 yes                     # per-interface
```

---

## systemd-boot

UEFI boot manager — simpler and faster than GRUB for UEFI systems.

### Installation

```bash
# Install (assumes ESP mounted at /boot or /efi)
sudo bootctl install

# Verify
bootctl status
```

### Configuration (`/boot/loader/loader.conf`)

```ini
default  arch.conf
timeout  4
console-mode max
editor   no
auto-entries    1      # detect Windows, macOS
auto-firmware    1     # add firmware setup entry
```

### Entry file (`/boot/loader/entries/arch.conf`)

```ini
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img      # Intel microcode (before initramfs)
initrd  /initramfs-linux.img
options root=PARTUUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx rw quiet loglevel=3
```

### Entry with LTS kernel fallback

```ini
# /boot/loader/entries/arch-lts.conf
title   Arch Linux (LTS)
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options root=PARTUUID=xxxx rw quiet
```

### Kernel parameters

```bash
# View current kernel cmdline
cat /proc/cmdline

# Add parameters temporarily at boot:
# At systemd-boot menu, press 'e' on the entry, edit the options line
```

### Automatic kernel updates

```bash
# Install this to auto-copy new kernels to /boot
sudo pacman -S systemd-boot-update

# Or manually update after kernel install:
sudo bootctl update
```

### Managing boot entries (efibootmgr)

```bash
# List entries
efibootmgr -v

# Change boot order
sudo efibootmgr -o 0001,0002,0003

# Create entry
sudo efibootmgr --create --disk /dev/sda --part 1 \
    --label "Arch Linux" \
    --loader /vmlinuz-linux

# Remove entry (be careful!)
sudo efibootmgr -b 0003 -B
```

---

## systemd-nspawn

Lightweight container manager — like Docker but uses systemd concepts.

### Create a container

```bash
# Bootstrap a minimal Arch Linux container
sudo pacman -S arch-install-scripts
sudo mkdir /var/lib/machines/mycontainer
sudo pacstrap -c /var/lib/machines/mycontainer base linux linux-firmware
```

### Run a container

```bash
# Start container
sudo systemd-nspawn -b -M mycontainer

# Or as a systemd service
sudo systemctl enable --now systemd-nspawn@mycontainer.service

# Login to running container
sudo machinectl login mycontainer

# Run command inside container
sudo systemd-nspawn -M mycontainer -- /bin/bash -c "pacman -Syu"
```

### Management

```bash
# List containers
machinectl list-images
machinectl list

# Poweroff/reboot
machinectl poweroff mycontainer
machinectl reboot mycontainer

# Copy files
machinectl copy-to mycontainer /host/file /container/path
machinectl copy-from mycontainer /container/file /host/path
```

### Container config (`/etc/systemd/nspawn/mycontainer.nspawn`)

```ini
[Exec]
Boot=yes
PrivateUsers=no

[Network]
Bridge=br0
Zone=trusted

[Files]
Bind=/opt/data:/data:rbind
```

---

## systemd-tmpfiles

Manage temporary files and directories declaratively.

### Configuration (`/etc/tmpfiles.d/*.conf`)

```ini
# /etc/tmpfiles.d/myapp.conf
# Type Path             Mode User Group Age   Argument
d      /run/myapp       0755 myapp mygroup 30d  -
f      /run/myapp/lock  0640 myapp mygroup -    -
D      /var/cache/myapp 0700 myapp mygroup 7d   -
z      /etc/myapp.conf  0640 root root     -    -
```

### Type reference

| Type | Behavior |
|------|----------|
| `d`  | Create directory if missing |
| `D`  | Create + clean old files (Age) |
| `f`  | Create file |
| `F`  | Create/truncate file |
| `L`  | Create symlink |
| `Lb` | Create symlink with relative target |
| `c`  | Create character device node |
| `b`  | Create block device node |
| `z`  | Set permissions (no create) |
| `Z`  | Recursive permissions (no create) |
| `t`  | Set extended attribute |
| `T`  | Recursive extended attribute |
| `x`  | Remove entry from path |
| `r`  | Recursively remove path |
| `R`  | Recursively remove path (even non-empty) |
| `a`  | Add ACL entry |
| `A`  | Recursive ACL entry |

### Apply

```bash
# Preview (dry run)
sudo systemd-tmpfiles --create --remove --prefix=/run/myapp --dry-run

# Apply
sudo systemd-tmpfiles --create
sudo systemd-tmpfiles --clean                     # apply aging rules
sudo systemd-tmpfiles --remove                    # remove marked entries
```

---

## systemd-oomd

Userspace OOM (Out-Of-Memory) manager — kills memory-hogging processes before kernel OOM.

### Enable

```bash
sudo systemctl enable --now systemd-oomd
```

### Configuration

```ini
# /etc/systemd/oomd.conf
[OOM]
DefaultMemoryPressureLimit=50%
DefaultMemoryPressureDurationSec=10
SwapUsedLimitPercent=90%
```

### Per-service overrides

```ini
# /etc/systemd/system/myapp.service.d/oomd.conf
[Service]
ManagedOOMSwap=kill                       # kill if swap usage > limit
ManagedOOMMemoryPressure=kill             # kill if memory pressure > limit
ManagedOOMMemoryPressureLimit=60%         # per-service threshold
```

### Monitoring

```bash
# View OOM events
journalctl -u systemd-oomd -f

# Check which services have ManagedOOM set
systemctl show <service> | grep ManagedOOM
```

---

## systemd-sysusers

Declarative system user/group creation — no `useradd` needed.

### Configuration (`/etc/sysusers.d/*.conf`)

```
# Type Name        ID   GECOS                  Home       Shell
u     myapp       900  "My Application User"   /opt/myapp -
g     myappgroup  -    -                       -          -
m     myuser      -    myappgroup              -          -
```

### Type reference

| Type | Syntax | Behavior |
|------|--------|----------|
| `u`  | `u name id desc home shell` | Create user |
| `g`  | `g name id desc` | Create group |
| `m`  | `m name group` | Add user to group |
| `r`  | `r min max` | Set UID/GID range for sysusers |

### Apply

```bash
sudo systemd-sysusers                              # read all configs and apply
sudo systemd-sysusers /etc/sysusers.d/myapp.conf   # apply specific file
```

---

## systemd-homed

Portable home directories — store home dirs as encrypted image files.

### Create home area

```bash
sudo homectl create myuser \
    --disk-size=10G \
    --filesystem=ext4 \
    --storage=luks \
    --password-change-at=90d
```

### Management

```bash
# List home areas
homectl list

# Inspect
homectl inspect myuser

# Resize
homectl resize myuser 20G

# Change password
homectl passwd myuser

# Lock/unlock
homectl lock myuser
homectl unlock myuser

# Remove
homectl remove myuser
```

### Auto-login with homed

```bash
# Activate home area at login
sudo loginctl enable-linger myuser
sudo homectl activate myuser
```

---

## systemd-repart

Declarative partition table management — grow partitions, add partitions on first boot.

### Configuration (`/etc/repart.d/*.conf`)

```ini
# /etc/repart.d/10-root.conf
[Partition]
Type=root
Label=root_arch
SizeMinBytes=20G
SizeMaxBytes=100G
ReadOnly=no
```

```ini
# /etc/repart.d/20-home.conf
[Partition]
Type=home
Label=home
SizeMinBytes=10G
SizeMaxBytes=200G
ReadOnly=no
```

### Apply

```bash
# Preview (dry run)
sudo systemd-repart --dry-run=yes

# Apply (grows partitions to fill disk)
sudo systemd-repart

# Only on first boot (for provisioning images)
# Place configs in /usr/lib/repart.d/ for first-boot-only
```

---

## systemd-sysext

Extend /usr and /opt with immutable overlay images — for development tools, SDKs.

### Create a system extension

```bash
# Extension image in /var/lib/extensions/
sudo mkdir -p /var/lib/extensions/mydevel/usr/bin
# Place binaries into /var/lib/extensions/mydevel/usr/bin/
```

### Extension metadata

```ini
# /var/lib/extensions/mydevel/mydevel.extension-release
[Extension]
Name=mydevel
ID=_any
VERSION_ID=rolling
```

### Apply

```bash
systemd-sysext list                              # list installed extensions
sudo systemd-sysext merge                        # activate extensions
sudo systemd-sysext unmerge                      # deactivate
```

---

## systemd-portabled

Manage portable services — services packaged as images that can be attached/detached.

### Create a portable service image

```bash
# Build a disk image with a systemd service
sudo mkdir /tmp/myapp-portable
sudo pacstrap -c /tmp/myapp-portable/root base myapp
sudo systemd-repart --image=/tmp/myapp.raw --empty=create --size=500M
```

### Manage

```bash
# List
portablectl list

# Attach
sudo portablectl attach /tmp/myapp.raw

# Detach
sudo portablectl detach myapp

# Inspect
sudo portablectl inspect /tmp/myapp.raw
```
