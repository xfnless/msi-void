#!/bin/sh
set -eu

tri_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/tri-session-test.XXXXXX")
cleanup() {
	rm -rf -- "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

marker=$tmp_dir/must-not-exist
config=$tmp_dir/config
output=$tmp_dir/output
printf '%s\n' \
	'env.QT_IM_MODULE = test input method' \
	'env.BAD-NAME = ignored' \
	"env.LITERAL = \$(touch $marker)" \
	'cursor_theme = TestCursor' \
	'cursor_size = 31' \
	'output = auto' \
	'mode = 1920x1080@60Hz' \
	'scale = 1.25' >"$config"

TRI_CONFIG=$config TRI_SESSION_DRY_RUN=1 "$tri_dir/session.sh" >"$output"

grep -F 'ENV QT_IM_MODULE=test input method' "$output" >/dev/null
grep -F "ENV LITERAL=\$(touch $marker)" "$output" >/dev/null
grep -F 'CURSOR_THEME TestCursor' "$output" >/dev/null
grep -F 'CURSOR_SIZE 31' "$output" >/dev/null
grep -F 'OUTPUT auto' "$output" >/dev/null
grep -F 'MODE 1920x1080@60Hz' "$output" >/dev/null
grep -F 'SCALE 1.25' "$output" >/dev/null
if grep -F 'BAD-NAME' "$output" >/dev/null; then
	echo 'invalid environment name was accepted' >&2
	exit 1
fi
if [ -e "$marker" ]; then
	echo 'configuration value was executed' >&2
	exit 1
fi
