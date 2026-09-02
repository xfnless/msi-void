#!/bin/sh
# Build Mouseless, install its root-owned configuration and enable runit.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mouseless_tmp=$(mktemp -d)
trap 'rm -rf "$mouseless_tmp"' EXIT HUP INT TERM

GOBIN=$mouseless_tmp go install github.com/jbensmann/mouseless@latest

sudo install -o root -g root -m 755 "$mouseless_tmp/mouseless" /usr/local/bin/mouseless
sudo install -o root -g root -m 644 -D \
	"$repo/root/etc/mouseless/config.yaml" /etc/mouseless/config.yaml
sudo install -o root -g root -m 755 -D \
	"$repo/root/etc/sv/mouseless/run" /etc/sv/mouseless/run
sudo ln -sfn /etc/sv/mouseless /var/service/mouseless

printf '%s\n' 'Mouseless 已安装、服务已启用，keyd 鼠标层立即生效。'
