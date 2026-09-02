#!/bin/sh
# Link shell, input method and the common Niri configuration.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
h=$dir/root/home

mkdir -p "$HOME/.config/fcitx5" "$HOME/.config/pipewire/pipewire.conf.d"
ln -sfn /usr/share/examples/wireplumber/10-wireplumber.conf \
	"$HOME/.config/pipewire/pipewire.conf.d/"
ln -sfn /usr/share/examples/pipewire/20-pipewire-pulse.conf \
	"$HOME/.config/pipewire/pipewire.conf.d/"
ln -sfn "$h/.bash_profile" "$HOME/.bash_profile"
ln -sfn "$h/.bashrc" "$HOME/.bashrc"
ln -sfn "$h/.inputrc" "$HOME/.inputrc"
ln -sfnT "$h/.config/niri" "$HOME/.config/niri"
ln -sfn "$h/.config/fcitx5/profile" "$HOME/.config/fcitx5/profile"
