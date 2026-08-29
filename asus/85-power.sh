#!/bin/sh
# ASUS：电池 80% + quiet；iwlwifi 关省电；唤醒/掉线自动重连
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo install -o root -g root -m 755 "$dir/etc/rc.local" /etc/rc.local
sudo install -o root -g root -m 644 \
	"$dir/etc/modprobe.d/iwlwifi.conf" /etc/modprobe.d/iwlwifi.conf
sudo install -o root -g root -m 755 -D \
	"$dir/etc/zzz.d/resume/10-wifi" /etc/zzz.d/resume/10-wifi
sudo install -o root -g root -m 755 -D \
	"$dir/etc/wpa_supplicant/action-reconnect.sh" \
	/etc/wpa_supplicant/action-reconnect.sh
sudo /etc/rc.local
