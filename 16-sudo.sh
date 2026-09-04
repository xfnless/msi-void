#!/bin/sh
# Allow the account running the setup to administer this personal machine without a password.
set -eu

user=${USER:?USER is not set}
case "$user" in
	*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-]*)
		printf 'Unsupported user name: %s\n' "$user" >&2
		exit 1
		;;
esac

sudoers_dir=${SUDOERS_DIR:-/etc/sudoers.d}
rule=$sudoers_dir/10-$user-nopasswd
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM

printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user" >"$tmp"
chmod 440 "$tmp"
sudo visudo -cf "$tmp"
sudo install -o root -g root -m 440 "$tmp" "$rule"
printf '%s\n' "Passwordless sudo enabled for $user."
