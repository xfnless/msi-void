#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config=$repo/root/etc/mihomo/config.yaml.example
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
has() { grep -Fq "$1" "$config" || fail "missing configuration: $1"; }

[ -f "$config" ] || fail 'Mihomo example configuration does not exist'
has 'external-controller: 127.0.0.1:9090'
has 'allow-lan: false'
has 'mode: rule'
has 'store-selected: true'
has 'enable: true'
has 'auto-route: true'
has 'dns-hijack:'
has 'marzban:'
has 'url: MARZBAN_SUBSCRIPTION_URL'
has 'User-Agent: [mihomo]'
has 'name: 香港'
has 'name: 国内'
has 'name: GLOBAL'
has 'GEOSITE,cn,国内'
has 'GEOIP,cn,国内,no-resolve'
has 'MATCH,香港'

if grep -Fq 'uuid:' "$config"; then
	fail 'public example contains a node UUID'
fi

domestic_filter=$(awk '
/name: 国内/ { in_domestic = 1; next }
in_domestic && /filter:/ {
    sub(/^[^:]*:[[:space:]]*/, "")
    gsub(/^\047|\047$/, "")
    print
    exit
}
' "$config")
python3 - "$domestic_filter" <<'PY' || fail 'domestic filter does not classify the Marzban node names'
import re
import sys

pattern = re.compile(sys.argv[1])
assert pattern.search("9443 hk-gz 47.243.86.161 Active VLESS tcp")
assert not pattern.search("8443 hk Active VLESS tcp")
PY

printf 'ok - Mihomo template has private subscription, split routing and safe controller defaults\n'
