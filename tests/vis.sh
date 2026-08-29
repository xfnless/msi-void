#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
status=$repo/home/.config/vis/my/status.lua

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

grep -q 'vis.ui:style_push' "$status" || fail 'status styles use the current Vis UI API'
if grep -q 'STYLE_LEXER_MAX\|win:style_define' "$status"; then
	fail 'status styles still use removed window style APIs'
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'vis startup test\n' >"$tmp/input"
TERM=xterm timeout 5 script -qec "vis +q '$tmp/input'" "$tmp/session" >/dev/null 2>&1 || \
	fail 'Vis starts and exits through a pseudo-terminal'
if grep -a -q 'status.lua:.*attempt to\|stack traceback' "$tmp/session"; then
	fail 'Vis startup reports a Lua configuration error'
fi

printf 'ok - Vis status styles use the supported UI API\n'
