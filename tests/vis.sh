#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
status=$repo/root/home/.config/vis/my/status.lua
formatter=$repo/root/home/.config/vis/my/formatter.lua

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

grep -q 'vis.ui:style_push' "$status" || fail 'status styles use the current Vis UI API'
if grep -q 'STYLE_LEXER_MAX\|win:style_define' "$status"; then
	fail 'status styles still use removed window style APIs'
fi

grep -Eq '(^|[[:space:]])go([[:space:]\\]|$)' "$repo/60-pkg-apps.sh" ||
	fail 'Go formatter is not installed'
grep -Fq 'syntax == "go"' "$formatter" || fail 'Vis does not recognize Go files'
grep -Fq 'return "gofmt"' "$formatter" || fail 'Vis does not format Go with gofmt'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'vis startup test\n' >"$tmp/input"
TERM=xterm timeout 5 script -qec "vis +q '$tmp/input'" "$tmp/session" >/dev/null 2>&1 || \
	fail 'Vis starts and exits through a pseudo-terminal'
if grep -a -q 'status.lua:.*attempt to\|stack traceback' "$tmp/session"; then
	fail 'Vis startup reports a Lua configuration error'
fi

# A clean Void install must receive every development package required by the
# features that 65-vis.sh enables explicitly.  Stub only the external package,
# network and build tools; execute the real installer script.
mkdir -p "$tmp/bin" "$tmp/home/.local/bin" "$tmp/home/.local/src/vis/.git"
cat >"$tmp/bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$VIS_TEST_LOG"
case " $* " in
	*' xbps-install '*-y*|*' xbps-install -'*y*) exit 0 ;;
	*) printf 'xbps install is not non-interactive\n' >&2; exit 1 ;;
esac
EOF
cat >"$tmp/bin/git" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/make" <<'EOF'
#!/bin/sh
printf 'make %s\n' "$*" >>"$VIS_TEST_LOG"
exit 0
EOF
cat >"$tmp/home/.local/src/vis/configure" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/home/.local/bin/vis" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"* "$tmp/home/.local/src/vis/configure" \
	"$tmp/home/.local/bin/vis"
VIS_TEST_LOG="$tmp/packages" HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
	sh "$repo/65-vis.sh"
for package in base-devel ncurses-devel lua54-devel lua54-lpeg tre-devel \
	acl-devel pkg-config; do
	grep -qw "$package" "$tmp/packages" || \
		fail "Vis installer does not install $package"
done
for suite in core lua vis; do
	grep -qx "make -C test/$suite" "$tmp/packages" || \
		fail "Vis installer does not run the non-interactive $suite tests"
done
if grep -qx 'make test' "$tmp/packages"; then
	fail 'Vis installer runs the interactive Vim comparison suite'
fi

printf 'ok - Vis config and source build dependencies are complete\n'
