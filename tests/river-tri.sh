#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

[ -x "$repo/home/.local/bin/river" ] || fail 'River executable exists'
[ -L "$repo/home/.local/bin/tri" ] || fail 'tri entry point is a symlink'
[ -x "$repo/home/.local/bin/tri-session" ] || fail 'tri-session entry point exists'
[ "$($repo/home/.local/bin/river -version 2>/dev/null)" = '0.4.8 -xwayland' ] || \
	fail 'River is portable version 0.4.8'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
set +e
env -u WAYLAND_DISPLAY -u XDG_RUNTIME_DIR "$repo/home/.local/bin/tri" >"$tmp/out" 2>"$tmp/err"
status=$?
set -e
[ "$status" -ne 132 ] || fail 'tri contains host-only CPU instructions'
grep -q 'ConnectFailed' "$tmp/err" || fail 'tri reaches its Wayland connection boundary'

sh -n "$repo/home/.config/river/init"
sh -n "$repo/home/.config/tri/session.sh"
sh "$repo/home/.config/tri/test-session.sh"
sh "$repo/home/.config/tri/test-rebuild.sh"

msi=$(TRI_CONFIG="$repo/msi/home/.config/tri/config" TRI_SESSION_DRY_RUN=1 \
	"$repo/home/.config/tri/session.sh")
asus=$(TRI_CONFIG="$repo/asus/home/.config/tri/config" TRI_SESSION_DRY_RUN=1 \
	"$repo/home/.config/tri/session.sh")
printf '%s\n' "$msi" | grep -qx 'MODE ' || fail 'MSI leaves native output mode unchanged'
printf '%s\n' "$msi" | grep -qx 'SCALE 1.5' || fail 'MSI applies scale 1.5'
printf '%s\n' "$asus" | grep -qx 'MODE 2560x1600@60Hz' || fail 'ASUS selects its panel mode'
printf '%s\n' "$asus" | grep -qx 'SCALE 1.5' || fail 'ASUS applies scale 1.5'
printf 'ok - portable River/tri uses explicit host configuration\n'
