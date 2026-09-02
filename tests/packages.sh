#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

for name in wl-kbptr xwayland-satellite nss nspr; do
	if grep -Eq "(^|[[:space:]])$name([[:space:]\\\\]|$)" \
		"$repo/20-pkg-base.sh" "$repo/60-pkg-apps.sh"; then
		fail "$name remains explicitly installed"
	fi
done

if grep -Fq 'spawn "wl-kbptr"' "$repo/root/home/.config/niri/config.kdl"; then
	fail 'Niri still binds wl-kbptr'
fi

printf 'ok - optional package list stays minimal\n'
