#!/bin/sh
# Packages shared by both Niri laptops.
set -eu

sudo xbps-install -Syu
sudo xbps-install -S \
	alacritty dbus seatd niri \
	swaybg \
	swayidle swaylock wlsunset wl-clipboard brightnessctl \
	pipewire wireplumber alsa-pipewire bluez \
	fcitx5 fcitx5-rime keyd \
	bash-completion git fastfetch \
	font-inconsolata-otf wqy-microhei
printf '%s\n' '公共软件包已安装；程序可立即运行。'
