#!/bin/sh
# Packages shared by both Niri laptops.
set -eu

sudo xbps-install -Syu
sudo xbps-install -S \
	alacritty dbus seatd niri xwayland-satellite \
	swaybg wl-kbptr \
	swayidle swaylock wlsunset wl-clipboard brightnessctl \
	pipewire wireplumber alsa-pipewire alsa-utils \
	fcitx5 fcitx5-rime keyd \
	bash-completion git fastfetch \
	font-inconsolata-otf wqy-microhei
