# Arch Linux Skill for OpenCode

> Adapted from [Manjaro Skill](https://github.com/AnomalyInnovations/manjaro-skill)

Arch Linux system administration skill for [OpenCode](https://opencode.ai). Provides pacman/AUR-first package management, systemd service management, health checks, troubleshooting, and performance tuning.

## Commands

| Command | Description |
|---|---|
| `/arch check` | System health check (disk, services, updates, kernels) |
| `/arch install <pkg>` | Smart package installer (pacman -> AUR -> isolated language install) |
| `/arch upgrade` | Safe upgrade with pre-flight checks and kernel change warnings |
| `/arch clean` | System cleanup (orphans, cache, journal, .pacnew) |
| `/arch kernel` | Kernel management (list, install LTS, rebuild initramfs) |
| `/arch snapshot` | Btrfs snapshots via Snapper (create, list, rollback) |
| `/arch log <unit>` | Quick systemd unit log viewer |
| `/arch rescue <symptoms>` | Guided troubleshooting for 22 common scenarios |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/m20191201/arch-skill/main/install.sh | bash

# Restart your AI assistant to load the skill
```

## Core Principle

**Pacman First** — always prefer native Arch package management:

1. `pacman -Ss <pkg>` — search official repos
2. `yay -Ss <pkg>` or `paru -Ss <pkg>` — search AUR
3. Language-specific installers only in isolation (venv, node_modules, etc.)

## File Structure

```
arch/
├── SKILL.md                    # Main skill entry point
├── commands/
│   └── arch.md                 # /arch command routing
├── references/
│   ├── packages.md             # pacman/yay/paru command reference
│   ├── systemd-recipes.md      # systemd unit templates and components
│   └── troubleshooting.md      # 22 troubleshooting workflows
├── install.sh                  # Installation script
└── README.md                   # This file
```

## References

- [Arch Wiki](https://wiki.archlinux.org/)
- [pacman manual](https://man.archlinux.org/man/pacman.8)
- [systemd documentation](https://systemd.io/)

## License

MIT
