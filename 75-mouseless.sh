#!/bin/sh
# Build Mouseless and grant the logged-in user access to input and uinput.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mouseless_tmp=$(mktemp -d)
trap 'rm -rf "$mouseless_tmp"' EXIT HUP INT TERM

GOBIN=$mouseless_tmp go install github.com/jbensmann/mouseless@latest

sudo install -o root -g root -m 755 "$mouseless_tmp/mouseless" /usr/local/bin/mouseless
sudo groupadd -f -r uinput
sudo usermod -aG input,uinput "$USER"
sudo install -o root -g root -m 644 -D \
	"$repo/root/etc/udev/rules.d/99-mouseless.rules" \
	/etc/udev/rules.d/99-mouseless.rules
sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=uinput

# Remove the former root runit service when upgrading this configuration.
sudo sv down /var/service/mouseless 2>/dev/null || true
sudo rm -f /var/service/mouseless /etc/sv/mouseless/run /etc/mouseless/config.yaml
sudo rmdir /etc/sv/mouseless /etc/mouseless 2>/dev/null || true

printf '%s\n' \
	'Mouseless 已安装，将由 Niri 在登录后启动。' \
	'退出整个 Niri 会话再重新登录，使 input/uinput 用户组生效。'
