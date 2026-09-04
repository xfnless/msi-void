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
*/rules) printf '%s\n' '{"rules":[{"index":0,"type":"AND","payload":"((OR,work-apps),(GEOSITE,category-ads-all))","proxy":"REJECT","extra":{"disabled":false}}]}' ;;
*/proxies/GLOBAL) printf '%s\n' '{"now":"香港","all":["香港","国内","DIRECT","custom node"]}' ;;
*/proxies/%E9%A6%99%E6%B8%AF) printf '%s\n' '{"now":"香港节点","all":["香港节点"]}' ;;
*/proxies/%E5%9B%BD%E5%86%85) printf '%s\n' '{"now":"国内节点","all":["国内节点"]}' ;;
*/proxies/*) printf '%s\n' '{"now":"node one","all":["node one"]}' ;;
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
cat >"$tmp/bin/sudo" <<'EOF'
#!/bin/sh
printf 'SUDO|%s\n' "$*" >>"$MIHOMO_TEST_LOG"
exec "$@"
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/sv" "$tmp/bin/mihomo" "$tmp/bin/sudo"
printf '%s\n' 'service log line' >"$tmp/current"

run_ctl() {
	: >"$tmp/log"
	MIHOMO_TEST_LOG=$tmp/log CURL=$tmp/bin/curl SV=$tmp/bin/sv \
		SUDO=$tmp/bin/sudo MIHOMO=$tmp/bin/mihomo MIHOMO_LOG=$tmp/current \
		"$script" "$@"
}

[ -x "$script" ] || fail 'mihomoctl does not exist'

run_ctl status >/dev/null
grep -Fq "SUDO|$tmp/bin/sv status mihomo" "$tmp/log" || fail 'root runit status does not elevate'

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

run_ctl nodes >"$tmp/out"
grep -Fq '香港节点' "$tmp/out" || fail 'nodes does not list the static Hong Kong node'
grep -Fq '国内节点' "$tmp/out" || fail 'nodes does not list the static domestic node'

run_ctl update >"$tmp/out"
grep -Fq '静态节点无需更新' "$tmp/out" || fail 'update does not explain static node behavior'
if grep -Fq '/providers/' "$tmp/log"; then
	fail 'static update still calls a subscription provider'
fi

run_ctl adblock off
grep -Fq 'PATCH|http://127.0.0.1:9090/rules/disable|{"0":true}' "$tmp/log" || fail 'adblock off does not temporarily disable the native rule'

run_ctl adblock on
grep -Fq 'PATCH|http://127.0.0.1:9090/rules/disable|{"0":false}' "$tmp/log" || fail 'adblock on does not enable the native rule'

run_ctl adblock status >"$tmp/out"
grep -Fq 'on' "$tmp/out" || fail 'adblock status does not report the native rule state'

if run_ctl use rule missing >"$tmp/out" 2>"$tmp/err"; then
	fail 'unknown rule policy is accepted'
fi
grep -Fq 'mihomoctl use rule split' "$tmp/err" || fail 'usage does not show accepted rule policy'

run_ctl check >/dev/null
grep -Fq "SUDO|$tmp/bin/mihomo -t -d /var/lib/mihomo -f /etc/mihomo/config.yaml" "$tmp/log" || fail 'private configuration check does not elevate'

run_ctl log >"$tmp/out"
grep -Fq 'service log line' "$tmp/out" || fail 'service log is not displayed'
grep -Fq "SUDO|tail -n 100 $tmp/current" "$tmp/log" || fail 'private service log does not elevate'

printf 'ok - mihomoctl maps clear modes and safe node names onto the native API\n'
