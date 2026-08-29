#!/bin/sh
# 装 keyd 配置并启用服务（包在 20-pkg-base.sh）
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sudo mkdir -p /etc/keyd
sudo ln -sf "$dir"/etc/keyd/*.conf /etc/keyd/
sudo ln -sfn /etc/sv/keyd /var/service/keyd
