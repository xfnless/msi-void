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
printf '%s\n' \
	'基础用户配置已链接。Niri 配置会自动重载；Shell 配置在新终端生效。'
