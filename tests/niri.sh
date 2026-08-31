#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

[ -f "$root/home/.config/niri/config.kdl" ] || fail 'Niri configuration is active'
[ ! -e "$root/archive/home/.config/niri" ] || fail 'Niri is no longer archived'
grep -q '^ni() {' "$root/home/.bashrc" || fail 'ni starts Niri from a TTY'
grep -Fq 'dbus-run-session niri --session' "$root/home/.bashrc" || fail 'Niri runs in a D-Bus session'
grep -Fq 'ln -sfnT "$h/.config/niri" "$HOME/.config/niri"' "$root/50-link-home.sh" || fail 'Niri config is linked'
grep -Eq '(^|[[:space:]])niri([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'Niri is installed'
grep -Eq '(^|[[:space:]])swappy([[:space:]\\]|$)' "$root/60-pkg-apps.sh" || fail 'Swappy is installed'
grep -Fq '| swappy -f -' "$root/home/.config/niri/config.kdl" || fail 'screenshots open in Swappy'
if grep -Riq 'satty' "$root/20-pkg-base.sh" "$root/60-pkg-apps.sh" "$root/home/.config/niri"; then
	fail 'Satty remains in the active setup'
fi
if grep -Eiq 'niri-float-sticky|bemenu|wlopm' "$root/20-pkg-base.sh"; then
	fail 'unused Niri helpers remain in the base package list'
fi

for path in \
	"$root/home/.config/labwc" "$root/home/.config/river" "$root/home/.config/tri" \
	"$root/home/.config/tint2" "$root/home/.config/yambar" \
	"$root/home/.cwmrc" "$root/home/.xinitrc" "$root/home/.Xresources"; do
	[ ! -e "$path" ] || fail "old WM file remains: ${path#"$root/"}"
done

if grep -Eiq 'labwc|cwm|river|tri|yambar|tint2|xorg-minimal|startx' \
	"$root/20-pkg-base.sh" "$root/50-link-home.sh" "$root/70-link-apps.sh" "$root/home/.bashrc"; then
	fail 'an old WM remains in the active setup'
fi

niri validate --config "$root/home/.config/niri/config.kdl" >/dev/null
printf 'ok - Niri is the only active window manager\n'
