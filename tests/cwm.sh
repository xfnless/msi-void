#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

grep -Fx 'Xft.dpi: 144' "$root/home/.Xresources" >/dev/null
grep -Fx 'fontname "WenQuanYi Micro Hei:pixelsize=21"' "$root/home/.cwmrc" >/dev/null
grep -Fx 'command term alacritty' "$root/home/.cwmrc" >/dev/null
grep -Fx 'export GTK_IM_MODULE=fcitx' "$root/home/.xinitrc" >/dev/null
grep -Fx 'export QT_IM_MODULE=fcitx' "$root/home/.xinitrc" >/dev/null
grep -Fx 'export XMODIFIERS=@im=fcitx' "$root/home/.xinitrc" >/dev/null
grep -Fx 'xrdb -merge "$HOME/.Xresources"' "$root/home/.xinitrc" >/dev/null
grep -Fx 'xset r rate 250 40' "$root/home/.xinitrc" >/dev/null
grep -Fx 'fcitx5 &' "$root/home/.xinitrc" >/dev/null
grep -F 'MatchIsTouchpad "on"' "$root/etc/X11/xorg.conf.d/30-touchpad.conf" >/dev/null
grep -F 'Option "Tapping" "on"' "$root/etc/X11/xorg.conf.d/30-touchpad.conf" >/dev/null
grep -F 'sh 35-xorg.sh' "$root/flow.txt" >/dev/null
