#!/bin/sh
#
# 开机路径（两层）：
#
#   1) 主板 EFI 启动项
#      先启动名叫 "void" 的项 → 加载 \EFI\void\grubx64.efi
#      （不是直接进 Windows；Windows 排第二只是备用）
#
#   2) GRUB 菜单（平时隐藏）
#      默认第 0 项 = Windows → 所以不开菜单就会进 Win
#      开机闪一下时按 Esc → 出现菜单，可选 Void 内核
#
# 本脚本只改「GRUB 菜单内容 / 隐藏方式」和「EFI 启动顺序」。
# 不重装 grubx64.efi（你系统里已经有了）。
#

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# --- GRUB 配置：隐藏菜单、默认第一项 ---
# 文件说明见同目录 grub/default
sudo cp -n /etc/default/grub /etc/default/grub.bak
sudo install -m 644 "$repo/root/etc/default/grub.msi" /etc/default/grub

# --- 菜单项：Windows 写在 Void 内核前面 ---
# 09_windows 文件名里的 09 比 10_linux 小，所以生成菜单时 Win 在上、Void 在下
# 内容说明见 grub/09_windows
sudo install -m 755 "$repo/root/etc/grub.d/09_windows" /etc/grub.d/09_windows

# 根据上面两份配置，重写 /boot/grub/grub.cfg
sudo update-grub

# --- EFI 启动顺序：void 先于 Windows Boot Manager ---
# efibootmgr 列出类似：
#   Boot0003* void
#   Boot0001* Windows Boot Manager
# 下面两行只是把编号抠出来，再设成 void,windows
void=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]*\)\* void.*/\1/p')
win=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]*\)\* Windows Boot Manager.*/\1/p')
sudo efibootmgr --bootorder "$void,$win"

echo "看结果：efibootmgr ；菜单预览：grep menuentry /boot/grub/grub.cfg"
printf '%s\n' 'GRUB 已更新；启动行为在下次重启时生效。'
