#!/bin/sh
#
# ASUS 开机路径：
#   主板默认进 Windows；按 Esc 选 void_grub 后，Void GRUB 无菜单立即进 Void。
#   不把 Windows 写进 GRUB 菜单。
#

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sudo cp -n /etc/default/grub /etc/default/grub.bak
sudo install -m 644 "$repo/root/etc/default/grub.asus" /etc/default/grub

# 本机不用 GRUB 里的 Windows 项（进 Win 走 ASUS EFI 菜单）。
sudo rm -f /etc/grub.d/09_windows

sudo update-grub

# 默认直接进入 Windows；Esc → void_grub 进 Void。
# Boot0000 / Boot0001 以本机 efibootmgr 现状为准。
sudo efibootmgr -o 0000,0001

echo "看结果：efibootmgr ；菜单预览：grep menuentry /boot/grub/grub.cfg"
