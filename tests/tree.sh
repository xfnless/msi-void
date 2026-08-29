#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

for path in archive/home/.emacs.d archive/home/.config/nvim archive/home/.config/niri \
	home/.config/river home/.config/tri etc/keyd \
	msi/etc/default/grub msi/etc/grub.d/09_windows \
	asus/etc/default/grub msi asus; do
	[ -e "$repo/$path" ] || fail "missing $path"
done
for path in Documents home/.emacs.d home/.config/nvim home/.config/niri \
	home/.config/foot home/.config/wl-kbptr home/.config/mouseless \
	home/.asoundrc keyd grub msi/grub asus/grub \
	86-dns.sh etc/resolv.conf.head; do
	[ ! -e "$repo/$path" ] || fail "inactive or private path is active: $path"
done

common_files="$repo/20-pkg-base.sh $repo/40-sv-base.sh $repo/50-link-home.sh $repo/60-pkg-apps.sh $repo/70-link-apps.sh $repo/home/.bashrc"
if grep -Eiq 'intel|amd|sof|tlp|iwlwifi|efibootmgr|nameserver|bluetooth|bluez|mouseless|wl-kbptr|swaybg|niri|foot|neovim|emacs' $common_files; then
	fail 'common setup contains host hardware or rejected software'
fi
grep -q 'pipewire' "$repo/20-pkg-base.sh" || fail 'PipeWire is common'
grep -q 'wireplumber' "$repo/20-pkg-base.sh" || fail 'WirePlumber is common'
grep -q 'firefox' "$repo/60-pkg-apps.sh" || fail 'Firefox is installed on both hosts'
[ -x "$repo/90-helium.sh" ] || fail 'Helium is installed on both hosts'

grep -qx 'bind.Super+c = exec firefox' "$repo/msi/home/.config/tri/config" || fail 'MSI Super+c uses Firefox'
grep -qx 'bind.Super+c = exec firefox' "$repo/asus/home/.config/tri/config" || fail 'ASUS Super+c uses Firefox'
grep -q 'firefox.desktop' "$repo/msi/home/.config/mimeapps.list" || fail 'MSI defaults to Firefox'
grep -q 'firefox.desktop' "$repo/asus/home/.config/mimeapps.list" || fail 'ASUS defaults to Firefox'

for config in "$repo/msi/home/.config/tri/config" "$repo/asus/home/.config/tri/config"; do
	grep -q '^start.audio = exec pipewire$' "$config" || fail 'tri starts the common PipeWire session'
	grep -qx 'bind.Super+t = exec telegram-desktop' "$config" || fail 'Super+t starts Telegram'
	grep -q '^bind.XF86AudioRaiseVolume = wpctl ' "$config" || fail 'tri volume keys use wpctl'
	if grep -Eiq 'mouseless|wl-kbptr|swaybg|\.config/niri|bluetooth|bluez' "$config"; then
		fail 'tri config contains a rejected component'
	fi
done

if git -C "$repo" ls-files | grep -Eiq '(^|/)(accounts\.json|pppuser\.csv|\.bash_history|\.cache/|zig-cache/|zig-out/bin/tri\.previous$)'; then
	fail 'tracked tree contains personal data or build history'
fi
printf 'ok - common configuration and explicit host differences are isolated\n'
