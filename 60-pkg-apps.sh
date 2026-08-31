#!/bin/sh
# Daily terminal desktop applications shared by both hosts.
set -eu

sudo xbps-install -S \
	firefox google-chrome \
	grim slurp swappy \
	imv mpv zathura zathura-pdf-poppler \
	xdg-desktop-portal-termfilechooser xdg-utils \
	lf curl fd fzf ripgrep bat chafa htop xz \
	StyLua shfmt ruff nodejs \
	nss nspr telegram-desktop
