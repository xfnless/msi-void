#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

[ -f "$root/root/home/.config/niri/config.kdl" ] || fail 'Niri configuration is active'
[ ! -e "$root/archive/home/.config/niri" ] || fail 'Niri is no longer archived'
grep -q '^ni() {' "$root/root/home/.bashrc" || fail 'ni starts Niri from a TTY'
grep -Fq 'dbus-run-session niri --session' "$root/root/home/.bashrc" || fail 'Niri runs in a D-Bus session'
grep -Fq 'ln -sfnT "$h/.config/niri" "$HOME/.config/niri"' "$root/50-link-home.sh" || fail 'Niri config is linked'
grep -Eq '(^|[[:space:]])niri([[:space:]\\]|$)' "$root/20-pkg-base.sh" || fail 'Niri is installed'
if grep -Eq '(^|[[:space:]])alsa-utils([[:space:]\\]|$)' "$root/20-pkg-base.sh"; then
	fail 'ALSA mixer utility remains explicitly installed'
fi
grep -Fq 'wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "2%-"' \
	"$root/root/home/.config/niri/config.kdl" || fail 'volume down uses PipeWire'
grep -Fq 'wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "2%+"' \
	"$root/root/home/.config/niri/config.kdl" || fail 'volume up uses PipeWire'
grep -Fq 'wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"' \
	"$root/root/home/.config/niri/config.kdl" || fail 'mute uses PipeWire'
grep -Eq '(^|[[:space:]])swappy([[:space:]\\]|$)' "$root/60-pkg-apps.sh" || fail 'Swappy is installed'
grep -Fq '| swappy -f -' "$root/root/home/.config/niri/config.kdl" || fail 'screenshots open in Swappy'
grep -Fq 'Mod+c repeat=false { spawn "helium" "--new-window"; }' \
	"$root/root/home/.config/niri/config.kdl" || fail 'Mod+c opens Helium'
grep -Fq 'Mod+shift+c repeat=false { spawn "firefox" "--new-window"; }' \
	"$root/root/home/.config/niri/config.kdl" || fail 'Mod+Shift+c opens Firefox'
grep -Fq 'Mod+ctrl+c repeat=false { spawn "google-chrome-stable" "--new-window"; }' \
	"$root/root/home/.config/niri/config.kdl" || fail 'Mod+Ctrl+c opens Google Chrome Stable'
grep -Fq 'xcursor-theme "Adwaita"' "$root/root/home/.config/niri/config.kdl" || fail 'Niri uses the installed cursor theme'
grep -Fq 'xcursor-size 24' "$root/root/home/.config/niri/config.kdl" || fail 'Niri cursor size matches GTK'
if grep -Eq '/home/' "$root/root/home/.config/niri/config.kdl"; then
	fail 'Niri config contains a user-specific path'
fi
grep -Fq 'output "AU Optronics 0x0FA7 Unknown"' "$root/root/home/.config/niri/config.kdl" || fail 'MSI panel has an exact output rule'
grep -Fq 'mode "2560x1600@60.003"' "$root/root/home/.config/niri/config.kdl" || fail 'MSI panel is fixed to 60 Hz'
grep -Fq 'output "Tianma Microelectronics Ltd. TL140ADMP01 Unknown"' \
	"$root/root/home/.config/niri/config.kdl" || fail 'ASUS panel does not use its exact EDID model'
grep -Fq 'mode "2560x1600@60.000"' "$root/root/home/.config/niri/config.kdl" || fail 'ASUS panel is not fixed to its exact 60 Hz mode'
if grep -Eq 'ASUS_PANEL_MODEL|output "eDP-1"' "$root/root/home/.config/niri/config.kdl"; then
	fail 'ASUS panel still uses a placeholder or connector fallback'
fi
grep -Fq 'spawn-at-startup "sh" "-c" "exec swaybg -i \"$HOME/.config/niri/bg.jpg\""' \
	"$root/root/home/.config/niri/config.kdl" || fail 'wallpaper path follows HOME'
grep -Fq 'swaylock -f -i $HOME/.config/niri/lock.jpg' \
	"$root/root/home/.config/niri/config.kdl" || fail 'lock image path follows HOME'
[ -f "$root/root/home/.config/niri/bg.jpg" ] || fail 'desktop wallpaper is missing'
[ -f "$root/root/home/.config/niri/lock.jpg" ] || fail 'lock-screen wallpaper is missing'
if grep -Riq 'satty' "$root/20-pkg-base.sh" "$root/60-pkg-apps.sh" "$root/root/home/.config/niri"; then
	fail 'Satty remains in the active setup'
fi
if grep -Eiq 'niri-float-sticky|bemenu|wlopm' "$root/20-pkg-base.sh"; then
	fail 'unused Niri helpers remain in the base package list'
fi

for path in \
	"$root/root/home/.config/labwc" "$root/root/home/.config/river" "$root/root/home/.config/tri" \
	"$root/root/home/.config/tint2" "$root/root/home/.config/yambar" \
	"$root/root/home/.cwmrc" "$root/root/home/.xinitrc" "$root/root/home/.Xresources"; do
	[ ! -e "$path" ] || fail "old WM file remains: ${path#"$root/"}"
done

if grep -Eiq 'labwc|cwm|river|tri|yambar|tint2|xorg-minimal|startx' \
	"$root/20-pkg-base.sh" "$root/50-link-home.sh" "$root/70-link-apps.sh" "$root/root/home/.bashrc"; then
	fail 'an old WM remains in the active setup'
fi

niri validate --config "$root/root/home/.config/niri/config.kdl" >/dev/null
printf 'ok - Niri is the only active window manager\n'
