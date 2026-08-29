#!/bin/sh
set -e
LC_ALL=C
export LC_ALL
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

check_artifact() {
	artifact=$1
	[ -x "$artifact" ] || return 1
	readelf -h "$artifact" 2>/dev/null | grep -E 'Class:[[:space:]]+ELF64' >/dev/null || return 1
	readelf -h "$artifact" 2>/dev/null | grep -E 'Machine:[[:space:]]+Advanced Micro Devices X86-64' >/dev/null || return 1
	dynamic=$(readelf -d "$artifact" 2>/dev/null) || return 1
	for library in libwayland-client.so.0 libxkbcommon.so.0 libfcft.so.4 libpixman-1.so.0 libc.so.6; do
		printf '%s\n' "$dynamic" | grep -F "[$library]" >/dev/null || return 1
	done
	resolved=$(ldd "$artifact" 2>/dev/null) || return 1
	if printf '%s\n' "$resolved" | grep -F 'not found' >/dev/null; then
		return 1
	fi
	versions=$(readelf --version-info "$artifact" 2>/dev/null | sed -n 's/.*Name: GLIBC_\([0-9.]*\).*/\1/p') || return 1
	max_version=$(printf '2.38\n%s\n' "$versions" | sort -Vu | tail -n 1)
	[ "$max_version" = 2.38 ] || return 1
}

if [ -n "${TRI_REBUILD_TEST_FILE:-}" ]; then
	check_artifact "$TRI_REBUILD_TEST_FILE"
	exit
fi

zig build test
stage_dir=$(mktemp -d "$PWD/.tri-build.XXXXXX")
cleanup() {
	case "$stage_dir" in
	"$PWD"/.tri-build.*) rm -rf -- "$stage_dir" ;;
	esac
}
trap cleanup EXIT HUP INT TERM

zig build -Dtarget=x86_64-linux-gnu.2.38 -Dcpu=baseline -Doptimize=ReleaseSafe --prefix "$stage_dir"
check_artifact "$stage_dir/bin/tri"
mkdir -p zig-out/bin
if [ -x zig-out/bin/tri ]; then
	cp -p zig-out/bin/tri zig-out/bin/tri.previous
fi
mv "$stage_dir/bin/tri" zig-out/bin/tri.next
mv zig-out/bin/tri.next zig-out/bin/tri
cleanup
trap - EXIT HUP INT TERM
echo "built zig-out/bin/tri"
