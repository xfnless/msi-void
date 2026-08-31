#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

for path in archive/home/.emacs.d archive/home/.config/nvim \
	home/.config/niri etc/keyd msi/etc/default/grub \
	msi/etc/grub.d/09_windows msi asus; do
	[ -e "$repo/$path" ] || fail "missing $path"
done

for path in Documents home/.emacs.d home/.config/nvim \
	home/.config/foot home/.config/mouseless home/.asoundrc \
	keyd grub msi/grub asus/grub 86-dns.sh etc/resolv.conf.head; do
	[ ! -e "$repo/$path" ] || fail "inactive or private path is active: $path"
done

common_files="$repo/20-pkg-base.sh $repo/40-sv-base.sh $repo/50-link-home.sh $repo/60-pkg-apps.sh $repo/70-link-apps.sh $repo/home/.bashrc"
if grep -Eiq 'intel|amd|sof|tlp|iwlwifi|efibootmgr|nameserver|bluetooth|bluez|mouseless|foot|neovim|emacs' $common_files; then
	fail 'common setup contains host hardware or rejected software'
fi
grep -q 'pipewire' "$repo/20-pkg-base.sh" || fail 'PipeWire is common'
grep -q 'wireplumber' "$repo/20-pkg-base.sh" || fail 'WirePlumber is common'
grep -q 'firefox' "$repo/60-pkg-apps.sh" || fail 'Firefox is installed on both hosts'
[ -x "$repo/90-helium.sh" ] || fail 'Helium is installed on both hosts'
grep -q 'firefox.desktop' "$repo/msi/home/.config/mimeapps.list" || fail 'MSI defaults to Firefox'
grep -q 'firefox.desktop' "$repo/asus/home/.config/mimeapps.list" || fail 'ASUS defaults to Firefox'

if git -C "$repo" ls-files | grep -Eiq '(^|/)(accounts\.json|pppuser\.csv|\.bash_history|\.cache/|zig-cache/)'; then
	fail 'tracked tree contains personal data or build history'
fi
printf 'ok - common configuration and explicit host differences are isolated\n'
