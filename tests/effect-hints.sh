#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

grep -Fq 'TTY：执行 exit 后重新登录' "$repo/40-sv-base.sh" ||
	fail 'seatd group change does not explain how to re-login from TTY'
grep -Fq 'Niri：退出整个会话后重新登录' "$repo/40-sv-base.sh" ||
	fail 'seatd group change does not explain that closing one terminal is insufficient'

for script in msi/20-pkg-hardware.sh msi/80-grub.sh asus/80-grub.sh asus/85-power.sh; do
	grep -Fq '下次重启' "$repo/$script" || fail "$script omits its reboot effect"
done

grep -Fq 'void-installer 完成后：重启' "$repo/flow.txt" ||
	fail 'flow omits the required installer reboot'
grep -Fq '公共脚本完成后：退出当前登录会话，再重新登录' "$repo/flow.txt" ||
	fail 'flow omits the login-session checkpoint'
grep -Fq '设备脚本完成后：无需立即重启' "$repo/flow.txt" ||
	fail 'flow does not distinguish deferred reboot effects'

printf 'ok - scripts explain when changes take effect\n'
