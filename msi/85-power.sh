#!/bin/sh
# 安静电源配置 + 启用 tlp 服务
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo xbps-install -S tlp
sudo install -d /etc/tlp.d
sudo install -m 644 "$dir/etc/tlp.d/10-xfn.conf" /etc/tlp.d/10-xfn.conf
sudo ln -sfn /etc/sv/tlp /var/service/tlp
