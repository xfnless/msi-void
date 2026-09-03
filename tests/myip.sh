#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo/root/home/.local/bin/myip
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

mkdir "$tmp/bin"
cat >"$tmp/bin/curl" <<'EOF'
#!/bin/sh
case ${MYIP_TEST_RESULT:-success} in
success) printf '%s\n' '当前 IP：183.56.224.54  来自于：中国 广东 广州  电信' ;;
failure) exit 7 ;;
esac
EOF
chmod +x "$tmp/bin/curl"

expected='当前 IP：183.56.224.54  来自于：中国 广东 广州  电信'
actual=$(PATH="$tmp/bin:$PATH" "$script") || fail 'successful lookup exits with an error'
[ "$actual" = "$expected" ] || fail 'successful lookup does not preserve the service response'

if PATH="$tmp/bin:$PATH" MYIP_TEST_RESULT=failure "$script" >"$tmp/out" 2>"$tmp/err"; then
	fail 'failed lookup exits successfully'
fi
[ ! -s "$tmp/out" ] || fail 'failed lookup writes misleading standard output'
grep -Fq '无法获取公网 IP' "$tmp/err" || fail 'failed lookup has no useful error message'

printf 'ok - myip reports the public address and handles request failures\n'
