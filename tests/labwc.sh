#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config=$root/home/.config/labwc

grep -Fx 'QT_IM_MODULE=fcitx' "$config/environment" >/dev/null
grep -Fx 'QT_IM_MODULES=wayland;fcitx' "$config/environment" >/dev/null
grep -Fx 'XMODIFIERS=@im=fcitx' "$config/environment" >/dev/null
grep -Fx 'wlr-randr --output eDP-1 --scale 1.5' "$config/autostart" >/dev/null
grep -Fx 'fcitx5 &' "$config/autostart" >/dev/null
grep -F 'ln -sfnT "$h/.config/labwc" "$HOME/.config/labwc"' "$root/50-link-home.sh" >/dev/null
