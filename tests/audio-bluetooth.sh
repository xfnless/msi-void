#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

grep -Eq '(^|[[:space:]])pipewire([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'PipeWire is common'
grep -Eq '(^|[[:space:]])wireplumber([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'WirePlumber is common'
grep -Fq 'spawn-at-startup "pipewire"' "$root/root/home/.config/niri/config.kdl" || fail 'Niri starts PipeWire'
grep -Eq '(^|[[:space:]])bluez([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'BlueZ is common'
grep -Fq '/etc/sv/bluetoothd' "$root/40-sv-base.sh" || fail 'bluetoothd is enabled on both hosts'
if grep -Riq 'bluez\|bluetoothd' "$root/msi" "$root/asus"; then
	fail 'Bluetooth remains device-specific'
fi
printf 'ok - sound and Bluetooth are common\n'
