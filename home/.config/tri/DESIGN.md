# tri — 左主 + 右列手风琴

River ≥0.4 上的 Zig 窗口管理器。配置与二进制在 `~/.config/tri/`。会话 `rv` → `session.sh` → `exec zig-out/bin/tri`。

---

## 布局

- 左主 + 右列手风琴（快捷槽最多 **9** 扇，序号 **1…9**）
- 屏幕始终最多显示左主窗和右列展开窗两扇真实窗口，其余右列窗口显示为 chip

---

## 焦点模型

| 焦点列 | Super+e/d、Super+1…9 | Super+Shift+… |
|--------|----------------------|---------------|
| **左主** | 只改 `expanded` | 移动右列 **展开项**（e/d）或对应槽位 |
| **右列** | 改 `expanded` 且跟焦 | 移动 **当前焦点窗** |

- **Super+s**：左主 ↔ 右列
- 点 chip：展开 + 右列焦点

---

## Monocle

| 键 | 行为 |
|----|------|
| Super+f | Monocle（只改变 WM 布局） |

应用的全屏请求在下一次管理序列中确认，只改变应用界面状态，不改变 WM 分配的尺寸和位置。

---

## 快捷键摘要

| 键 | 动作 |
|----|------|
| Super+1…9 | 展开/导航到对应槽 |
| Super+Shift+1…9 | 移动当前对象到槽位 |
| Super+s / e / d | 焦点列、展开 |
| Super+Shift+s / e / d | 交换主↔展开、栈内移动 |
| Super+r | 交换左右宽度（62:38 ↔ 38:62） |
| Super+Shift+r | 镜像左右列位置 |

完整键位见 `CODE.md`。

---

## 配置（`config`）

```ini
master_ratio = 0.62
output = eDP-1
mode = 2560x1600@60Hz
scale = 1.5

env.QT_IM_MODULE = fcitx
start.input_method = exec fcitx5
bind.Super+a = exec alacritty
bind.Super+s = :focus_toggle
bind.XF86AudioRaiseVolume = wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
```

`env.*` 属于会话环境，`start.*` 是有序自启命令，`bind.*` 左侧是键位。换设备只改此文件；`output = auto` 可交给 River/系统保持当前输出配置。

---

## 构建

```bash
cd ~/.config/tri && ./rebuild.sh
```

构建固定为 baseline x86_64 glibc，仓库追踪的二进制可在 AMD/Intel 的 Void glibc 机器间共用。
