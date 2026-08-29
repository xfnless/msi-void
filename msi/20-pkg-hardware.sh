#!/bin/sh
# MSI Intel graphics, microcode and Meteor Lake audio firmware.
set -eu
sudo xbps-install -S intel-ucode mesa-intel-dri intel-video-accel sof-firmware
