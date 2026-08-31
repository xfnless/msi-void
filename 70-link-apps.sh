#!/bin/sh
# Link only active common application configuration.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
h=$dir/home

mkdir -p "$HOME/.config" "$HOME/.local/bin" \
	"$HOME/.local/share/applications" "$HOME/.local/share/fcitx5/rime"

ln -sfn "$h/.npmrc" "$HOME/.npmrc"
for name in alacritty fd fontconfig htop lf mpv vis \
	xdg-desktop-portal xdg-desktop-portal-termfilechooser; do
	ln -sfnT "$h/.config/$name" "$HOME/.config/$name"
done

chmod +x "$h/.local/bin/"* 2>/dev/null || true
ln -sf "$h/.local/bin/"* "$HOME/.local/bin/"
ln -sfn "$h/.local/share/applications/helium.desktop" \
	"$HOME/.local/share/applications/helium.desktop"
ln -sfn "$h/.local/share/applications/lf.desktop" \
	"$HOME/.local/share/applications/lf.desktop"
ln -sfn "$h/.local/share/applications/vis.desktop" \
	"$HOME/.local/share/applications/vis.desktop"
ln -sf "$h/.local/share/fcitx5/rime/"* "$HOME/.local/share/fcitx5/rime/"

# Helium policy and initial preferences are common; only the default browser differs.
sudo install -d -o root -g root -m 755 \
	/etc/chromium/policies/managed /etc/chromium/policies/recommended
sudo install -o root -g root -m 644 \
	"$dir/etc/chromium/policies/managed/extensions.json" \
	/etc/chromium/policies/managed/extensions.json
sudo install -o root -g root -m 644 \
	"$dir/etc/chromium/policies/recommended/helium.json" \
	/etc/chromium/policies/recommended/helium.json
"$h/.local/bin/helium-seed-prefs" || true
