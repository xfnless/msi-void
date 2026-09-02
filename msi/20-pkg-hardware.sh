#!/bin/sh
# MSI Intel graphics, microcode and Meteor Lake audio firmware.
set -eu
sudo xbps-install -S intel-ucode mesa-intel-dri intel-video-accel sof-firmware
printf '%s\n' 'MSI 硬件包已安装；微码、驱动和固件在下次重启后完整生效。'
