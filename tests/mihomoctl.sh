#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo/root/home/.local/bin/mihomoctl
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

mkdir "$tmp/bin"
cat >"$tmp/bin/curl" <<'EOF'
#!/bin/sh
method=GET
body=
url=
while [ "$#" -gt 0 ]; do
	case $1 in
	--request) method=$2; shift 2 ;;
	--data) body=$2; shift 2 ;;
	--header|--connect-timeout) shift 2 ;;
	--fail|--silent|--show-error) shift ;;
	http://*) url=$1; shift ;;
	*) shift ;;
	esac
done
printf '%s|%s|%s\n' "$method" "$url" "$body" >>"$MIHOMO_TEST_LOG"
case $url in
*/configs) printf '%s\n' '{"mode":"rule"}' ;;
*/proxies/GLOBAL) printf '%s\n' '{"now":"香港","all":["香港","国内","DIRECT","custom node"]}' ;;
*/proxies/*) printf '%s\n' '{"now":"node one","all":["node one"]}' ;;
*/providers/proxies/marzban) printf '%s\n' '{"name":"marzban","proxies":[{"name":"香港 node"},{"name":"国内 node"}]}' ;;
*) printf '%s\n' '{}' ;;
esac
EOF
cat >"$tmp/bin/sv" <<'EOF'
#!/bin/sh
printf '%s\n' 'run: mihomo: (pid 42) 10s'
EOF
cat >"$tmp/bin/mihomo" <<'EOF'
#!/bin/sh
printf '%s\n' 'configuration file test is successful'
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/sv" "$tmp/bin/mihomo"

run_ctl() {
	: >"$tmp/log"
	MIHOMO_TEST_LOG=$tmp/log CURL=$tmp/bin/curl SV=$tmp/bin/sv \
		MIHOMO=$tmp/bin/mihomo MIHOMO_LOG=$tmp/current "$script" "$@"
}

[ -x "$script" ] || fail 'mihomoctl does not exist'

run_ctl use rule split
grep -Fq '|http://127.0.0.1:9090/configs|{"mode":"rule"}' "$tmp/log" || fail 'rule mode does not use native configs API'

run_ctl use global hk
grep -Fq '/proxies/GLOBAL|{"name": "香港"}' "$tmp/log" || fail 'hk alias does not select Hong Kong'
grep -Fq '/configs|{"mode":"global"}' "$tmp/log" || fail 'hk alias does not enable global mode'

run_ctl use global cn
grep -Fq '/proxies/GLOBAL|{"name": "国内"}' "$tmp/log" || fail 'cn alias does not select domestic node'

run_ctl use global 'custom node'
grep -Fq '/proxies/GLOBAL|{"name": "custom node"}' "$tmp/log" || fail 'exact node name is not safely encoded as JSON'

if run_ctl use global missing >"$tmp/out" 2>"$tmp/err"; then
	fail 'unknown global node is accepted'
fi
grep -Fq '未知节点' "$tmp/err" || fail 'unknown node error is unclear'

run_ctl use direct
grep -Fq '/configs|{"mode":"direct"}' "$tmp/log" || fail 'direct does not use native mode API'

run_ctl update
grep -Fq 'PUT|http://127.0.0.1:9090/providers/proxies/marzban|' "$tmp/log" || fail 'provider update does not use native provider API'

if run_ctl use rule missing >"$tmp/out" 2>"$tmp/err"; then
	fail 'unknown rule policy is accepted'
fi
grep -Fq 'mihomoctl use rule split' "$tmp/err" || fail 'usage does not show accepted rule policy'

printf 'ok - mihomoctl maps clear modes and safe node names onto the native API\n'
