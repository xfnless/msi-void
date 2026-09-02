#!/bin/sh
# Daily terminal desktop applications shared by both hosts.
set -eu

sudo xbps-install -S \
	firefox \
	grim slurp swappy \
	imv mpv zathura zathura-pdf-poppler \
	xdg-desktop-portal-termfilechooser xdg-utils \
	lf python3-dbus python3-gobject curl fd fzf ripgrep bat chafa htop xz \
	StyLua shfmt ruff nodejs \
	nss nspr telegram-desktop
printf '%s\n' '应用软件包已安装；程序可立即运行。'
