#!/bin/sh
# Daily terminal desktop applications shared by both hosts.
set -eu

sudo xbps-install -S \
	firefox \
	grim slurp swappy \
	imv mpv zathura zathura-pdf-poppler \
	xdg-utils \
	curl fd fzf ripgrep bat chafa htop xz \
	StyLua shfmt ruff nodejs \
	nss nspr telegram-desktop
