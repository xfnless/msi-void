#!/bin/sh
# MSI chooses Firefox as its default browser.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ln -sfn "$dir/home/.config/mimeapps.list" "$HOME/.config/mimeapps.list"
