#!/bin/sh
# Link shell, input method and common River files.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
h=$dir/home

mkdir -p "$HOME/.config/fcitx5" "$HOME/.config/pipewire/pipewire.conf.d"
ln -sfn /usr/share/examples/wireplumber/10-wireplumber.conf \
	"$HOME/.config/pipewire/pipewire.conf.d/"
ln -sfn /usr/share/examples/pipewire/20-pipewire-pulse.conf \
	"$HOME/.config/pipewire/pipewire.conf.d/"
ln -sfn "$h/.bash_profile" "$HOME/.bash_profile"
ln -sfn "$h/.bashrc" "$HOME/.bashrc"
ln -sfn "$h/.cwmrc" "$HOME/.cwmrc"
ln -sfn "$h/.inputrc" "$HOME/.inputrc"
ln -sfn "$h/.Xresources" "$HOME/.Xresources"
ln -sfn "$h/.xinitrc" "$HOME/.xinitrc"
ln -sfnT "$h/.config/labwc" "$HOME/.config/labwc"
ln -sfnT "$h/.config/river" "$HOME/.config/river"
ln -sfn "$h/.config/fcitx5/profile" "$HOME/.config/fcitx5/profile"
