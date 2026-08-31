#!/bin/sh
# Packages shared by both Niri laptops.
set -eu

sudo xbps-install -Syu
sudo xbps-install -S \
	alacritty dbus seatd niri niri-float-sticky xwayland-satellite \
	bemenu swaybg wl-kbptr \
	swayidle swaylock wlsunset wlopm wl-clipboard brightnessctl \
	pipewire wireplumber alsa-pipewire \
	fcitx5 fcitx5-rime keyd \
	bash-completion git fastfetch \
	font-inconsolata-otf wqy-microhei
