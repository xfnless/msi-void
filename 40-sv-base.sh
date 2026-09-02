#!/bin/sh
# Services shared by both hosts.
set -eu

sudo ln -sfn /etc/sv/chronyd /var/service/chronyd
sudo ln -sfn /etc/sv/dbus /var/service/dbus
sudo ln -sfn /etc/sv/seatd /var/service/seatd
sudo ln -sfn /etc/sv/bluetoothd /var/service/bluetoothd
sudo usermod -aG _seatd "$USER"

sudo rm -f \
	/var/service/agetty-tty3 \
	/var/service/agetty-tty4 \
	/var/service/agetty-tty5 \
	/var/service/agetty-tty6

for service in /var/service/*; do
	[ -d "$service/log" ] || continue
	target=$(readlink -f "$service")
	sudo touch "$target/log/down"
	sudo sv down "$service/log" 2>/dev/null || true
done

printf '%s\n' \
	'公共服务已启用，立即生效。' \
	'用户组变更将在下次登录生效。' \
	'TTY：执行 exit 后重新登录。' \
	'Niri：退出整个会话后重新登录；只关闭终端不够。'
