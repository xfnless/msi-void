#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config=$repo/root/etc/mouseless/config.yaml
run=$repo/root/etc/sv/mouseless/run
installer=$repo/75-mouseless.sh
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

[ -f "$config" ] || fail 'Mouseless config is missing'
[ -x "$run" ] || fail 'Mouseless runit service is missing or not executable'
[ -x "$installer" ] || fail 'Mouseless installer is missing or not executable'

for mapping in \
	'f13: move 0 -1' 'f14: move 0 1' 'f15: move -1 0' 'f16: move 1 0' \
	'f21: scroll up' 'f22: scroll down' 'f23: scroll left' 'f24: scroll right' \
	'f17: speed 0.1' 'f18: speed 0.3' 'f19: speed 2.0' 'f20: speed 4.0'; do
	grep -Fq "$mapping" "$config" || fail "missing mapping: $mapping"
done

grep -Fq 'go install github.com/jbensmann/mouseless@latest' "$installer" ||
	fail 'installer does not build official Mouseless'
grep -Fq '/etc/sv/mouseless /var/service/mouseless' "$installer" ||
	fail 'installer does not enable the runit service'
grep -Fq '/usr/local/bin/mouseless --config /etc/mouseless/config.yaml' "$run" ||
	fail 'service does not use the installed configuration'
grep -Fxq 'sh 75-mouseless.sh' "$repo/flow.txt" || fail 'flow omits Mouseless'

printf 'ok - keyd function keys drive the Mouseless runit service\n'
