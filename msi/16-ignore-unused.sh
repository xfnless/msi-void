#!/bin/sh
# 可选：忽略并卸掉本机用不到的固件 / FS 工具等
# 保留 intel-ucode、linux-firmware-intel、linux-firmware-network、sof-firmware
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo install -d /etc/xbps.d
# 旧文件名兼容：若曾装过 10-ignore-firmware.conf 则换掉
sudo rm -f /etc/xbps.d/10-ignore-firmware.conf
sudo install -m 644 "$dir/etc/xbps.d/10-ignorepkg.conf" /etc/xbps.d/10-ignorepkg.conf

sudo xbps-remove -y \
	linux-firmware-amd \
	linux-firmware-nvidia \
	linux-firmware-broadcom \
	wifi-firmware \
	ipw2100-firmware \
	ipw2200-firmware \
	zd1211-firmware \
	alsa-firmware \
	btrfs-progs \
	xfsprogs \
	f2fs-tools \
	traceroute \
	ethtool \
	swappy \
	|| true
