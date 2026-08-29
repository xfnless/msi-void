#!/bin/sh
# 忽略本机用不上的 base 固件/文件系统工具，并卸掉；禁用 nouveau
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo mkdir -p /etc/xbps.d /etc/modprobe.d
sudo install -o root -g root -m 644 \
	"$dir/etc/xbps.d/20-ignore.conf" \
	/etc/xbps.d/20-ignore.conf
sudo install -o root -g root -m 644 \
	"$dir/etc/modprobe.d/blacklist-nouveau.conf" \
	/etc/modprobe.d/blacklist-nouveau.conf

# 已忽略的可强制卸掉（即便仍被 base 点名）
sudo xbps-remove -Ry \
	linux-firmware-intel \
	linux-firmware-nvidia \
	linux-firmware-broadcom \
	alsa-firmware \
	wifi-firmware \
	ipw2100-firmware \
	ipw2200-firmware \
	zd1211-firmware \
	btrfs-progs \
	xfsprogs \
	f2fs-tools \
	2>/dev/null || true

echo '==== ignorepkg ===='
cat /etc/xbps.d/20-ignore.conf
echo '==== still installed? (should be empty) ===='
for p in \
	linux-firmware-intel linux-firmware-nvidia linux-firmware-broadcom \
	alsa-firmware \
	wifi-firmware ipw2100-firmware ipw2200-firmware zd1211-firmware \
	btrfs-progs xfsprogs f2fs-tools
do
	xbps-query "$p" >/dev/null 2>&1 && echo "STILL $p"
done
echo '(nouveau：须 grub 含 modprobe.blacklist=nouveau，并重建 initramfs；见 80-grub.sh)'
# 当前内核 initramfs 收进 modprobe.d，避免早于 root 就加载 nouveau
kver=$(uname -r)
if [ -f "/boot/vmlinuz-$kver" ]; then
	sudo dracut --force "/boot/initramfs-$kver.img" "$kver"
fi
