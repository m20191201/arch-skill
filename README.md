# Arch Linux Skill for OpenCode

> 改编自 [Manjaro Skill](https://github.com/AnomalyInnovations/manjaro-skill)

Arch Linux 系统管理 skill — 为 [OpenCode](https://opencode.ai) 提供 pacman/AUR 优先的包管理、systemd 服务管理、系统健康检查、故障排查和性能调优。

## 功能

| 命令 | 功能 |
|---|---|
| `/arch check` | 系统健康检查（磁盘、服务、更新、内核） |
| `/arch install <pkg>` | 智能包安装（pacman → AUR → 隔离语言安装） |
| `/arch upgrade` | 安全升级（含前置检查、内核变更预警） |
| `/arch clean` | 系统清理（孤儿包、缓存、journal、.pacnew） |
| `/arch kernel` | 内核管理（列表、安装 LTS、重建 initramfs） |
| `/arch snapshot` | Btrfs 快照（Snapper 创建/列表/回滚） |
| `/arch log <unit>` | 快速查看 systemd 单元日志 |
| `/arch rescue <symptoms>` | 引导式故障排查（22 种场景） |

## 安装

```bash
# 远程安装
curl -fsSL https://raw.githubusercontent.com/m20191201/arch-skill/main/install.sh | bash

# 重启 AI 助手以加载 skill
```

## 核心原则

**Pacman 优先** — 在 Arch 上始终优先使用原生包管理工具：

1. `pacman -Ss <pkg>` 查找官方仓库
2. `yay -Ss <pkg>` 或 `paru -Ss <pkg>` 查找 AUR
3. 以上均无时，用语言专用安装器（必须在隔离环境）

## 文件结构

```
arch/
├── SKILL.md                    # 主文档（技能入口）
├── commands/
│   └── arch.md                 # /arch 命令路由
├── references/
│   ├── packages.md             # pacman/yay/paru 命令参考
│   ├── systemd-recipes.md      # systemd unit 模板大全
│   └── troubleshooting.md      # 22 种故障排查流程
├── install.sh                  # 安装脚本
└── README.md                   # 本文件
```

## 参考文档

- [Arch Wiki](https://wiki.archlinux.org/) — 最佳中文/英文文档
- [pacman 手册](https://man.archlinux.org/man/pacman.8)
- [systemd 文档](https://systemd.io/)

## License

MIT
