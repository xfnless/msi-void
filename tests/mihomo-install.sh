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

# Re-running the installer must replace the service link itself and let runsvdir
# start it. Dereferencing an existing link creates /etc/sv/mihomo/mihomo, while
# an immediate `sv up` races runsvdir's creation of supervise/control.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin" "$tmp/home"
printf '#!/bin/sh\nexit 0\n' >"$tmp/mihomo"
chmod +x "$tmp/mihomo"
cat >"$tmp/bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$MIHOMO_INSTALL_LOG"
case "$*" in
'test -f /etc/mihomo/config.yaml') exit 0 ;;
'grep -Fq MARZBAN_SUBSCRIPTION_URL /etc/mihomo/config.yaml') exit 1 ;;
esac
exit 0
EOF
chmod +x "$tmp/bin/sudo"
MIHOMO_INSTALL_LOG=$tmp/log MIHOMO_BIN=$tmp/mihomo HOME=$tmp/home \
	PATH="$tmp/bin:$PATH" sh "$installer" >/dev/null
grep -Fqx 'ln -sfnT /etc/sv/mihomo /var/service/mihomo' "$tmp/log" || \
	fail 'reinstall does not atomically replace the runit service link'
if grep -Fqx 'sv up mihomo' "$tmp/log"; then
	fail 'installer races runsvdir by calling sv up immediately'
fi

printf 'ok - Mihomo installation validates private configuration before enabling runit\n'
