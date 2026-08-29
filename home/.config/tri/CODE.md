# tri — 代码结构与实现备忘

---

## 文件

| 文件 | 作用 |
|------|------|
| `src/main.zig` | 布局、焦点、键鼠 |
| `src/titlebar.zig` | chip（序号左、标题右；列镜像时反过来） |
| `src/config.zig` | 读 `config` |
| `src/bindings.zig` | 键位、命令/内部动作解析与冲突处理 |
| `src/child_reaper.zig` | 回收快捷键命令子进程 |
| `session.sh` | 读取会话环境/输出并启动 tri |
| `test-session.sh` | session 安全解析测试 |
| `test-rebuild.sh` | 构建产物拒绝测试 |
| `config` | 日用配置 |

---

## 状态

```text
master, stack[9], expanded, focus_side, stack_on_left, monocle
```

- `layoutManage`：右列始终只有一个展开窗，其余槽显示 chip

---

## 键位

当前完整键位写在 `config`：左边是键，右边是 shell 命令或以 `:` 开头的 tri 内部动作。代码不预设终端、浏览器、截图、亮度和音量命令。

- `Super+a / c / v` → 终端 / 浏览器 / 备忘
- `Super+w` → 全屏截图
- `Super+Shift+q / Super+Ctrl+Shift+q` → 关闭窗口 / 退出会话
- `Super+s / e / d` → 切换焦点列 / 上一个 / 下一个
- `Super+Shift+s / e / d` → 主窗与展开窗交换 / 向上 / 向下移动
- `Super+f` → Monocle（只改变 WM 布局）
- 应用可自行切换全屏界面，但 WM 不改变窗口尺寸和位置
- `Super+r / Super+Shift+r` → 交换左右宽度 / 镜像列位置
- `Super+1…9` → `expand_slot_1…9`
- `Super+Shift+1…9` → `move_slot_1…9`
- `Super+Escape` → 开关屏幕；亮度、音量和静音使用硬件键

格式：`bind.Super+a = exec alacritty` 或 `bind.Super+s = :focus_toggle`。长驻的简单命令建议加 `exec`；管道等 shell 表达式直接写。修饰键支持 `Super/Ctrl/Shift/Alt`；删除配置行即可禁用。无效项和重复键会被忽略并记录警告，不会终止 WM；短命令结束后由 tri 回收，不留僵尸进程。

## 会话

- `env.NAME = value`：由 `session.sh` 安全导出，不会 source/eval 配置。
- `output/mode/scale`：启动 tri 前交给 `wlr-randr`；`output = auto` 跳过。
- `start.label = command`：由 tri 按配置顺序启动，标签无内建含义。
- 应用、输入法、portal、音频、锁屏和设备路径只写在 `config`，不写死进脚本或 Zig。

---

## chip

- `setChip(slot_ch, title, kind)`；`stack_on_left` 时序号与标题左右对调
- 无 `chip_align` 配置

---

## 构建

```bash
./rebuild.sh   # baseline x86_64 glibc → zig-out/bin/tri
```
