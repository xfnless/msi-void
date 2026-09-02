#!/bin/sh
# 装 keyd 配置并启用服务（包在 20-pkg-base.sh）
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sudo install -d /etc/keyd
sudo install -m 644 "$dir/root/etc/keyd/"*.conf /etc/keyd/
sudo ln -sfn /etc/sv/keyd /var/service/keyd
printf '%s\n' 'keyd 配置已安装、服务已启用，立即生效。'
