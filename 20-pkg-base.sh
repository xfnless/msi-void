#!/bin/sh
# Packages shared by both River laptops.
set -eu

sudo xbps-install -Syu
sudo xbps-install -S \
	alacritty dbus seatd wlroots0.20 fcft libutf8proc \
	swayidle swaylock wlsunset wlopm wl-clipboard brightnessctl \
	pipewire wireplumber alsa-pipewire \
	fcitx5 fcitx5-rime keyd \
	bash-completion git fastfetch \
	font-inconsolata-otf wqy-microhei
