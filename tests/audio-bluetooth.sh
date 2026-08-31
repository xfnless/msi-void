#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

grep -Eq '(^|[[:space:]])pipewire([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'PipeWire is common'
grep -Eq '(^|[[:space:]])wireplumber([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'WirePlumber is common'
grep -Fq 'spawn-at-startup "pipewire"' "$root/home/.config/niri/config.kdl" || fail 'Niri starts PipeWire'
grep -Eq '(^|[[:space:]])bluez([[:space:]\\]|$)' "$root/asus/20-pkg-hardware.sh" || fail 'ASUS installs BlueZ'
grep -Fq '/etc/sv/bluetoothd' "$root/asus/40-host-services.sh" || fail 'ASUS enables bluetoothd'
if grep -Riq 'bluez\|bluetooth' "$root/20-pkg-base.sh" "$root/40-sv-base.sh" "$root/msi"; then
	fail 'Bluetooth leaked into common or MSI setup'
fi
printf 'ok - sound is common and Bluetooth is ASUS-only\n'
