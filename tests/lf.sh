#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lfrc=$repo/home/.config/lf/lfrc
preview=$repo/home/.config/lf/preview
archive=$repo/home/.local/bin/lf-archive
portal=$repo/home/.config/xdg-desktop-portal/niri-portals.conf

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

[ -f "$lfrc" ] || fail 'LF main configuration exists'
[ -x "$preview" ] || fail 'LF previewer is executable'
[ -x "$archive" ] || fail 'safe LF archive helper exists'
grep -Fx 'org.freedesktop.impl.portal.FileChooser=termfilechooser' "$portal" >/dev/null || \
	fail 'Niri selects the terminal file chooser portal'
if grep -Eiq 'river|wlr' "$portal"; then
	fail 'Niri portal config contains stale River or wlroots backends'
fi
[ ! -e "$repo/home/.config/xdg-desktop-portal/river-portals.conf" ] || \
	fail 'stale River portal selector remains'
sh -n "$preview"
sh -n "$archive"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'alpha\nbeta\n' >"$tmp/a file.txt"

preview_out=$($preview "$tmp/a file.txt" 80 20)
printf '%s\n' "$preview_out" | grep -q alpha || fail 'text preview returns file contents'

(cd "$tmp" && "$archive" tar bundle.tar.gz 'a file.txt')
[ -f "$tmp/a file.txt" ] || fail 'tar creation preserves selected input'
tar -tzf "$tmp/bundle.tar.gz" | grep -q 'a file.txt' || fail 'tar contains selected input'

if (cd "$tmp" && "$archive" tar bundle.tar.gz 'a file.txt') >/dev/null 2>&1; then
	fail 'archive helper overwrites an existing output'
fi

if (cd "$tmp" && "$archive" tar '' 'a file.txt') >/dev/null 2>&1; then
	fail 'archive helper accepts an empty output name'
fi

printf 'ok - LF previews text and archives selections without deleting input\n'
