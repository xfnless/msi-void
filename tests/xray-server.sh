#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
install=$repo/servers/xray/install.sh
exit_template=$repo/servers/xray/exit.json
relay_template=$repo/servers/xray/hk-relay.json

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
has() { grep -Fq "$2" "$1" || fail "$1 missing: $2"; }

[ -f "$install" ] || fail 'server installer is missing'
[ -f "$exit_template" ] || fail 'exit template is missing'
[ -f "$relay_template" ] || fail 'HK relay template is missing'

has "$install" 'xray run -test'
has "$install" 'config.json.before-standalone'
has "$install" '/^(Password|PublicKey)/'
has "$install" 'systemctl is-active --quiet xray'
has "$exit_template" '"port": 443'
has "$exit_template" '"security": "reality"'
has "$exit_template" '"flow": "xtls-rprx-vision"'
has "$relay_template" '"port": 9443'
has "$relay_template" '"protocol": "dokodemo-door"'
has "$relay_template" '"address": "__RELAY_ADDRESS__"'

printf 'ok - standalone Xray artifacts are explicit and safely validated\n'
