#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
installer=$repo/45-mihomo.sh
run=$repo/root/etc/sv/mihomo/run
log_run=$repo/root/etc/sv/mihomo/log/run
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 is missing: $2"; }

[ -x "$run" ] || fail 'Mihomo runit service is absent or not executable'
[ -x "$log_run" ] || fail 'Mihomo runit logger is absent or not executable'
[ -f "$installer" ] || fail 'Mihomo installer is absent'

has "$run" '/usr/local/bin/mihomo'
has "$run" '-d /var/lib/mihomo'
has "$run" '-f /etc/mihomo/config.yaml'
has "$log_run" 'svlogd -tt /var/log/sv/mihomo'
has "$installer" 'config.yaml.example'
has "$installer" 'MARZBAN_SUBSCRIPTION_URL'
has "$installer" 'mihomo -t'
has "$installer" '/var/service/mihomo'
has "$installer" 'install -m 600'

validation_line=$(grep -n 'mihomo -t' "$installer" | head -n 1 | cut -d: -f1)
enable_line=$(grep -n '/var/service/mihomo' "$installer" | tail -n 1 | cut -d: -f1)
[ "$validation_line" -lt "$enable_line" ] || fail 'service is enabled before configuration validation'

printf 'ok - Mihomo installation validates private configuration before enabling runit\n'
