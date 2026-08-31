#!/bin/sh
# Xorg input defaults shared by both laptops.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sudo install -Dm644 "$dir/etc/X11/xorg.conf.d/30-touchpad.conf" \
  /etc/X11/xorg.conf.d/30-touchpad.conf
