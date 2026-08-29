#!/bin/sh
# Services shared by both hosts.
set -eu

sudo ln -sfn /etc/sv/chronyd /var/service/chronyd
sudo ln -sfn /etc/sv/dbus /var/service/dbus
sudo ln -sfn /etc/sv/seatd /var/service/seatd
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
