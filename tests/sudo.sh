#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

mkdir -p "$tmp/bin" "$tmp/etc/sudoers.d"
cat >"$tmp/bin/sudo" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
	install)
		src=${8}
		dst=${9}
		cp "$src" "$dst"
		chmod 440 "$dst"
		;;
	visudo)
		test "$2" = -cf
		test -f "$3"
		;;
	*) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/sudo"

PATH="$tmp/bin:$PATH" SUDOERS_DIR="$tmp/etc/sudoers.d" USER=tester \
	sh "$repo/16-sudo.sh"

rule=$tmp/etc/sudoers.d/10-tester-nopasswd
[ -f "$rule" ] || fail 'passwordless sudo rule was not installed'
[ "$(stat -c %a "$rule")" = 440 ] || fail 'sudoers rule mode is not 0440'
[ "$(cat "$rule")" = 'tester ALL=(ALL:ALL) NOPASSWD: ALL' ] || \
	fail 'sudoers rule does not grant the configured user passwordless sudo'
printf 'ok - passwordless sudo is installed for the current user\n'
