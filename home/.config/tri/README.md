# tri

tri 是面向 River 0.4 的个人窗口管理器：左侧主窗口，右侧为一个展开窗口与若干标题 chip 组成的手风琴栈。

## 支持边界

tri 冻结现有功能，不计划加入 workspace、IPC、动画、窗口规则或传统浮动布局。正式支持 River 0.4、单输出、单 seat；多输出环境只使用 River 报告的第一个有效输出。仓库内二进制面向 Void Linux glibc 2.38+、基础 x86_64 指令集，AMD 和 Intel 共用；系统需提供 `libwayland-client.so.0`、`libxkbcommon.so.0`、`libfcft.so.4` 和 `libpixman-1.so.0`。

完整键位见 `CODE.md`，布局语义见 `DESIGN.md`。

## 换设备使用

拉取 `voidlinux-config` 后，让正式配置指向仓库目录：

```sh
ln -s "$HOME/voidlinux-config/home/.config/tri" "$HOME/.config/tri"
ln -s "$HOME/.config/tri/session.sh" "$HOME/.local/bin/tri-session"
ldd "$HOME/.config/tri/zig-out/bin/tri"
```

然后只编辑 `config`。另一台机器通常需要调整 `output/mode/scale`、`env.*`、`start.*` 和外部命令；`output = auto` 表示不调用 `wlr-randr`。仓库已经带源码和通用二进制，不需要安装 Zig。

也可用 `TRI_CONFIG=/path/config` 指定配置、`TRI_BIN=/path/tri` 指定二进制。

## 配置

- `env.NAME = value`：在 D-Bus 和 tri 启动前导出环境变量。
- `start.label = command`：按文件顺序启动一次；标签仅用于阅读。
- `bind.key = command`：运行 shell 命令；值以 `:` 开头时调用 tri 内部动作。
- 长驻的简单命令建议写 `exec program`，避免多留一层 shell。
- 删除一行即可禁用；无效的可选项只会警告或跳过。

## 构建

```sh
./rebuild.sh
```

只有修改源码时才需要 Zig 0.16。脚本先运行单元测试，再用 `x86_64-linux-gnu.2.38`、`cpu=baseline` 生成 ReleaseSafe 候选文件；通过 ELF 和动态库检查后保存当前二进制为 `tri.previous`，最后原子替换日用二进制。

完整日用配置见 `config`。

## 版本策略

固定已经实机验证的 River 0.4、Zig 0.16 和 `build.zig.zon` 中的依赖提交。依赖升级应单独进行，并在进入日用会话前完成测试和冒烟验证。

## River 实机会话检查

自动测试不能模拟 compositor。更新日用版本前应在可恢复的 River 会话中检查：

- 启动、退出以及 WM 重新启动后已有窗口仍可管理；
- 新增和关闭 master、展开窗及折叠窗；
- `Super+s/e/d`、对应的 Shift 移动操作及数字槽位；
- `Super+f` 和列镜像；
- 点击每个 chip 后展开和焦点同步；
- 连续改变窗口标题及快速展开多个槽时 chip 无闪退或绘制损坏；
- 锁屏、熄屏、恢复以及触摸板和音量/亮度按键。

发生问题时先运行 `zig-out/bin/tri.previous`，并保留终端或 journal 中的 tri 日志。
