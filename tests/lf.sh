#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lfrc=$repo/root/home/.config/lf/lfrc
preview=$repo/root/home/.config/lf/preview
archive=$repo/root/home/.local/bin/lf-archive
detach=$repo/root/home/.local/bin/lf-detach
show_items=$repo/root/home/.local/bin/lf-show-items
portal=$repo/root/home/.config/xdg-desktop-portal/niri-portals.conf

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

[ -f "$lfrc" ] || fail 'LF main configuration exists'
[ -x "$preview" ] || fail 'LF previewer is executable'
[ -x "$archive" ] || fail 'safe LF archive helper exists'
[ -x "$detach" ] || fail 'detached launcher exists'
[ -x "$show_items" ] || fail 'FileManager1 ShowItems adapter exists'
grep -Fx 'org.freedesktop.impl.portal.FileChooser=termfilechooser' "$portal" >/dev/null ||
	fail 'Niri selects the terminal file chooser portal'
if grep -Eiq 'river|wlr' "$portal"; then
	fail 'Niri portal config contains stale River or wlroots backends'
fi
[ ! -e "$repo/root/home/.config/xdg-desktop-portal/river-portals.conf" ] ||
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

# A GUI child must outlive the terminal-side process that launched it.
cat >"$tmp/gui-child" <<'EOF'
#!/bin/sh
sleep 0.2
printf 'alive\n' >"$LF_TEST_ALIVE"
EOF
chmod +x "$tmp/gui-child"
LF_TEST_ALIVE="$tmp/alive" "$detach" "$tmp/gui-child"
i=0
while [ ! -s "$tmp/alive" ] && [ "$i" -lt 20 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ "$(cat "$tmp/alive" 2>/dev/null || :)" = alive ] ||
	fail 'detached GUI process survives its launcher'

# ShowItems must preserve and select the file, not reduce it to its parent.
mkdir "$tmp/bin"
cat >"$tmp/bin/alacritty" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$LF_TEST_ARGS"
EOF
chmod +x "$tmp/bin/alacritty"
LF_TEST_ARGS="$tmp/args" PATH="$tmp/bin:$PATH" \
	"$show_items" 'file:///tmp/a%20file%25.txt'
i=0
while [ ! -s "$tmp/args" ] && [ "$i" -lt 20 ]; do
	sleep 0.05
	i=$((i + 1))
done
expected=$(printf '%s\n' '--title' 'lf: /tmp/a file%.txt' '-e' 'lf' '-single' '/tmp/a file%.txt')
[ "$(cat "$tmp/args" 2>/dev/null || :)" = "$expected" ] ||
	fail 'ShowItems selects the decoded file path in lf'

printf 'ok - LF previews text and archives selections without deleting input\n'

grep -Fq 'gio trash -- $fx' "$lfrc" || fail 'D does not use the standard trash'
grep -Fxq 'map D trash' "$lfrc" || fail 'D is not mapped to trash'
grep -Fq "printf '%s\\n' \$fx | wl-copy" "$lfrc" || fail 'full paths cannot be copied'
grep -Fq 'basename -- "$path"' "$lfrc" || fail 'file names cannot be copied'
grep -Fxq 'map yp copy_path' "$lfrc" || fail 'yp does not copy paths'
grep -Fxq 'map yn copy_name' "$lfrc" || fail 'yn does not copy names'
grep -Fxq 'set dircounts' "$lfrc" || fail 'directory item counts are not enabled'
if grep -Eq '^map zc([[:space:]]|$)' "$lfrc"; then
	fail 'directory counts can still be disabled globally'
fi
grep -Fq 'du -sh -- "$f"' "$lfrc" || fail 'directory size is not calculated for the current item'
grep -Fxq 'map zd dir_size' "$lfrc" || fail 'zd does not show the current directory size'
if grep -Fq 'set nodircounts' "$lfrc"; then
	fail 'calculating one directory still disables counts globally'
fi
grep -Fxq 'set infotimefmtnew "01-02 15:04"' "$lfrc" || fail 'current-year dates are not compact numeric values'
grep -Fxq 'set infotimefmtold "2006-01-02"' "$lfrc" || fail 'older dates are not numeric values'
grep -Fxq 'set timefmt "2006-01-02 15:04:05"' "$lfrc" || fail 'bottom timestamps are not numeric values'
printf 'ok - LF has recoverable deletion and compact file utilities\n'
