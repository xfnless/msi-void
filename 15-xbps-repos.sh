#!/bin/sh
# 可选：换 Fastly 主源并启用 nonfree（装机已配可跳过）
# intel-ucode 等在 nonfree
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo install -d /etc/xbps.d
sudo install -m 644 "$dir/root/etc/xbps.d/00-repository-main.conf" /etc/xbps.d/00-repository-main.conf
sudo install -m 644 "$dir/root/etc/xbps.d/20-nonfree.conf" /etc/xbps.d/20-nonfree.conf
