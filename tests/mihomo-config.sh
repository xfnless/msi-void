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
has 'find-process-mode: always'
has 'store-selected: true'
has 'enable: true'
has 'auto-route: true'
has 'dns-hijack:'
has 'proxies:'
has 'name: 香港节点'
has 'name: 国内节点'
has 'REPLACE_STATIC_NODE_VALUES'
has 'server: REPLACE_HK_SERVER'
has 'port: 443'
has 'server: REPLACE_CN_RELAY_SERVER'
has 'port: 9443'
has 'tls: true'
has 'servername: www.nvidia.com'
has 'flow: xtls-rprx-vision'
has 'reality-opts:'
has 'public-key: REPLACE_PUBLIC_KEY'
has 'short-id: REPLACE_SHORT_ID'
has 'name: 香港'
has 'name: 国内'
has 'name: GLOBAL'
has 'DOMAIN-SUFFIX,chatgpt.com,DIRECT'
has 'DOMAIN-SUFFIX,openai.com,DIRECT'
has 'DOMAIN-SUFFIX,oaistatic.com,DIRECT'
has 'DOMAIN-SUFFIX,oaiusercontent.com,DIRECT'
has 'AND,((OR,((PROCESS-NAME,firefox),(PROCESS-NAME,chrome),(PROCESS-NAME,Telegram))),(GEOSITE,category-ads-all)),REJECT'
has 'SUB-RULE,(PROCESS-NAME,firefox),work-app'
has 'SUB-RULE,(PROCESS-NAME,chrome),work-app'
has 'SUB-RULE,(PROCESS-NAME,Telegram),work-app'
has 'MATCH,DIRECT'
has 'work-app:'
has 'GEOSITE,cn,国内'
has 'GEOIP,cn,国内,no-resolve'
has 'MATCH,香港'

openai_line=$(grep -n 'DOMAIN-SUFFIX,chatgpt.com,DIRECT' "$config" | cut -d: -f1)
ad_line=$(grep -n 'GEOSITE,category-ads-all' "$config" | cut -d: -f1)
firefox_line=$(grep -n 'SUB-RULE,(PROCESS-NAME,firefox)' "$config" | cut -d: -f1)
[ "$openai_line" -lt "$ad_line" ] || fail 'OpenAI direct rules must run before ad blocking'
[ "$ad_line" -lt "$firefox_line" ] || fail 'ad blocking must run before work-app split routing'

if grep -Fq 'proxy-providers:' "$config" || grep -Fq 'MARZBAN_SUBSCRIPTION_URL' "$config"; then
	fail 'static template still depends on a subscription provider'
fi

printf 'ok - Mihomo template has private static nodes, split routing and safe controller defaults\n'
