#!/bin/sh
# ASUS uses its own display values; Firefox is the common default browser.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ ! -L "$HOME/.config/tri" ] || rm "$HOME/.config/tri"
mkdir -p "$HOME/.config/tri"
ln -sfn "$dir/home/.config/tri/config" "$HOME/.config/tri/config"
ln -sfn "$dir/home/.config/mimeapps.list" "$HOME/.config/mimeapps.list"
